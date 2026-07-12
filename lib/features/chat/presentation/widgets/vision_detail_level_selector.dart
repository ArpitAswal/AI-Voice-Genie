import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class VisionDetailLevelSelector extends StatelessWidget {
  final VisionDetailLevel selectedLevel;
  final ValueChanged<VisionDetailLevel> onChanged;

  const VisionDetailLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VisionDetailLevel>(
      enabled: true,
      initialValue: selectedLevel,
      onSelected: onChanged,
      color: context.isDark ? AppColors.cardDark : AppColors.white,
      elevation: 8,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      itemBuilder: (context) => VisionDetailLevel.values
          .map(
            (level) => PopupMenuItem<VisionDetailLevel>(
              value: level,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      level.displayName,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: level == selectedLevel
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: context.isDark
                            ? AppColors.white
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  if (level == selectedLevel)
                    Icon(Icons.check_rounded,
                        color: context.primaryColor, size: 18),
                ],
              ),
            ),
          )
          .toList(),
      child: _SelectorPill(level: selectedLevel),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final VisionDetailLevel level;

  const _SelectorPill({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding / 2,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            level.displayName,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: context.primaryColor),
        ],
      ),
    );
  }
}
