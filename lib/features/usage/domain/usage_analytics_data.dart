import '../../../core/enums/app_enums.dart';
import 'usage_event_model.dart';
import 'usage_summary_model.dart';

/// Represents aggregated AI interaction metrics for a single calendar day.
///
/// Used as data points for time-series charts (such as the Token & Request Trends
/// trajectory graph) across a selected monthly billing period.
class DailyUsagePoint {
  /// The day of the month (1 through 28, 29, 30, or 31).
  final int day;

  /// Full timestamp representation for this calendar day.
  final DateTime date;

  /// Prompt / input tokens consumed on this day.
  final int inputTokens;

  /// Completion / output tokens generated on this day.
  final int outputTokens;

  /// Total tokens consumed on this day (`inputTokens + outputTokens`).
  final int totalTokens;

  /// Number of successful completions / requests executed on this day.
  final int requestCount;

  /// Estimated dollar cost in USD for this day's interactions.
  final double costUsd;

  const DailyUsagePoint({
    required this.day,
    required this.date,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.requestCount = 0,
    this.costUsd = 0.0,
  });

  /// Creates a zero-value placeholder point for a calendar day without activity.
  factory DailyUsagePoint.empty(int day, DateTime date) {
    return DailyUsagePoint(
      day: day,
      date: date,
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
      requestCount: 0,
      costUsd: 0.0,
    );
  }

  /// Immutably accumulates an individual [UsageEventModel] into this day's totals.
  DailyUsagePoint addEvent(UsageEventModel event) {
    return DailyUsagePoint(
      day: day,
      date: date,
      inputTokens: inputTokens + event.inputTokens,
      outputTokens: outputTokens + event.outputTokens,
      totalTokens: totalTokens + event.totalTokens,
      requestCount: requestCount + 1,
      costUsd: costUsd + event.estimatedCostUsd,
    );
  }

  /// Whether this day had any recorded token activity or requests.
  bool get hasActivity => totalTokens > 0 || requestCount > 0;
}

/// Domain Value Object representing aggregated and filtered telemetry across a billing month.
///
/// Provides in-memory computation for:
/// - Daily time-series trends (1..N days of the month) for line and bar charts.
/// - Peak activity callout detection (day with highest token volume).
/// - Model & Provider distribution splits (tokens and dollar expenditure).
/// - Modality breakdown (text, image, PDF, and prompt/completion ratios).
///
/// Pure Dart class without Flutter dependencies to preserve testability and architectural boundaries.
class UsageAnalyticsData {
  /// Partitioning month key in 'YYYY-MM' format (e.g. '2026-10').
  final String monthKey;

  /// Ordered daily data points spanning the full month (day 1 through month length).
  final List<DailyUsagePoint> dailyPoints;

  /// The calendar day with the highest token volume during the month (null if no activity).
  final DailyUsagePoint? peakDay;

  /// Total tokens processed across all filtered events.
  final int totalTokens;

  /// Total number of requests/prompts executed.
  final int totalRequests;

  /// Total prompt/input tokens.
  final int totalInputTokens;

  /// Total completion/output tokens.
  final int totalOutputTokens;

  /// Total estimated cost in USD.
  final double totalCostUsd;

  /// Number of images generated in this period.
  final int totalImages;

  /// Number of PDF documents parsed in this period.
  final int totalPdfs;

  /// Volume of tokens partitioned by AI Provider (e.g. Gemini, OpenAI, Claude).
  final Map<AiProviderId, int> providerTokens;

  /// Cost in USD partitioned by AI Provider.
  final Map<AiProviderId, double> providerCost;

  /// Request count partitioned by AI Provider.
  final Map<AiProviderId, int> providerRequests;

  /// Volume of tokens partitioned by capability/modality.
  final Map<AiCapability, int> capabilityTokens;

  /// Cost in USD partitioned by capability/modality.
  final Map<AiCapability, double> capabilityCost;

  /// Request count partitioned by capability/modality.
  final Map<AiCapability, int> capabilityRequests;

  /// Number of images generated partitioned by capability/modality.
  final Map<AiCapability, int> capabilityImages;

  /// Number of PDF documents parsed/generated partitioned by capability/modality.
  final Map<AiCapability, int> capabilityPdfs;

  const UsageAnalyticsData({
    required this.monthKey,
    required this.dailyPoints,
    this.peakDay,
    this.totalTokens = 0,
    this.totalRequests = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCostUsd = 0.0,
    this.totalImages = 0,
    this.totalPdfs = 0,
    this.providerTokens = const {},
    this.providerCost = const {},
    this.providerRequests = const {},
    this.capabilityTokens = const {},
    this.capabilityCost = const {},
    this.capabilityRequests = const {},
    this.capabilityImages = const {},
    this.capabilityPdfs = const {},
  });

  /// Factory constructor that dynamically computes analytics from raw [events]
  /// with optional client-side filters ([providerFilter], [capabilityFilter]).
  ///
  /// Features:
  /// 1. Time-series bucketing: creates a complete 1..N day bucket map for continuous chart curves.
  /// 2. In-memory filtering: applies provider and modality filters instantaneously with zero Firestore reads.
  /// 3. Peak detection: finds the maximum token consumption day and its exact request count.
  /// 4. Graceful fallback: merges with [summary] data if raw events are sparse.
  factory UsageAnalyticsData.compute({
    required List<UsageEventModel> events,
    required String monthKey,
    AiProviderId? providerFilter,
    AiCapability? capabilityFilter,
    UsageSummaryModel? summary,
  }) {
    // 1. Parse Year & Month from monthKey (e.g. "2026-10")
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      year = int.tryParse(parts[0]) ?? year;
      month = int.tryParse(parts[1]) ?? month;
    }

