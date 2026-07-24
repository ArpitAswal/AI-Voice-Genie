import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

import '../domain/usage_event_model.dart';
import '../domain/usage_summary_model.dart';
import '../domain/usage_repository.dart';

/// Firestore implementation of [UsageRepository].
///
/// Design decisions:
/// - [saveEvent] writes the event document and atomically increments the summary
///   in parallel to minimise latency.
/// - Summary uses [SetOptions(merge: true)] with [FieldValue.increment] so that
///   concurrent writes from multiple devices never cause data races.
/// - Uses Firestore dot-notation (e.g., `monthlyData.2026-07.requestCount`)
///   to increment fields inside the nested map without overwriting it.
class UsageRepositoryImpl implements UsageRepository {
  final FirebaseFirestore _db;

  UsageRepositoryImpl({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Event Write ─────────────────────────────────────────────────────────────

  @override
  Future<void> saveEvent({
    required String uid,
    required UsageEventModel event,
  }) async {
    final eventPath = FirebaseCollections.usageEventsCollection(uid);
    final summaryPath =
        FirebaseCollections.usageSummaryDoc(uid, event.provider.id);

    debugPrint('📊 UsageRepository: Attempting batch write...');
    debugPrint('   - Event Path: $eventPath/${event.id}');
    debugPrint('   - Summary Path: $summaryPath');

    try {
      final batch = _db.batch();

      // 1. Write the individual event document
      final eventRef = _db.collection(eventPath).doc(event.id);
      batch.set(eventRef, event.toFirestore());

      // 2. Merge-increment the unified summary
      final summaryRef = _db.doc(summaryPath);

      final incrementMap = {
        FirebaseCollections.usageFieldProvider: event.provider.id,
        'monthlyData': {
          event.monthKey: {
            FirebaseCollections.summaryFieldRequestCount:
                FieldValue.increment(1),
            FirebaseCollections.usageFieldInputTokens:
                FieldValue.increment(event.inputTokens),
            FirebaseCollections.usageFieldOutputTokens:
                FieldValue.increment(event.outputTokens),
            FirebaseCollections.usageFieldTotalTokens:
                FieldValue.increment(event.totalTokens),
            FirebaseCollections.usageFieldImageCount:
                FieldValue.increment(event.imageCount),
            FirebaseCollections.usageFieldPdfCount:
                FieldValue.increment(event.pdfCount),
            FirebaseCollections.summaryFieldEstimatedCostUsd:
                FieldValue.increment(event.estimatedCostUsd),
          }
        },
        FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
        FirebaseCollections.usageFieldTotalTokens:
            FieldValue.increment(event.totalTokens),
      };

      batch.set(
        summaryRef,
        incrementMap,
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('📊 UsageRepository: Batch write completed successfully!');
      debugPrint(
          '   - Saved: ${event.provider.id} | ${event.totalTokens} tokens | \$${event.estimatedCostUsd.toStringAsFixed(4)}');
    } catch (e) {
      // Never fail the AI flow due to usage tracking errors
      debugPrint('❌ UsageRepository: Batch write failed (non-fatal): $e');
    }
  }

  @override
  Future<void> updateSummary({
    required String uid,
    required UsageEventModel event,
  }) async {
    try {
      final summaryRef = _db.doc(
        FirebaseCollections.usageSummaryDoc(uid, event.provider.id),
      );

      final incrementMap = {
        FirebaseCollections.usageFieldProvider: event.provider.id,
        'monthlyData': {
          event.monthKey: {
            FirebaseCollections.summaryFieldRequestCount:
                FieldValue.increment(1),
            FirebaseCollections.usageFieldInputTokens:
                FieldValue.increment(event.inputTokens),
            FirebaseCollections.usageFieldOutputTokens:
                FieldValue.increment(event.outputTokens),
            FirebaseCollections.usageFieldTotalTokens:
                FieldValue.increment(event.totalTokens),
            FirebaseCollections.usageFieldImageCount:
                FieldValue.increment(event.imageCount),
            FirebaseCollections.usageFieldPdfCount:
                FieldValue.increment(event.pdfCount),
            FirebaseCollections.summaryFieldEstimatedCostUsd:
                FieldValue.increment(event.estimatedCostUsd),
          }
        },
        FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
        FirebaseCollections.usageFieldTotalTokens:
            FieldValue.increment(event.totalTokens),
      };

      await summaryRef.set(
        incrementMap,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('⚠️ Usage summary update failed (non-fatal): $e');
    }
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  @override
  Future<UsageSummaryModel?> getSummary({
    required String uid,
    required AiProviderId provider,
  }) async {
    try {
      final snap = await _db
          .doc(FirebaseCollections.usageSummaryDoc(uid, provider.id))
          .get();
      if (!snap.exists || snap.data() == null) return null;
      return UsageSummaryModel.fromFirestore(snap.data()!);
    } catch (e) {
      debugPrint('⚠️ getSummary failed: $e');
      return null;
    }
  }

  @override
  Future<List<UsageSummaryModel>> getAllSummaries({
    required String uid,
  }) async {
    try {
      final snap = await _db
          .collection(FirebaseCollections.usageSummariesCollection(uid))
          .get();

      return snap.docs
          .map((d) => UsageSummaryModel.fromFirestore(d.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ getAllSummaries failed: $e');
      return [];
    }
  }

  @override
  Stream<List<UsageSummaryModel>> watchAllSummaries({
    required String uid,
  }) {
    return _db
        .collection(FirebaseCollections.usageSummariesCollection(uid))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UsageSummaryModel.fromFirestore(d.data()))
            .toList());
  }

  // ── Global Budget Settings ────────────────────────────────────────────────

  @override
  Future<void> updateGlobalSettings({
    required String uid,
    required UsageSummaryModel model,
  }) async {
    try {
      final summaryRef = _db.doc(
        FirebaseCollections.usageSummaryDoc(uid, model.provider.id),
      );

      final updateMap = {
        FirebaseCollections.usageFieldProvider: model.provider.id,
        FirebaseCollections.budgetFieldEnabled: model.enabled,
        FirebaseCollections.budgetFieldMonthlyBudgetUsd: model.totalBudgetUsd,
        FirebaseCollections.budgetFieldAlreadyUsedUsd: model.alreadyUsedUsd,
        FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
      };

      await summaryRef.set(
        updateMap,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('⚠️ updateGlobalSettings failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> disableBudget({
    required String uid,
    required AiProviderId provider,
  }) async {
    try {
      final summaryRef = _db.doc(
        FirebaseCollections.usageSummaryDoc(uid, provider.id),
      );

      await summaryRef.set({
        FirebaseCollections.budgetFieldEnabled: false,
        FirebaseCollections.budgetFieldMonthlyBudgetUsd: null,
        FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ disableBudget failed: $e');
      rethrow;
    }
  }
}
