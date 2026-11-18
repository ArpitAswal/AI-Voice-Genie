import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/usage_analytics_data.dart';

/// Renders the 5-Modality Feature Breakdown list for the Usage Analytics screen.
///
/// Displays granular operational workload metrics across all 5 AI capabilities:
/// 1. Text Generation (normal conversation & completions)
/// 2. Image Generation (visual synthesis via DALL-E / Imagen)
/// 3. Image Analysis (multimodal vision understanding)
/// 4. PDF Analysis (document parsing & reading)
/// 5. PDF Generation (document creation & reporting)
///
/// Each capability displays its icon, title, percentage share with a mini progress bar,
/// exact token/artifact counts, request volume, and estimated dollar expenditure.
class FeatureMetricBreakdown extends StatelessWidget {
  /// Aggregated analytics data containing capability breakdowns.
  final UsageAnalyticsData data;

  /// Whether running on tablet layout.
  final bool isTablet;

  const FeatureMetricBreakdown({
    super.key,
    required this.data,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDark;
    final l10n = context.l10n;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    // Define metadata for all 5 core capabilities in display order
    final capabilities = [
      _CapabilityMetadata(
        capability: AiCapability.textGeneration,
        label: l10n.textGeneration,
        subtitle: l10n.chatPromptCompletions,
        icon: Icons.chat_bubble_outline_rounded,
        color: const Color(0xFF4F6BFF),
      ),
      _CapabilityMetadata(
        capability: AiCapability.imageGeneration,
        label: l10n.imageGeneration,
        subtitle: l10n.dalleVisualSynthesis,
        icon: Icons.palette_outlined,
        color: const Color(0xFF8B5CF6),
      ),
      _CapabilityMetadata(
        capability: AiCapability.imageUnderstanding,
        label: l10n.imageAnalysis,
        subtitle: l10n.multimodalVisionUnderstanding,
        icon: Icons.visibility_outlined,
        color: const Color(0xFF06B6D4),
      ),
      _CapabilityMetadata(
        capability: AiCapability.pdfParsing,
        label: l10n.pdfAnalysis,
        subtitle: l10n.documentParsingReading,
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _CapabilityMetadata(
        capability: AiCapability.pdfGeneration,
        label: l10n.pdfGeneration,
        subtitle: l10n.reportDocumentCreation,
        icon: Icons.post_add_rounded,
        color: const Color(0xFF10A37F),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row: Title & Subtitle ───────────────────────────────────
          Text(
            l10n.featureModalityBreakdown,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            l10n.workloadDistributionCapabilities,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.tertiary
            ),
          ),
          const SizedBox(height: 16.0),

          // ── 5-Modality List ────────────────────────────────────────────────
          for (int i = 0; i < capabilities.length; i++) ...[
            if (i > 0) const SizedBox(height: 12.0),
            _buildCapabilityRow(context, capabilities[i]),
          ],
        ],
      ),
    );
  }

  /// Builds a single styled capability row with icon, title, percentage, metrics, and progress bar.
  Widget _buildCapabilityRow(
    BuildContext context,
    _CapabilityMetadata meta,
  ) {
    final theme = context.theme;
    final isDark = context.isDark;
    final l10n = context.l10n;

    final tokens = data.capabilityTokens[meta.capability] ?? 0;
    final cost = data.capabilityCost[meta.capability] ?? 0.0;
    final requests = data.capabilityRequests[meta.capability] ?? 0;
    final images = data.capabilityImages[meta.capability] ?? 0;
    final pdfs = data.capabilityPdfs[meta.capability] ?? 0;

    final totalTokens = data.totalTokens;
    final double fraction =
        totalTokens > 0 ? (tokens / totalTokens).clamp(0.0, 1.0) : 0.0;
    final percentString = '${(fraction * 100).toStringAsFixed(0)}%';

    // Build human-friendly operational telemetry string
    final List<String> metricsParts = [];
    if (meta.capability == AiCapability.imageGeneration && images > 0) {
      metricsParts.add('$images ${l10n.usageImages}');
    }
    if (meta.capability == AiCapability.pdfParsing && pdfs > 0) {
      metricsParts.add('$pdfs ${l10n.usagePdfs}');
    }
    metricsParts.add('${_formatCompact(tokens)} ${l10n.tokensBadge}');
    metricsParts.add('$requests ${l10n.reqsBadge}');

    final telemetryString = metricsParts.join(' · ');

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Title + Percent Badge
          Row(
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(
                  meta.icon,
                  size: 17.0,
                  color: meta.color,
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: meta.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      meta.subtitle,
                      style: TextStyle(
                        fontSize: 10.0,
                        color: context.colorScheme.tertiary
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  percentString,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: meta.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),

          // Mini Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 3.5,
              backgroundColor:  (context.theme.dividerTheme.color ??
                  context.colorScheme.tertiary)
                  .withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                fraction > 0
                    ? meta.color
                    : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
            ),
          ),
          const SizedBox(height: 8.0),

          // Bottom Row: Telemetry Counts (Left) & Estimated Cost (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  telemetryString,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                    color: cost > 0
                        ? context.colorScheme.onSurface
                        : context.colorScheme.tertiary
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '\$${cost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: cost > 0
                      ? context.colorScheme.onSurface
                      : context.colorScheme.tertiary
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact number formatter (e.g. 1.2M, 28.1K, 450).
  static String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/// Helper model for capability display metadata.
class _CapabilityMetadata {
  final AiCapability capability;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _CapabilityMetadata({
    required this.capability,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