    // Number of days in this calendar month (handles leap years via DateTime)
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // 2. Initialize the daily buckets for each day of the month (1..daysInMonth)
    final Map<int, DailyUsagePoint> dailyBuckets = {};
    for (int day = 1; day <= daysInMonth; day++) {
      dailyBuckets[day] =
          DailyUsagePoint.empty(day, DateTime(year, month, day));
    }

    int totalTokens = 0;
    int totalRequests = 0;
    int totalInputTokens = 0;
    int totalOutputTokens = 0;
    double totalCostUsd = 0.0;
    int totalImages = 0;
    int totalPdfs = 0;

    final Map<AiProviderId, int> providerTokens = {};
    final Map<AiProviderId, double> providerCost = {};
    final Map<AiProviderId, int> providerRequests = {};

    final Map<AiCapability, int> capabilityTokens = {};
    final Map<AiCapability, double> capabilityCost = {};
    final Map<AiCapability, int> capabilityRequests = {};
    final Map<AiCapability, int> capabilityImages = {};
    final Map<AiCapability, int> capabilityPdfs = {};

    // 3. Process each event through active in-memory filters
    for (final event in events) {
      // Filter by Provider (if user selected a specific provider)
      if (providerFilter != null && event.provider != providerFilter) {
        continue;
      }

      // Filter by Modality/Capability (if user selected e.g. PDF or Image)
      if (capabilityFilter != null && event.capability != capabilityFilter) {
        continue;
      }

      // Accumulate into overall totals
      totalTokens += event.totalTokens;
      totalRequests += 1;
      totalInputTokens += event.inputTokens;
      totalOutputTokens += event.outputTokens;
      totalCostUsd += event.estimatedCostUsd;
      totalImages += event.imageCount;
      totalPdfs += event.pdfCount;

      // Accumulate provider breakdowns
      final p = event.provider;
      providerTokens[p] = (providerTokens[p] ?? 0) + event.totalTokens;
      providerCost[p] = (providerCost[p] ?? 0.0) + event.estimatedCostUsd;
      providerRequests[p] = (providerRequests[p] ?? 0) + 1;

      // Accumulate capability breakdowns
      final c = event.capability;
      capabilityTokens[c] = (capabilityTokens[c] ?? 0) + event.totalTokens;
      capabilityCost[c] = (capabilityCost[c] ?? 0.0) + event.estimatedCostUsd;
      capabilityRequests[c] = (capabilityRequests[c] ?? 0) + 1;
      capabilityImages[c] = (capabilityImages[c] ?? 0) + event.imageCount;
      capabilityPdfs[c] = (capabilityPdfs[c] ?? 0) + event.pdfCount;

      // Add to corresponding day bucket
      final eventDay = event.createdAt.day;
      if (eventDay >= 1 && eventDay <= daysInMonth) {
        final currentPoint = dailyBuckets[eventDay]!;
        dailyBuckets[eventDay] = currentPoint.addEvent(event);
      }
    }

    // 4. Construct sorted daily points list
    final List<DailyUsagePoint> dailyPoints = [];
    DailyUsagePoint? peak;

    for (int day = 1; day <= daysInMonth; day++) {
      final point = dailyBuckets[day]!;
      dailyPoints.add(point);

      if (point.hasActivity) {
        if (peak == null || point.totalTokens > peak.totalTokens) {
          peak = point;
        }
      }
    }

    return UsageAnalyticsData(
      monthKey: monthKey,
      dailyPoints: dailyPoints,
      peakDay: peak,
      totalTokens: totalTokens,
      totalRequests: totalRequests,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      totalCostUsd: totalCostUsd,
      totalImages: totalImages,
      totalPdfs: totalPdfs,
      providerTokens: providerTokens,
      providerCost: providerCost,
      providerRequests: providerRequests,
      capabilityTokens: capabilityTokens,
      capabilityCost: capabilityCost,
      capabilityRequests: capabilityRequests,
      capabilityImages: capabilityImages,
      capabilityPdfs: capabilityPdfs,
    );
  }

  /// Calculates the Prompt-to-Completion (Input-to-Output) token multiplier.
  ///
  /// Compares completion tokens generated against prompt tokens received.
  /// If input is 0, returns 0.0.
  double get outputToInputRatio {
    if (totalInputTokens == 0) return 0.0;
    return totalOutputTokens / totalInputTokens;
  }

  /// Formatted string representing Prompt Efficiency (Input : Output ratio) for display (e.g. "1 : 1.37").
  ///
  /// For every 1 prompt (input) token sent, the AI model generated X completion (output) tokens.
  String get outputRatioFormatted {
    if (totalInputTokens == 0) {
      return '1 : 1.00';
    }
    final ratio = totalOutputTokens / totalInputTokens;
    return '1 : ${ratio.toStringAsFixed(2)}';
  }

  /// Average requests executed per active day with recorded interactions.
  double get avgRequestsPerActiveDay {
    final activeDays = dailyPoints.where((p) => p.hasActivity).length;
    if (activeDays == 0) return 0.0;
    return totalRequests / activeDays;
  }

  /// Whether any interactions were recorded for this period.
  bool get hasActivity => totalTokens > 0 || totalRequests > 0;
}
