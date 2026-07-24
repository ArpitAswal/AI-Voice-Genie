import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';
import 'monthly_usage_data.dart';

/// Unified AI Usage Profile per provider.
///
/// Document ID: "{providerId}" (e.g. "openai", "gemini")
/// Firestore path: AI_Voice_Genie/Users/User_Model/{uid}/usageSummaries/{providerId}
///
/// Contains global budget settings and a nested map of monthly usage statistics.
class UsageSummaryModel {
  /// AI provider this profile belongs to
  final AiProviderId provider;

  // ── Global Budget Settings ────────────────────────────────────────────────

  /// Whether this provider is enabled for usage tracking/budgeting
  final bool enabled;

  /// Lifetime prepaid budget limit in USD (null = no budget set)
  final double? totalBudgetUsd;

  /// Credits already spent outside the app (null = 0)
  final double? alreadyUsedUsd;

  // ── Monthly Data ─────────────────────────────────────────────────────────

  /// Nested map of monthly usage data, keyed by "YYYY-MM" (e.g., "2026-07")
  final Map<String, MonthlyUsageData> monthlyData;

  /// When the document was last updated
  final DateTime? updatedAt;

  /// Root-level tracker for lifetime tokens (optional fallback)
  final int? _rootTotalTokens;

  const UsageSummaryModel({
    required this.provider,
    this.enabled = true,
    this.totalBudgetUsd,
    this.alreadyUsedUsd,
    this.monthlyData = const {},
    this.updatedAt,
    int? rootTotalTokens,
  }) : _rootTotalTokens = rootTotalTokens;

  /// Firestore document ID for this profile
  String get docId => provider.id;

  /// True if a total budget value has been entered
  bool get hasBudget =>
      enabled && totalBudgetUsd != null && totalBudgetUsd! > 0;

  // ── Dynamic Calculators ───────────────────────────────────────────────────

  /// Get the usage stats for a specific month
  MonthlyUsageData getMonth(String monthKey) =>
      monthlyData[monthKey] ?? MonthlyUsageData.empty();

  /// Total sum of estimated cost across all tracked months
  double _sumTrackedCost() {
    return monthlyData.values
        .fold(0.0, (acc, month) => acc + month.estimatedCostUsd);
  }

  /// Calculates total lifetime spend combining tracked app usage with already used credits.
  double lifetimeSpend() {
    return _sumTrackedCost() + (alreadyUsedUsd ?? 0.0);
  }

  /// Calculates lifetime tracked tokens (uses root total if available, else sums months)
  int lifetimeTokens() {
    if (_rootTotalTokens != null && _rootTotalTokens > 0) {
      return _rootTotalTokens;
    }
    return monthlyData.values.fold(0, (acc, month) => acc + month.totalTokens);
  }

  /// Calculates how much of the total budget is remaining.
  /// Returns null if no budget is configured.
  double? remainingUsd() {
    if (!hasBudget) return null;
    final total = lifetimeSpend();
    return (totalBudgetUsd! - total).clamp(0.0, totalBudgetUsd!);
  }

  /// Calculates remaining budget as a fraction 0.0–1.0.
  /// Returns null if no budget is configured.
  double? remainingFraction() {
    if (!hasBudget) return null;
    final total = lifetimeSpend();
    final remaining = totalBudgetUsd! - total;
    return (remaining / totalBudgetUsd!).clamp(0.0, 1.0);
  }

  /// True if the user has exceeded their total budget
  bool isExceeded() {
    if (!hasBudget) return false;
    final total = lifetimeSpend();
    return total > totalBudgetUsd!;
  }

  /// True if there's any recorded activity in the entire profile
  bool get hasAnyActivity =>
      alreadyUsedUsd != null || monthlyData.values.any((m) => m.hasActivity);

  // ── Serialization ─────────────────────────────────────────────────────────

  factory UsageSummaryModel.fromFirestore(Map<String, dynamic> data) {
    final rawMonthly = data['monthlyData'] as Map<String, dynamic>? ?? {};
    final Map<String, MonthlyUsageData> parsedMonthly = {};

    rawMonthly.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedMonthly[key] = MonthlyUsageData.fromMap(value);
      }
    });

    return UsageSummaryModel(
      provider: AiProviderId.fromId(
          data[FirebaseCollections.usageFieldProvider] as String? ?? 'openai'),
      enabled: data[FirebaseCollections.budgetFieldEnabled] as bool? ?? true,
      totalBudgetUsd:
          (data[FirebaseCollections.budgetFieldMonthlyBudgetUsd] as num?)
              ?.toDouble(),
      alreadyUsedUsd:
          (data[FirebaseCollections.budgetFieldAlreadyUsedUsd] as num?)
              ?.toDouble(),
      monthlyData: parsedMonthly,
      updatedAt: (data[FirebaseCollections.usageFieldUpdatedAt] as Timestamp?)
          ?.toDate(),
      rootTotalTokens:
          (data[FirebaseCollections.usageFieldTotalTokens] as num?)?.toInt(),
    );
  }
}
