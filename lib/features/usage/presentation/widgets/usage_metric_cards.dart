import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/usage_analytics_data.dart';
import '../../domain/usage_summary_model.dart';

/// Renders 4 high-level KPI summary cards for the Usage Analytics screen:
/// 1. Total Tokens (aggregate input + output volume)
/// 2. Estimated Spend (dollar cost vs configured budget cap)
/// 3. Total Requests (total interactions executed)
/// 4. Out / In Ratio (model output generation vs prompt input length)
///
/// Responsive: renders as a 2x2 grid on mobile viewports and a single 4-card
/// row on tablet / desktop layouts.
class UsageMetricCards extends StatelessWidget {
  final UsageAnalyticsData data;
  final UsageSummaryModel? activeSummary;
  final bool isTablet;

  const UsageMetricCards({
    super.key,
    required this.data,
    this.activeSummary,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // 1. Format Total Tokens with clean suffix (e.g. 3.8M, 142.5K)
    final tokensFormatted = _formatNumber(data.totalTokens);
    final inTokensFormatted = _formatNumber(data.totalInputTokens);
    final outTokensFormatted = _formatNumber(data.totalOutputTokens);

    // 2. Format Spend
    final costFormatted = '\$${data.totalCostUsd.toStringAsFixed(2)}';
    final budgetSubtitle = l10n.estBillingCost;

    // 3. Format Requests and Daily Velocity
    final reqsFormatted = data.totalRequests.toString();
    final avgReqs = data.avgRequestsPerActiveDay.round();
    final avgReqsSubtitle =
        avgReqs > 0 ? 'Avg ~$avgReqs req/day' : l10n.totalAiCompletions;

    // 4. Token Ratio
    final ratioFormatted = data.outputRatioFormatted;
    final ratioSubtitle = l10n.promptEfficiency;

    final cards = [
      _MetricCard(
        title: l10n.totalTokens,
        value: tokensFormatted,
        subtitle: 'In: $inTokensFormatted · Out: $outTokensFormatted',
        icon: Icons.data_object_rounded,
        iconColor: const Color(0xFF4F6BFF),
        badgeText: l10n.tokensBadge,
        badgeColor: const Color(0xFF4F6BFF),
      ),
      _MetricCard(
        title: l10n.estSpend,
        value: costFormatted,
        subtitle: budgetSubtitle,
        icon: Icons.payments_rounded,
        iconColor: const Color(0xFF10A37F),
        badgeText: l10n.spendBadge,
        badgeColor: const Color(0xFF10A37F),
      ),
      _MetricCard(
        title: l10n.totalReqs,
        value: reqsFormatted,
        subtitle: avgReqsSubtitle,
        icon: Icons.bolt_rounded,
        iconColor: const Color(0xFFF59E0B),
        badgeText: l10n.reqsBadge,
        badgeColor: const Color(0xFFF59E0B),
      ),
      _MetricCard(
        title: l10n.inOutRatio,
        value: ratioFormatted,
        subtitle: ratioSubtitle,
        icon: Icons.sync_alt_rounded,
        iconColor: const Color(0xFF8B5CF6),
        badgeText: l10n.ratioBadge,
        badgeColor: const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Layout adapts to available parent width: single 1x4 row on spacious viewports (>= 520dp),
        // or a balanced 2x2 grid on compact mobile screens.
        final useRow = constraints.maxWidth >= 520;
        if (useRow) {
          // Wide layout: 4 cards side-by-side in a single row
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        // Mobile & constrained tablet: 2x2 grid
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 10),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Compact number formatter (e.g. 1500 -> 1.5K, 2400000 -> 2.4M).
  static String _formatNumber(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
    }
    return count.toString();
  }
}

/// Single styled KPI summary card adhering to M3 glassmorphism guidelines.
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final Color badgeColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Icon + Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6.0, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Metric Value
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Title
          Text(
            title,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.tertiary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Subtitle / context
          Text(
            subtitle,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.tertiary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
