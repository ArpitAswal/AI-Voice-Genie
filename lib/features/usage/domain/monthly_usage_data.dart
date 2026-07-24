import '../../../core/constants/firebase_collections.dart';

/// Represents usage statistics for a specific month.
class MonthlyUsageData {
  final int requestCount;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int imageCount;
  final int pdfCount;
  final double estimatedCostUsd;

  const MonthlyUsageData({
    this.requestCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.imageCount = 0,
    this.pdfCount = 0,
    this.estimatedCostUsd = 0.0,
  });

  /// Creates an empty record.
  factory MonthlyUsageData.empty() => const MonthlyUsageData();

  factory MonthlyUsageData.fromMap(Map<String, dynamic> data) {
    return MonthlyUsageData(
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      FirebaseCollections.summaryFieldRequestCount: requestCount,
      FirebaseCollections.usageFieldInputTokens: inputTokens,
      FirebaseCollections.usageFieldOutputTokens: outputTokens,
      FirebaseCollections.usageFieldTotalTokens: totalTokens,
      FirebaseCollections.usageFieldImageCount: imageCount,
      FirebaseCollections.usageFieldPdfCount: pdfCount,
      FirebaseCollections.summaryFieldEstimatedCostUsd: estimatedCostUsd,
    };
  }

  /// True if there's any recorded activity this month
  bool get hasActivity => requestCount > 0 || totalTokens > 0 || imageCount > 0;

  /// Human-readable spend, e.g. "\$2.80"
  String get formattedCost => '\$${estimatedCostUsd.toStringAsFixed(2)}';
}
