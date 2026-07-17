import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

import '../domain/usage_budget_model.dart';
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
/// - All errors are caught internally; usage tracking must never disrupt the AI
///   request flow.
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
    final summaryDocId = '${event.provider.id}_${event.monthKey}';
    final summaryPath = FirebaseCollections.usageSummaryDoc(uid, summaryDocId);

    debugPrint('📊 UsageRepository: Attempting batch write...');
    debugPrint('   - Event Path: $eventPath/${event.id}');
    debugPrint('   - Summary Path: $summaryPath');

    try {
      final batch = _db.batch();

      // 1. Write the individual event document
      final eventRef = _db.collection(eventPath).doc(event.id);
      batch.set(eventRef, event.toFirestore());

      // 2. Merge-increment the monthly summary
      final summaryRef = _db.doc(summaryPath);

      final summaryIncrement = UsageSummaryModel(
        provider: event.provider,
        monthKey: event.monthKey,
        inputTokens: event.inputTokens,
        outputTokens: event.outputTokens,
        totalTokens: event.totalTokens,
        imageCount: event.imageCount,
        pdfCount: event.pdfCount,
        estimatedCostUsd: event.estimatedCostUsd,
      );

      batch.set(
        summaryRef,
        summaryIncrement.toIncrementMap(),
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
      final summaryDocId = '${event.provider.id}_${event.monthKey}';
      final summaryRef = _db.doc(
        FirebaseCollections.usageSummaryDoc(uid, summaryDocId),
      );

      final summaryIncrement = UsageSummaryModel(
        provider: event.provider,
        monthKey: event.monthKey,
        inputTokens: event.inputTokens,
        outputTokens: event.outputTokens,
        totalTokens: event.totalTokens,
        imageCount: event.imageCount,
        pdfCount: event.pdfCount,
        estimatedCostUsd: event.estimatedCostUsd,
      );

      await summaryRef.set(
        summaryIncrement.toIncrementMap(),
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
    required String monthKey,
  }) async {
    try {
      final docId = '${provider.id}_$monthKey';
      final snap =
          await _db.doc(FirebaseCollections.usageSummaryDoc(uid, docId)).get();
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
    required String monthKey,
  }) async {
    try {
      final snap = await _db
          .collection(FirebaseCollections.usageSummariesCollection(uid))
          .where(FirebaseCollections.usageFieldMonthKey, isEqualTo: monthKey)
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
    required String monthKey,
  }) {
    return _db
        .collection(FirebaseCollections.usageSummariesCollection(uid))
        .where(FirebaseCollections.usageFieldMonthKey, isEqualTo: monthKey)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UsageSummaryModel.fromFirestore(d.data()))
            .toList());
  }

  // ── Budget ───────────────────────────────────────────────────────────────────

  @override
  Future<UsageBudgetModel?> getBudget({
    required String uid,
    required AiProviderId provider,
  }) async {
    try {
      final snap = await _db
          .doc(FirebaseCollections.usageBudgetDoc(uid, provider.id))
          .get();
      if (!snap.exists || snap.data() == null) return null;
      return UsageBudgetModel.fromFirestore(snap.data()!);
    } catch (e) {
      debugPrint('⚠️ getBudget failed: $e');
      return null;
    }
  }

  @override
  Future<void> saveBudget({
    required String uid,
    required UsageBudgetModel budget,
  }) async {
    try {
      await _db
          .doc(FirebaseCollections.usageBudgetDoc(uid, budget.provider.id))
          .set(budget.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ saveBudget failed: $e');
      rethrow; // Budget save IS user-initiated — surface the error
    }
  }

  @override
  Future<void> deleteBudget({
    required String uid,
    required AiProviderId provider,
  }) async {
    try {
      await _db
          .doc(FirebaseCollections.usageBudgetDoc(uid, provider.id))
          .delete();
    } catch (e) {
      debugPrint('⚠️ deleteBudget failed: $e');
      rethrow;
    }
  }
}
