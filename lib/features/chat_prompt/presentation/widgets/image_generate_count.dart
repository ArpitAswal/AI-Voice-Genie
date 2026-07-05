import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class ImageGenerateCountSelector extends StatelessWidget {
  final int selectedCount;
  final ValueChanged<int> onChanged;

  const ImageGenerateCountSelector({
    super.key,
    required this.selectedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      enabled: true,
      initialValue: selectedCount,
      onSelected: onChanged,
      color: context.theme.colorScheme.surface,
      elevation: 8,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      itemBuilder: (context) => List.generate(4, (index) => index + 1)
          .map(
            (count) => PopupMenuItem<int>(
              value: count,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: count == selectedCount
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: context.isDark
                            ? AppColors.white
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  if (count == selectedCount)
                    Icon(Icons.check_rounded,
                        color: context.primaryColor, size: 18),
                ],
              ),
            ),
          )
          .toList(),
      child: _SelectorPill(selectedCount: selectedCount),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final int selectedCount;

  const _SelectorPill({required this.selectedCount});

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
            '$selectedCount',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
        ],
      ),
    );
  }
}
