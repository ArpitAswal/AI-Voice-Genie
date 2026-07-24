import '../../../core/enums/app_enums.dart';
import 'usage_event_model.dart';
import 'usage_summary_model.dart';

/// Abstract interface for all usage tracking Firestore operations.
///
/// The orchestrator calls [saveEvent] after every successful AI request.
/// The profile provider calls [getAllSummaries] to build the UI.
abstract interface class UsageRepository {
  /// Saves a single usage event to Firestore.
  ///
  /// Also triggers [updateSummary] to atomically increment the monthly totals.
  /// Must never throw — all errors should be caught and logged internally.
  Future<void> saveEvent({
    required String uid,
    required UsageEventModel event,
  });

  /// Atomically increments the nested monthly usage summary in Firestore.
  ///
  /// Called internally by [saveEvent]; exposed for testing.
  Future<void> updateSummary({
    required String uid,
    required UsageEventModel event,
  });

  /// Loads the unified usage profile for a specific provider.
  Future<UsageSummaryModel?> getSummary({
    required String uid,
    required AiProviderId provider,
  });

  /// Loads all unified usage profiles across all providers.
  Future<List<UsageSummaryModel>> getAllSummaries({
    required String uid,
  });

  /// Listen to all unified usage profiles in real-time
  Stream<List<UsageSummaryModel>> watchAllSummaries({
    required String uid,
  });

  /// Saves (creates or overwrites) global budget settings for a provider.
  Future<void> updateGlobalSettings({
    required String uid,
    required UsageSummaryModel model,
  });

  /// Disables/Deletes the budget settings for a provider (leaves usage intact).
  Future<void> disableBudget({
    required String uid,
    required AiProviderId provider,
  });
}
