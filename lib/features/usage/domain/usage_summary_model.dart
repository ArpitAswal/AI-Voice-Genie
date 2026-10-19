import '../../../core/enums/app_enums.dart';
import '../data/usage_dto.dart';
import 'monthly_usage_data.dart';

/// Unified Domain Entity for AI Usage Profiles & Budget Tracking per provider.
///
/// Firestore path: `AI_Voice_Genie/Users/User_Model/{uid}/usageSummaries/{providerId}`.
///
/// Contains global budget parameters alongside a partitioned map of monthly telemetry
/// data. The [keyHint] field holds the last 6 characters of the API key that built
/// this document. When the active key's hint differs from [keyHint], budget counters
/// are automatically reset so the new key starts with zero tracked spend — accurately
/// reflecting the new Google billing account's credits.
class UsageSummaryModel {
  /// The specific AI provider this profile tracks (e.g. Gemini, OpenAI, Claude).
  /// Corresponds to the Firestore document ID.
  final AiProviderId provider;

  /// Whether budget limit enforcement is active for this provider.
  /// Dynamically derived from [hasBudget].
  bool get enabled => hasBudget;

  /// Monthly budget spending cap in USD (null if user has not set a budget limit).
  /// When set, the app warns the user or throttles calls as spend approaches this ceiling.
  final double? totalBudgetUsd;

  /// Historical external spend in USD incurred before using this application.
  /// Factored into [lifetimeSpend] so the user's continuous billing cycle remains accurate.
  final double? alreadyUsedUsd;

  /// Map of monthly usage records, keyed by 'YYYY-MM' strings (e.g., '2026-10').
  /// Allows querying past months and calculating month-over-month trend analysis.
  final Map<String, MonthlyUsageData> monthlyData;

  /// Timestamp indicating when the summary document was last updated in Firestore.
  final DateTime? updatedAt;

  /// Root-level tracker for all-time cumulative tokens across all months.
  /// Enables instantaneous lifetime stats without needing to iterate through monthly maps.
  final int? _lifetimeTotalTokens;

  /// Last 6 characters of the API key that built this summary document (e.g. 'f7cK2A').
  ///
  /// Non-secret: 6 chars of a 39+ character key cannot be reversed or used to
  /// reconstruct the original key.
  ///
  /// Role: Key-rotation detector. When the orchestrator finishes an AI request,
  /// it compares the active key's last-6 with this stored hint:
  ///   - Match  → normal increment of monthly counters.
  ///   - Differ → reset monthly/lifetime token counters and write the new hint,
  ///              preserving only [totalBudgetUsd] (the user's spending preference).
  ///   - null   → first-time write; treat as a match.
  final String? keyHint;

  /// AES-encrypted API key string stored directly inside the summary document.
  final String? encryptedApiKey;

  final String? _docId;

  const UsageSummaryModel({
    required this.provider,
    this.totalBudgetUsd,
    this.alreadyUsedUsd,
    this.monthlyData = const {},
    this.updatedAt,
    this.keyHint,
    this.encryptedApiKey,
    String? docId,
    int? lifetimeTotalTokens,
  })  : _docId = docId,
        _lifetimeTotalTokens = lifetimeTotalTokens;

  /// Firestore document ID for this profile (e.g. `gemini_f7cK2A` or fallback `provider.id`).
  String get docId =>
      _docId ?? (keyHint != null ? '${provider.id}_$keyHint' : provider.id);

  /// True if an active positive monthly budget is configured.
  bool get hasBudget => totalBudgetUsd != null && totalBudgetUsd! > 0;

  // ── Dynamic Calculators ───────────────────────────────────────────────────

  /// Retrieves usage metrics for a specific month key ('YYYY-MM'), returning an
  /// empty record if no activity exists for that period.
  MonthlyUsageData getMonth(String monthKey) =>
      monthlyData[monthKey] ?? MonthlyUsageData.empty();

  /// Total sum of estimated cost in USD across all tracked monthly records.
  double _sumTrackedCost() {
    return monthlyData.values
        .fold(0.0, (acc, month) => acc + month.estimatedCostUsd);
  }

  /// Calculates total lifetime spend combining tracked app usage with external credits.
  double lifetimeSpend() {
    return _sumTrackedCost() + (alreadyUsedUsd ?? 0.0);
  }

  /// Calculates all-time cumulative tokens consumed for this provider.
  /// Prefers root [lifetimeTotalTokens] counter; falls back to summing monthly maps.
  int lifetimeTokens() {
    if (_lifetimeTotalTokens != null && _lifetimeTotalTokens > 0) {
      return _lifetimeTotalTokens;
    }
    return monthlyData.values.fold(0, (acc, month) => acc + month.totalTokens);
  }

  /// Calculates remaining budget in USD for the current billing cycle.
  /// Returns null if no budget is configured.
  double? remainingUsd() {
    if (!hasBudget) return null;
    final total = lifetimeSpend();
    return (totalBudgetUsd! - total).clamp(0.0, totalBudgetUsd!);
  }

  /// Calculates remaining budget fraction between 0.0 and 1.0 for UI progress bars.
  /// Returns null if no budget is configured.
  double? remainingFraction() {
    if (!hasBudget) return null;
    final total = lifetimeSpend();
    final remaining = totalBudgetUsd! - total;
    return (remaining / totalBudgetUsd!).clamp(0.0, 1.0);
  }

  /// Returns true if the user's lifetime spend has met or exceeded the configured budget.
  bool isExceeded() {
    if (!hasBudget) return false;
    final total = lifetimeSpend();
    return total >= totalBudgetUsd!;
  }

  /// Returns true if any usage or budget data exists for this provider.
  bool get hasAnyActivity =>
      (alreadyUsedUsd ?? 0.0) > 0 ||
      monthlyData.values.any((m) => m.hasActivity) ||
      (_lifetimeTotalTokens ?? 0) > 0;

  // ── Serialization Bridges ─────────────────────────────────────────────────

  /// Deserializes a Firestore map by bridging through [UsageSummaryDto].
  factory UsageSummaryModel.fromFirestore(
    Map<String, dynamic> data, {
    String? docId,
  }) {
    final effectiveDocId = docId ?? (data['provider'] as String? ?? '');
    return UsageSummaryDto.fromFirestore(effectiveDocId, data).toDomain();
  }
}
