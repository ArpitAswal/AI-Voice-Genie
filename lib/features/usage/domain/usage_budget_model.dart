import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Optional monthly budget per AI provider set by the user.
///
/// Document ID = providerId (e.g. "openai", "gemini", "claude")
/// Firestore path: AI_Voice_Genie/Users/User_Model/{uid}/usageBudgets/{providerId}
class UsageBudgetModel {
  /// AI provider this budget applies to
  final AiProviderId provider;

  /// Monthly budget ceiling in USD (null = no budget set)
  final double? monthlyBudgetUsd;

  /// Whether this budget is actively enforced/shown
  final bool enabled;

  /// When this budget was last updated
  final DateTime? updatedAt;

  const UsageBudgetModel({
    required this.provider,
    this.monthlyBudgetUsd,
    this.enabled = true,
    this.updatedAt,
  });

  /// True if a budget value has been entered
  bool get hasBudget =>
      enabled && monthlyBudgetUsd != null && monthlyBudgetUsd! > 0;

  /// Calculates how much is remaining.
  /// Returns null if no budget is configured.
  double? remainingUsd(double spentUsd) {
    if (!hasBudget) return null;
    return (monthlyBudgetUsd! - spentUsd).clamp(0.0, monthlyBudgetUsd!);
  }

  /// Calculates remaining as a fraction 0.0–1.0.
  /// Returns null if no budget is configured.
  double? remainingFraction(double spentUsd) {
    if (!hasBudget) return null;
    final remaining = monthlyBudgetUsd! - spentUsd;
    return (remaining / monthlyBudgetUsd!).clamp(0.0, 1.0);
  }

  /// True if the user has exceeded their monthly budget
  bool isExceeded(double spentUsd) => hasBudget && spentUsd > monthlyBudgetUsd!;

  /// Human-readable budget, e.g. "\$10.00"
  String get formattedBudget =>
      hasBudget ? '\$${monthlyBudgetUsd!.toStringAsFixed(2)}' : 'No budget';

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.usageFieldProvider: provider.id,
      FirebaseCollections.budgetFieldMonthlyBudgetUsd: monthlyBudgetUsd,
      FirebaseCollections.budgetFieldEnabled: enabled,
      FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  factory UsageBudgetModel.fromFirestore(Map<String, dynamic> data) {
    return UsageBudgetModel(
      provider: AiProviderId.fromId(
          data[FirebaseCollections.usageFieldProvider] as String? ?? 'openai'),
      monthlyBudgetUsd:
          (data[FirebaseCollections.budgetFieldMonthlyBudgetUsd] as num?)
              ?.toDouble(),
      enabled: data[FirebaseCollections.budgetFieldEnabled] as bool? ?? true,
      updatedAt: (data[FirebaseCollections.usageFieldUpdatedAt] as Timestamp?)
          ?.toDate(),
    );
  }

  UsageBudgetModel copyWith({
    double? monthlyBudgetUsd,
    bool? enabled,
  }) {
    return UsageBudgetModel(
      provider: provider,
      monthlyBudgetUsd: monthlyBudgetUsd ?? this.monthlyBudgetUsd,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  String toString() =>
      'UsageBudgetModel(${provider.id} — budget: $formattedBudget, enabled: $enabled)';
}
