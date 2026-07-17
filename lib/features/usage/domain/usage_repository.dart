import '../../../core/enums/app_enums.dart';
import 'usage_budget_model.dart';
import 'usage_event_model.dart';
import 'usage_summary_model.dart';

/// Abstract interface for all usage tracking Firestore operations.
///
/// The orchestrator calls [saveEvent] after every successful AI request.
/// The profile provider calls [getAllSummaries] and [getBudget] to build the UI.
abstract interface class UsageRepository {
  /// Saves a single usage event to Firestore.
  ///
  /// Also triggers [updateSummary] to atomically increment the monthly totals.
  /// Must never throw — all errors should be caught and logged internally.
  Future<void> saveEvent({
    required String uid,
    required UsageEventModel event,
  });

  /// Atomically increments the monthly usage summary in Firestore.
  ///
  /// Called internally by [saveEvent]; exposed for testing.
  Future<void> updateSummary({
    required String uid,
    required UsageEventModel event,
  });

  /// Loads the usage summary for a specific provider and month.
  ///
  /// Returns null if no activity has been recorded yet.
  Future<UsageSummaryModel?> getSummary({
    required String uid,
    required AiProviderId provider,
    required String monthKey,
  });

  /// Loads all usage summaries for the given month across all providers.
  ///
  /// Read all summaries for a given month
  Future<List<UsageSummaryModel>> getAllSummaries({
    required String uid,
    required String monthKey,
  });

  /// Listen to all summaries for a given month in real-time
  Stream<List<UsageSummaryModel>> watchAllSummaries({
    required String uid,
    required String monthKey,
  });

  /// Loads the budget for a specific provider.
  ///
  /// Returns null if the user has not configured a budget.
  Future<UsageBudgetModel?> getBudget({
    required String uid,
    required AiProviderId provider,
  });

  /// Saves (creates or overwrites) a budget for a provider.
  Future<void> saveBudget({
    required String uid,
    required UsageBudgetModel budget,
  });

  /// Deletes the budget for a provider.
  Future<void> deleteBudget({
    required String uid,
    required AiProviderId provider,
  });
}
