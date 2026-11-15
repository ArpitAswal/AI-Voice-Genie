import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../viewmodel/intro_viewmodel.dart';

/// Interactive quick action chips allowing one-tap exploration.
///
/// Ergonomics:
/// - Tablet & Desktop (>=600dp): Static horizontal row (all chips sit side-by-side with zero scroll).
/// - Mobile (<600dp): Single-row horizontal scroll view, eliminating orphan chips and saving ~55dp of vertical height.
/// - Tactile Material 3 ink ripple with guaranteed hit targets (minHeight: 48dp).
/// - Declarative, DRY action mapping.
class QuickActionsSection extends StatelessWidget {
  final ValueChanged<QuickActionType> onActionSelected;
  final bool isShortHeight;

  const QuickActionsSection({
    super.key,
    required this.onActionSelected,
    this.isShortHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    // Declarative action configuration
    final actions = [
      (
        type: QuickActionType.askQuestion,
        icon: Icons.question_answer_rounded,
        label: context.l10n.askQuestion,
        iconColor: AppColors.tealAccent,
      ),
      (
        type: QuickActionType.summarizePdf,
        icon: Icons.upload_file_rounded,
        label: context.l10n.summarizePdf,
        iconColor: AppColors.voiceActive,
      ),
      (
        type: QuickActionType.generateImage,
        icon: Icons.palette_rounded,
        label: context.l10n.generateImage,
        iconColor: AppColors.purpleAccent,
      ),
      (
        type: QuickActionType.analyzeImage,
        icon: Icons.image_search_rounded,
        label: context.l10n.analyzeImage,
        iconColor: AppColors.primaryLight,
      ),
      (
        type: QuickActionType.generatePdf,
        icon: Icons.picture_as_pdf_rounded,
        label: context.l10n.generatePdf,
        iconColor: AppColors.lightError,
      ),
      (
        type: QuickActionType.generateCode,
        icon: Icons.code_rounded,
        label: context.l10n.generateCode,
        iconColor: const Color(0xFF6C63FF),
      ),
    ];

    final chipWidgets = actions.map((item) {
      return _QuickActionChip(
        icon: item.icon,
        label: item.label,
        iconColor: item.iconColor,
        onTap: () => onActionSelected(item.type),
        isShortHeight: isShortHeight,
      );
    }).toList();

    final chipsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: chipWidgets.asMap().entries.map((entry) {
        final isLast = entry.key == chipWidgets.length - 1;
        return Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
          child: entry.value,
        );
      }).toList(),
    );

    final wrapLayout = Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: chipWidgets,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          context.l10n.askTodo,
          style: (context.isCompact
                  ? context.textTheme.titleSmall
                  : context.textTheme.titleMedium)
              ?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurface,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),

        // Responsive Adaptive Chips Layout:
        // - Landscape Tablet & Desktop (>= 840dp): Wrap (spans width naturally without horizontal scrolling)
        // - Mobile & Tablet Portrait (< 840dp): Single-row horizontal scroll view (conserves vertical height)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840.0 || context.isExpanded;
            if (isWide) {
              return wrapLayout;
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              child: chipsRow,
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isShortHeight;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    required this.isShortHeight,
  });

  double _iconSize(BuildContext context) {
    if (context.isCompact && isShortHeight) {
      return 18.0;
    }
    return context.isTablet ? 22.0 : 20.0;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isShortHeight ? 8 : 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: _iconSize(context)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: (context.isCompact
                          ? (isShortHeight
                              ? context.textTheme.labelMedium
                              : context.textTheme.bodyMedium)
                          : context.textTheme.bodyLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
