import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Material 3 adaptive side NavigationRail for expanded viewports (Tablets in landscape & Desktop).
///
/// Ergonomics:
/// - Replaces bottom navigation bar on wide viewports to save vertical content height.
/// - Adheres strictly to the 48dp touch target standard with ink ripple feedback.
/// - Brand theming harmonized directly with the mobile bottom navigation bar
///   (gradient background, consistent active pill translucency, and uppercase typography).
/// - Primary voice trigger is delegated solely to the IntroScreen bottom-right FAB,
///   eliminating duplicate/confusing voice triggers on large viewports.
class AdaptiveNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AdaptiveNavRail({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final itemColor =
        context.isDark ? AppColors.primaryLight : AppColors.primaryDark;

    return Container(
      width: context.screenWidth * 0.1,
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              (context.isDark ? AppColors.tealAccent : AppColors.cyanAccent)
                  .withValues(alpha: 0.3),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(
            right: BorderSide(
              color: context.theme.dividerColor,
              width: 5,
            ),
          ),
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(21))),
      child: SafeArea(
        top: topPadding > 0,
        bottom: true,
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Brand Avatar / Header Icon
            Container(
              width: context.iconAvatar,
              height: context.iconAvatar,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: context.isDark
                    ? AppColors.darkVoiceGradient
                    : AppColors.lightVoiceGradient,
                boxShadow: [
                  BoxShadow(
                    color: itemColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Navigation Destinations
            _buildRailItem(
              index: 0,
              icon: Icons.home_outlined,
              label: context.l10n.home,
              context: context,
            ),
            const SizedBox(height: 16),
            _buildRailItem(
              index: 1,
              icon: Icons.chat_bubble_outline,
              label: context.l10n.conversationHistory,
              context: context,
            ),
            const SizedBox(height: 16),
            _buildRailItem(
              index: 2,
              icon: Icons.account_circle_outlined,
              label: context.l10n.profile,
              context: context,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    final isSelected = currentIndex == index;
    final itemColor =
        context.isDark ? AppColors.primaryLight : AppColors.primaryDark;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(minWidth: 76, minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (context.isDark
                      ? AppColors.cardDark.withValues(alpha: 0.5)
                      : AppColors.cardLight.withValues(alpha: 0.5))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: context.iconStandard,
                  color: itemColor,
                ),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: itemColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.5,
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
