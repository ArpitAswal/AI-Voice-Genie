
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class ModelImageSize extends StatelessWidget {
  final ImageGenerateSize selectedSize;
  final ValueChanged<ImageGenerateSize> onChanged;

  const ModelImageSize(
      {required this.selectedSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ImageGenerateSize>(
      enabled: true,
      initialValue: selectedSize,
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
      itemBuilder: (context) => ImageGenerateSize.values
          .map(
            (provider) => PopupMenuItem<ImageGenerateSize>(
          value: provider,
          child: _ProviderMenuItem(
            provider: provider,
            isSelected: provider == selectedSize,
          ),
        ),
      )
          .toList(),
      child: _SelectorPill(
        provider: selectedSize,
        isEnabled: true,
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final ImageGenerateSize? provider;
  final bool isEnabled;

  const _SelectorPill({
    required this.provider,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding / 2,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            provider?.name ?? '',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _ProviderMenuItem extends StatelessWidget {
  final ImageGenerateSize provider;
  final bool isSelected;

  const _ProviderMenuItem({
    required this.provider,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: Text(
            provider.name,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.primaryLight,
            ),
          ),
        ),
        if (isSelected)
          Icon(
            Icons.check_rounded,
            size: 18,
          ),
      ],
    );
  }
}
