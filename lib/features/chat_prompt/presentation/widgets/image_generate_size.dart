import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class AiImageSizeSelector extends StatelessWidget {
  final AiImageSize selectedSize;
  final ValueChanged<AiImageSize> onChanged;

  const AiImageSizeSelector({
    super.key,
    required this.selectedSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AiImageSize>(
      enabled: true,
      initialValue: selectedSize,
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
      itemBuilder: (context) => AiImageSize.values
          .map(
            (size) => PopupMenuItem<AiImageSize>(
              value: size,
              child: _SizeMenuItem(
                size: size,
                isSelected: size == selectedSize,
              ),
            ),
          )
          .toList(),
      child: _SelectorPill(selectedSize: selectedSize),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final AiImageSize selectedSize;

  const _SelectorPill({required this.selectedSize});

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
            selectedSize.name,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
           Icon(Icons.keyboard_arrow_down_rounded, size: 16,
            color: context.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _SizeMenuItem extends StatelessWidget {
  final AiImageSize size;
  final bool isSelected;

  const _SizeMenuItem({
    required this.size,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            size.apiValue,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.primaryLight,
            ),
          ),
        ),
        if (isSelected)
          Icon(
            Icons.check_rounded,
            color: context.primaryColor,
            size: 18,
          ),
      ],
    );
  }
}
