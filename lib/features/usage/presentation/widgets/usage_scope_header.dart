import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/loading_overlay.dart';
import '../usage_analytics_provider.dart';
import 'month_year_picker_dialog.dart';

/// Renders the Scope Header controls for the Usage Analytics screen:
/// 1. Billing Month Selector (e.g. "October 2026").
/// 2. AI Model Filter Chips ("All Models", "Google Gemini", "ChatGPT", "Claude").
/// 3. Modality Filter Chips ("All", "Text Generation", "Image Generation", etc.).
///
/// All filter adjustments update [UsageAnalyticsProvider] reactively, triggering
/// instantaneous in-memory re-computation of charts and metrics without network overhead.
class UsageScopeHeader extends StatelessWidget {
  /// The active analytics state management provider.
  final UsageAnalyticsProvider provider;

  /// Authenticated user ID for month queries and data refresh.
  final String? uid;

  const UsageScopeHeader({
    super.key,
    required this.provider,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final selectedMonthKey = provider.selectedMonthKey;
    final availableMonths = provider.availableMonths;
    final selectedProvider = provider.selectedProvider;
    final selectedCapability = provider.selectedCapability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Month Selector Row ───────────────────────────────────────────────
        Row(
          children: [
            // Month Calendar Picker Interactive Pill
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: uid == null
                    ? null
                    : () async {
                        final picked = await showMonthYearPicker(
                          context: context,
                          initialMonthKey: selectedMonthKey,
                          availableMonths: availableMonths,
                        );
                        if (picked != null &&
                            picked != selectedMonthKey &&
                            context.mounted) {
                          final isCached = provider.isMonthCached(picked);
                          if (!isCached) {
                            LoadingOverlay.show(context,
                                message: context.l10n.loadingMonthlyData);
                          }
                          try {
                            await provider.loadEvents(uid!, monthKey: picked);
                          } finally {
                            if (!isCached) {
                              LoadingOverlay.hide();
                            }
                          }
                        }
                      },
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: context.isCompact ? 16.0 : 21,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 8.0),
                      Text(_formatMonthKey(selectedMonthKey),
                          style: (context.isCompact
                                  ? context.textTheme.bodyMedium
                                  : context.textTheme.bodyLarge)
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6.0),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: context.isCompact ? 16.0 : 21.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // ── Model Filter Chips Row ───────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // All Models chip
              _buildModelChip(
                label: context.l10n.allModels,
                isSelected: selectedProvider == null,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                onTap: () => provider.setProviderFilter(null),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // Individual Providers
              ...AiProviderId.values.map((p) {
                final isSelected = selectedProvider == p;
                final color = _getProviderColor(p);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildModelChip(
                    label: p.displayName,
                    isSelected: isSelected,
                    color: color,
                    onTap: () => provider.setProviderFilter(p),
                    isDark: isDark,
                    ctx: context,
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8.0),

        // ── Modality / Capability Filter Chips Row ────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // All Modalities chip
              _buildModalityChip(
                label: context.l10n.allModalities,
                isSelected: selectedCapability == null,
                onTap: () => provider.setCapabilityFilter(null),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // Text / Chat Generation
              _buildModalityChip(
                label: context.l10n.textGeneration,
                isSelected: selectedCapability == AiCapability.textGeneration,
                onTap: () =>
                    provider.setCapabilityFilter(AiCapability.textGeneration),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // Image Generation
              _buildModalityChip(
                label: context.l10n.imageGeneration,
                isSelected: selectedCapability == AiCapability.imageGeneration,
                onTap: () =>
                    provider.setCapabilityFilter(AiCapability.imageGeneration),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // Image Analysis / Understanding
              _buildModalityChip(
                label: context.l10n.imageAnalysis,
                isSelected:
                    selectedCapability == AiCapability.imageUnderstanding,
                onTap: () => provider
                    .setCapabilityFilter(AiCapability.imageUnderstanding),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // PDF Analysis / Reading
              _buildModalityChip(
                label: context.l10n.pdfAnalysis,
                isSelected: selectedCapability == AiCapability.pdfParsing,
                onTap: () =>
                    provider.setCapabilityFilter(AiCapability.pdfParsing),
                isDark: isDark,
                ctx: context,
              ),
              const SizedBox(width: 8.0),

              // PDF Generation
              _buildModalityChip(
                label: context.l10n.pdfGeneration,
                isSelected: selectedCapability == AiCapability.pdfGeneration,
                onTap: () =>
                    provider.setCapabilityFilter(AiCapability.pdfGeneration),
                isDark: isDark,
                ctx: context,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a pill chip for model/provider selection.
  Widget _buildModelChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required BuildContext ctx,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 44.0),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: (ctx.isCompact
                  ? ctx.textTheme.labelMedium
                  : ctx.textTheme.labelLarge)
              ?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : ctx.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }

  /// Builds a pill chip for capability/modality selection.
  Widget _buildModalityChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required BuildContext ctx,
  }) {
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 44.0),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: (ctx.isCompact
                  ? ctx.textTheme.labelMedium
                  : ctx.textTheme.labelLarge)
              ?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : ctx.colorScheme.tertiary,
          ),
        ),
      ),
    );
  }

  /// Formats month keys such as '2026-10' into 'October 2026'.
  static String _formatMonthKey(String monthKey) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final monthIndex = int.tryParse(parts[1]);
      if (monthIndex != null && monthIndex >= 1 && monthIndex <= 12) {
        return '${months[monthIndex - 1]} $year';
      }
    }
    return monthKey;
  }

  /// Maps an [AiProviderId] to its brand color.
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
}
