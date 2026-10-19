import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firebase_collections.dart';
import 'usage_dto.dart';

/// Data Access Object (DAO) for AI Usage Firestore Storage.
///
/// Encapsulates all raw Firestore interactions, batch operations, and real-time streams
/// for usage events and aggregate summaries under `AI_Voice_Genie/Users/User_Model/{uid}/...`.
/// Isolates Firestore SDK dependencies from the repository and domain layers.
class UsageFirestoreDao {
  final FirebaseFirestore _firestore;

  UsageFirestoreDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseCollections.firestore;

  // ── Atomic Event & Summary Batch ──────────────────────────────────────────

  /// Atomically persists an individual [UsageEventDto] document and either:
  ///   - Increments the aggregate provider [UsageSummaryDto] monthly counters (normal path), or
  ///   - Resets the summary document counters and writes the new key fingerprint (key-rotation path).
  ///
  /// Key-Rotation Detection:
  ///   Reads the stored [summaryFieldKeyHint] from Firestore before the batch write.
  ///   If [eventDto.keyHint] differs from the stored hint (i.e. the user replaced their API key),
  ///   the monthly data and lifetime token counters are wiped to zero so the new key's billing
  ///   account starts tracking from scratch. [monthlyBudgetUsd] is preserved so the user's
  ///   spending cap preference is not lost.
  ///
  /// Guarantees:
  /// 1. Zero partial writes: Either both the event and summary update succeed, or neither does.
  /// 2. Atomic counters: Uses [FieldValue.increment] to eliminate race conditions from
  ///    concurrent AI prompts across multiple devices or tabs.
  /// 3. Sparse attachment increments: Only increments `imageCount` or `pdfCount` if > 0.
  Future<void> recordUsageEventBatch({
    required String uid,
    required UsageEventDto eventDto,
  }) async {
    final eventColPath = FirebaseCollections.usageEventsCollection(uid);
    // Key-specific summary document: usageSummaries/{providerId}_{keyHint}
    // Preserves individual key usage history while separating billing credits.
    final summaryDocId = eventDto.keyHint != null
        ? '${eventDto.providerId}_${eventDto.keyHint}'
        : eventDto.providerId;
    final summaryDocPath =
        FirebaseCollections.usageSummaryDoc(uid, summaryDocId);

    final batch = _firestore.batch();

    // 1. Write the granular event document (doc ID = eventDto.eventId)
    // Does NOT write redundant internal 'id' inside the document payload.
    final eventDocRef =
        _firestore.collection(eventColPath).doc(eventDto.eventId);
    batch.set(eventDocRef, eventDto.toFirestoreMap());

    // 2. Read the existing summary once to inherit budget cap if newly created.
    final summaryDocRef = _firestore.doc(summaryDocPath);
    final monthKey = eventDto.monthKey;

    final existingSnapshot = await summaryDocRef.get();

    if (!existingSnapshot.exists) {
      batch.set(
        summaryDocRef,
        {
          if (eventDto.keyHint != null)
            FirebaseCollections.summaryFieldKeyHint: eventDto.keyHint,
          'monthlyData': {},
          FirebaseCollections.usageFieldLifetimeTotalTokens: 0,
        },
        SetOptions(merge: true),
      );
    }

    // 3. Atomically increment monthly and lifetime counters for this key
    batch.set(
      summaryDocRef,
      _buildIncrementMap(
        monthKey: monthKey,
        eventDto: eventDto,
        keyHint: eventDto.keyHint,
      ),
      SetOptions(merge: true),
    );

    await batch.commit();
    debugPrint(
      '📊 UsageFirestoreDao: Recorded event [${eventDto.eventId}] & updated summary '
      'for [$summaryDocId] (Month: $monthKey, Tokens: ${eventDto.totalTokens})',
    );
  }

