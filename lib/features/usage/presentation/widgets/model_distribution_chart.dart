import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/usage_analytics_data.dart';

/// Renders the Model / Provider Distribution Donut Chart and segment breakdown list.
///
/// Visualizes the relative volume of tokens consumed across active AI providers
/// (Google Gemini, OpenAI ChatGPT, Anthropic Claude) for the selected billing month.
///
/// Features:
/// - Native Flutter [CustomPainter] donut chart without third-party dependencies.
/// - Segment arcs colored by provider brand colors ([AppColors.geminiBrand], [AppColors.openAiBrand], [AppColors.claudeBrand]).
/// - Centered aggregate token metric badge (e.g., "3.8M Tokens").
/// - Provider breakdown list with token counts, spend amounts, percentage progress bars, and tap-to-filter capability.
class ModelDistributionChart extends StatelessWidget {
  /// Aggregated analytics data containing provider tokens and costs.
  final UsageAnalyticsData data;

  /// Currently selected provider filter (null represents 'All Models').
  final AiProviderId? selectedProvider;

  /// Callback when user taps a provider segment or row to toggle filtering.
  final ValueChanged<AiProviderId?>? onProviderSelected;

  const ModelDistributionChart({
    super.key,
    required this.data,
    this.selectedProvider,
    this.onProviderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: Title ──────────────────────────────────────────────────
          Text(
            context.l10n.modelDistribution,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8.0),

          // ── Donut Chart & Breakdown Segment List ───────────────────────────
          _buildChartAndBreakdown(context, AiProviderId.values),
        ],
      ),
    );
  }

  /// Builds the donut chart alongside or above the detailed provider segment rows.
  Widget _buildChartAndBreakdown(
    BuildContext context,
    List<AiProviderId> activeEntries,
  ) {
    final isDark = context.isDark;
    final totalTokens = data.totalTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Layout adapts to allocated card width: stacks donut on very narrow constraints (< 280dp)
        final isNarrow = constraints.maxWidth < 280.0;

        final donutWidget = SizedBox(
          width: 120.0,
          height: 120.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120.0, 120.0),
                painter: _DonutChartPainter(
                  providerTokens: data.providerTokens,
                  totalTokens: totalTokens,
                  isDark: isDark,
                  selectedProvider: selectedProvider,
                ),
              ),
              // Center Label (Total Token Volume)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatCompact(totalTokens),
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w800,
                      color: context.colorScheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    context.l10n.usageTokens,
                    style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        color: context.colorScheme.tertiary),
                  ),
                ],
              ),
            ],
          ),
        );

        final breakdownWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: activeEntries.map((provider) {
            return _buildProviderSegmentRow(context, provider);
          }).toList(),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donutWidget,
              const SizedBox(height: 16.0),
              breakdownWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            donutWidget,
            const SizedBox(width: 20.0),
            Expanded(child: breakdownWidget),
          ],
        );
      },
    );
  }

  /// Builds an individual provider row with colored dot, percentage, token volume, spend, and mini progress bar.
  Widget _buildProviderSegmentRow(
    BuildContext context,
    AiProviderId provider,
  ) {
    final theme = context.theme;
    final isDark = context.isDark;

    final tokens = data.providerTokens[provider] ?? 0;
    final cost = data.providerCost[provider] ?? 0.0;
    final totalTokens = data.totalTokens;

    // Calculate percentage of total tokens (0.0 to 1.0)
    final double fraction =
        totalTokens > 0 ? (tokens / totalTokens).clamp(0.0, 1.0) : 0.0;
    final percentString = '${(fraction * 100).toStringAsFixed(0)}%';

    final brandColor = provider.brandColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: Dot + Provider Name + Percentage
          Row(
            children: [
              Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: brandColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  provider.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: brandColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                percentString,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: brandColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3.0),

          // Subtitle: Tokens + Cost
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${_formatCompact(tokens)} ${context.l10n.usageTokens}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.0,
                        color: tokens > 0
                            ? context.colorScheme.onSurface
                            : context.colorScheme.tertiary),
                  ),
                ),
                const SizedBox(width: 4.0),
                Text(
                  '\$${cost.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: tokens > 0
                          ? context.colorScheme.onSurface
                          : context.colorScheme.tertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),

          // Mini Segment Proportion Bar
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 3.0,
                backgroundColor: (context.theme.dividerTheme.color ??
                        context.colorScheme.tertiary)
                    .withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(
                  fraction > 0
                      ? brandColor
                      : (isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps an [AiProviderId] to its signature brand color.
  static Color _getProviderColor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.gemini:
        return AppColors.geminiBrand;
      case AiProviderId.openAi:
        return AppColors.openAiBrand;
      case AiProviderId.claude:
        return AppColors.claudeBrand;
    }
  }

  /// Formats raw token integer into human-friendly compact notation (e.g. 1.2M, 45.6K).
  static String _formatCompact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

/// Custom painter rendering the multi-segment circular donut chart.
class _DonutChartPainter extends CustomPainter {
  final Map<AiProviderId, int> providerTokens;
  final int totalTokens;
  final bool isDark;
  final AiProviderId? selectedProvider;

  _DonutChartPainter({
    required this.providerTokens,
    required this.totalTokens,
    required this.isDark,
    this.selectedProvider,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw Background / Empty State Track Circle
    final trackColor =
        isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (totalTokens <= 0) return;

    // 2. Draw Provider Segments
    // Start from top (-pi / 2 radians)
    double startAngle = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Calculate arc angles for each provider
    for (final provider in AiProviderId.values) {
      final tokens = providerTokens[provider] ?? 0;
      if (tokens <= 0) continue;

      final sweepAngle = (tokens / totalTokens) * 2 * math.pi;

      final isDimmed = selectedProvider != null && selectedProvider != provider;
      final baseColor = ModelDistributionChart._getProviderColor(provider);
      final segmentColor =
          isDimmed ? baseColor.withValues(alpha: 0.25) : baseColor;

      final segmentPaint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            (selectedProvider == provider) ? strokeWidth + 2 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      // Draw segment arc
      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.totalTokens != totalTokens ||
        oldDelegate.providerTokens != providerTokens ||
        oldDelegate.selectedProvider != selectedProvider ||
        oldDelegate.isDark != isDark;
  }
}
