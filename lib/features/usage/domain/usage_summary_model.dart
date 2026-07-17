import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Aggregated monthly usage summary per provider.
///
/// Document ID format: "{providerId}_{monthKey}" — e.g. "openai_2026-07"
/// Firestore path: AI_Voice_Genie/Users/User_Model/{uid}/usageSummaries/{docId}
///
/// Updated atomically using Firestore [FieldValue.increment] after each request,
/// so concurrent writes from multiple devices are safely merged.
class UsageSummaryModel {
  /// AI provider these stats belong to
  final AiProviderId provider;

  /// Month key: "2026-07"
  final String monthKey;

  // ── Request Volume ──────────────────────────────────────────────────────────

  /// Total number of AI requests completed this month
  final int requestCount;

  // ── Token Usage ─────────────────────────────────────────────────────────────

  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  // ── Attachment Counts ────────────────────────────────────────────────────────

  final int imageCount;
  final int pdfCount;

  // ── Cost ─────────────────────────────────────────────────────────────────────

  /// Cumulative estimated cost in USD for this month
  final double estimatedCostUsd;

  /// When the document was last updated (Firestore server timestamp)
  final DateTime? updatedAt;

  const UsageSummaryModel({
    required this.provider,
    required this.monthKey,
    this.requestCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.imageCount = 0,
    this.pdfCount = 0,
    this.estimatedCostUsd = 0.0,
    this.updatedAt,
  });

  /// Firestore document ID for this summary
  String get docId => '${provider.id}_$monthKey';

  /// True if there's any recorded activity this month
  bool get hasActivity => requestCount > 0 || totalTokens > 0 || imageCount > 0;

  /// Increment map for Firestore atomic updates (never overwrites, only adds)
  Map<String, dynamic> toIncrementMap() {
    return {
      FirebaseCollections.usageFieldProvider: provider.id,
      FirebaseCollections.usageFieldMonthKey: monthKey,
      FirebaseCollections.summaryFieldRequestCount: FieldValue.increment(1),
      FirebaseCollections.usageFieldInputTokens:
          FieldValue.increment(inputTokens),
      FirebaseCollections.usageFieldOutputTokens:
          FieldValue.increment(outputTokens),
      FirebaseCollections.usageFieldTotalTokens:
          FieldValue.increment(totalTokens),
      FirebaseCollections.usageFieldImageCount:
          FieldValue.increment(imageCount),
      FirebaseCollections.usageFieldPdfCount: FieldValue.increment(pdfCount),
      FirebaseCollections.summaryFieldEstimatedCostUsd:
          FieldValue.increment(estimatedCostUsd),
      FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  factory UsageSummaryModel.fromFirestore(Map<String, dynamic> data) {
    return UsageSummaryModel(
      provider: AiProviderId.fromId(
          data[FirebaseCollections.usageFieldProvider] as String? ?? 'openai'),
      monthKey: data[FirebaseCollections.usageFieldMonthKey] as String? ?? '',
      requestCount: (data[FirebaseCollections.summaryFieldRequestCount] as num?)
              ?.toInt() ??
          0,
      inputTokens:
          (data[FirebaseCollections.usageFieldInputTokens] as num?)?.toInt() ??
              0,
      outputTokens:
          (data[FirebaseCollections.usageFieldOutputTokens] as num?)?.toInt() ??
              0,
      totalTokens:
          (data[FirebaseCollections.usageFieldTotalTokens] as num?)?.toInt() ??
              0,
      imageCount:
          (data[FirebaseCollections.usageFieldImageCount] as num?)?.toInt() ??
              0,
      pdfCount:
          (data[FirebaseCollections.usageFieldPdfCount] as num?)?.toInt() ?? 0,
      estimatedCostUsd:
          (data[FirebaseCollections.summaryFieldEstimatedCostUsd] as num?)
                  ?.toDouble() ??
              0.0,
      updatedAt: (data[FirebaseCollections.usageFieldUpdatedAt] as Timestamp?)
          ?.toDate(),
    );
  }

  /// Human-readable spend, e.g. "\$2.80"
  String get formattedCost => '\$${estimatedCostUsd.toStringAsFixed(2)}';

  @override
  String toString() => 'UsageSummaryModel(${provider.id} $monthKey — '
      'requests: $requestCount, tokens: $totalTokens, cost: $formattedCost)';
}
