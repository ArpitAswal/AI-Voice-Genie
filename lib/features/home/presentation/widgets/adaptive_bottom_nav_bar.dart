import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Material 3 adaptive bottom navigation bar for compact and medium viewports.
///
/// Features:
/// - Smooth animated selection pill with theme-conscious alpha backgrounds.
/// - Full compliance with 48x48dp minimum accessible touch targets.
/// - Automatic safe area clearance using [MediaQuery.viewPaddingOf].
/// - Tactile ink ripple feedback via [InkWell] instead of rigid gestures.
class AdaptiveBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AdaptiveBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Only query bottom padding to prevent unnecessary rebuilds on other metric changes
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: bottomInset > 0 ? bottomInset : 8,
          top: 8,
          left: 12,
          right: 12,
        ),
        decoration: BoxDecoration(
          gradient: context.isDark
              ? AppColors.primaryGradientDark
              : AppColors.primaryGradientLight,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              label: context.l10n.home,
              context: context,
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.chat_bubble_outline,
              label: context.l10n.conversationHistory,
              context: context,
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.account_circle_outlined,
              label: context.l10n.profile,
              context: context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
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
          borderRadius: BorderRadius.circular(32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            // Ensure minimum 48dp height for touch accessibility
            constraints: const BoxConstraints(minHeight: 48, minWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (context.isDark
                      ? AppColors.cardDark.withValues(alpha: 0.5)
                      : AppColors.cardLight.withValues(alpha: 0.5))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
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
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
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