  /// Builds the nested atomic increment map for a provider's monthly summary.
  Map<String, dynamic> _buildIncrementMap({
    required String monthKey,
    required UsageEventDto eventDto,
    String? keyHint,
  }) {
    return {
      'monthlyData': {
        monthKey: {
          // Increment monthly request counter by 1
          FirebaseCollections.summaryFieldRequestCount: FieldValue.increment(1),
          // Increment monthly input token usage
          FirebaseCollections.usageFieldInputTokens:
              FieldValue.increment(eventDto.inputTokens),
          // Increment monthly output token usage
          FirebaseCollections.usageFieldOutputTokens:
              FieldValue.increment(eventDto.outputTokens),
          // Increment monthly total token usage
          FirebaseCollections.usageFieldTotalTokens:
              FieldValue.increment(eventDto.totalTokens),
          // Sparse increment: only bump image counter if images were produced
          if (eventDto.imageCount > 0)
            FirebaseCollections.usageFieldImageCount:
                FieldValue.increment(eventDto.imageCount),
          // Sparse increment: only bump PDF counter if PDFs were processed
          if (eventDto.pdfCount > 0)
            FirebaseCollections.usageFieldPdfCount:
                FieldValue.increment(eventDto.pdfCount),
          // Increment estimated dollar expenditure
          FirebaseCollections.summaryFieldEstimatedCostUsd:
              FieldValue.increment(eventDto.estimatedCostUsd),
        },
      },
      // Root Lifetime Counter (distinct from monthlyData totalTokens):
      FirebaseCollections.usageFieldLifetimeTotalTokens:
          FieldValue.increment(eventDto.totalTokens),
      // Write the active key fingerprint (null-safe: only written when provided)
      if (keyHint != null) FirebaseCollections.summaryFieldKeyHint: keyHint,
      // Timestamp of the latest write operation
      FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  // ── Summary Reads & Streams ────────────────────────────────────────────────

  /// Fetches a single provider's usage summary profile by provider ID and optional keyHint/docId.
  Future<UsageSummaryDto?> getSummaryDoc({
    required String uid,
    required String providerId,
    String? docId,
    String? keyHint,
  }) async {
    final targetDocId = docId ??
        (keyHint != null ? '${providerId}_$keyHint' : providerId);
    final docRef =
        _firestore.doc(FirebaseCollections.usageSummaryDoc(uid, targetDocId));
    var snapshot = await docRef.get();
    if (!snapshot.exists && targetDocId != providerId) {
      final fallbackRef =
          _firestore.doc(FirebaseCollections.usageSummaryDoc(uid, providerId));
      snapshot = await fallbackRef.get();
    }
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UsageSummaryDto.fromFirestore(snapshot.id, snapshot.data()!);
  }

  /// Fetches all provider summary documents for a user in a one-shot query.
  Future<List<UsageSummaryDto>> getAllSummariesCollection({
    required String uid,
  }) async {
    final colRef =
        _firestore.collection(FirebaseCollections.usageSummariesCollection(uid));
    final snapshot = await colRef.get();
    return snapshot.docs
        .where((doc) => doc.data().isNotEmpty)
        .map((doc) => UsageSummaryDto.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Listens to real-time changes on all provider summary documents for a user.
  Stream<List<UsageSummaryDto>> watchSummariesCollection({
    required String uid,
  }) {
    final colRef =
        _firestore.collection(FirebaseCollections.usageSummariesCollection(uid));
    return colRef.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data().isNotEmpty)
          .map((doc) => UsageSummaryDto.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // ── Budget Management ──────────────────────────────────────────────────────

  /// Updates budget settings (monthlyBudgetUsd, alreadyUsedUsd) on the summary document.
  Future<void> saveBudgetSettings({
    required String uid,
    required UsageSummaryDto summaryDto,
  }) async {
    final docId = summaryDto.docId ??
        (summaryDto.keyHint != null
            ? '${summaryDto.providerId}_${summaryDto.keyHint}'
            : summaryDto.providerId);
    final docRef = _firestore.doc(
      FirebaseCollections.usageSummaryDoc(uid, docId),
    );
    await docRef.set(summaryDto.toBudgetUpdateMap(), SetOptions(merge: true));

    debugPrint(
      '💼 UsageFirestoreDao: Saved budget for [$docId] '
      '(Limit: \$${summaryDto.monthlyBudgetUsd}, Used: \$${summaryDto.alreadyUsedUsd})',
    );
  }

  /// Disables budget enforcement for a provider by setting [monthlyBudgetUsd] to null.
  /// Preserves all historical usage data and token logs untouched.
  Future<void> disableBudgetDoc({
    required String uid,
    required String providerId,
    String? docId,
  }) async {
    final targetDocId = docId ?? providerId;
    final docRef =
        _firestore.doc(FirebaseCollections.usageSummaryDoc(uid, targetDocId));
    await docRef.set({
      FirebaseCollections.budgetFieldMonthlyBudgetUsd: null,
      FirebaseCollections.budgetFieldAlreadyUsedUsd: null,
      FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('🛑 UsageFirestoreDao: Disabled budget for [$targetDocId]');
  }

  // ── Account Teardown Purge ─────────────────────────────────────────────────

  /// Deletes all usage subcollections (events, summaries, budgets) in paginated batches.
  /// Used exclusively during account deletion to ensure complete GDPR / data wipe.
  Future<void> deleteAllUsageData({required String uid}) async {
    final collectionPaths = [
      FirebaseCollections.usageEventsCollection(uid),
      FirebaseCollections.usageSummariesCollection(uid),
      FirebaseCollections.usageBudgetsCollection(uid),
    ];

    for (final path in collectionPaths) {
      try {
        while (true) {
          final snapshot = await _firestore.collection(path).limit(400).get();
          if (snapshot.docs.isEmpty) break;

          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          if (snapshot.docs.length < 400) break;
        }
      } catch (e) {
        debugPrint('⚠️ UsageFirestoreDao: Error deleting collection $path: $e');
      }
    }
  }
}
