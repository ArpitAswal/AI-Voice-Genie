import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../domain/usage_event_model.dart';
import '../domain/usage_repository.dart';
import '../domain/usage_summary_model.dart';
import 'usage_dto.dart';
import 'usage_firestore_dao.dart';

/// Concrete implementation of [UsageRepository] adhering to DAO & DTO architectural pattern.
///
/// Responsibilities:
/// 1. Acts as the domain bridge between presentation/orchestration layers and Firestore storage.
/// 2. Delegates low-level atomic batch writes and Firestore streams to [UsageFirestoreDao].
/// 3. Normalizes domain entities through [UsageEventDto] and [UsageSummaryDto].
/// 4. Ensures AI request execution is never interrupted or blocked by telemetry logging failures.
class UsageRepositoryImpl implements UsageRepository {
  final UsageFirestoreDao _dao;

  UsageRepositoryImpl({UsageFirestoreDao? dao, FirebaseFirestore? db})
      : _dao = dao ?? UsageFirestoreDao(firestore: db);

  // ── Event Persistence ──────────────────────────────────────────────────────

  @override
  Future<void> saveEvent({
    required String uid,
    required UsageEventModel event,
  }) async {
    try {
      // 1. Transform Domain Entity into DTO (sparse fields, omitting redundant internal ID)
      final dto = UsageEventDto.fromDomain(event);

      // 2. Delegate atomic write to DAO (persists event + increments summary in one batch)
      await _dao.recordUsageEventBatch(uid: uid, eventDto: dto);
    } catch (e) {
      // Telemetry failures must never crash or block chat generation (agent rule: graceful degradation)
      debugPrint('❌ UsageRepositoryImpl.saveEvent failed (non-fatal): $e');
    }
  }

  @override
  Future<void> updateSummary({
    required String uid,
    required UsageEventModel event,
  }) async {
    // Handled atomically within saveEvent; kept for interface completeness and isolated tests
    await saveEvent(uid: uid, event: event);
  }

  // ── Summary Reads & Streams ────────────────────────────────────────────────

  @override
  Future<UsageSummaryModel?> getSummary({
    required String uid,
    required AiProviderId provider,
    String? docId,
    String? keyHint,
  }) async {
    try {
      final dto = await _dao.getSummaryDoc(
        uid: uid,
        providerId: provider.id,
        docId: docId,
        keyHint: keyHint,
      );
      return dto?.toDomain();
    } catch (e) {
      debugPrint('⚠️ UsageRepositoryImpl.getSummary failed for [${provider.id}]: $e');
      return null;
    }
  }

  @override
  Future<List<UsageSummaryModel>> getAllSummaries({
    required String uid,
  }) async {
    try {
      final dtos = await _dao.getAllSummariesCollection(uid: uid);
      return dtos.map((dto) => dto.toDomain()).toList();
    } catch (e) {
      debugPrint('⚠️ UsageRepositoryImpl.getAllSummaries failed: $e');
      return [];
    }
  }

  @override
  Stream<List<UsageSummaryModel>> watchAllSummaries({
    required String uid,
  }) {
    return _dao
        .watchSummariesCollection(uid: uid)
        .map((dtos) => dtos.map((dto) => dto.toDomain()).toList());
  }

  // ── Budget Configuration ───────────────────────────────────────────────────

  @override
  Future<void> updateGlobalSettings({
    required String uid,
    required UsageSummaryModel model,
  }) async {
    try {
      final dto = UsageSummaryDto.fromDomain(model);
      await _dao.saveBudgetSettings(uid: uid, summaryDto: dto);
    } catch (e) {
      debugPrint('⚠️ UsageRepositoryImpl.updateGlobalSettings failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> disableBudget({
    required String uid,
    required AiProviderId provider,
    String? docId,
  }) async {
    try {
      await _dao.disableBudgetDoc(
        uid: uid,
        providerId: provider.id,
        docId: docId,
      );
    } catch (e) {
      debugPrint('⚠️ UsageRepositoryImpl.disableBudget failed: $e');
      rethrow;
    }
  }

  // ── Account Cleanup ────────────────────────────────────────────────────────

  @override
  Future<void> deleteAllUsageData({required String uid}) async {
    try {
      await _dao.deleteAllUsageData(uid: uid);
    } catch (e) {
      debugPrint('⚠️ UsageRepositoryImpl.deleteAllUsageData failed: $e');
      rethrow;
    }
  }
}
