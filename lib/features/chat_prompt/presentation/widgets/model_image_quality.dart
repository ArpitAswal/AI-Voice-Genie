import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

class ModelImageQuality extends StatelessWidget {
  final ImageQuality selectedQuality;
  final ValueChanged<ImageQuality> onChanged;

  const ModelImageQuality({
    super.key,
    required this.selectedQuality,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ImageQuality>(
      enabled: true,
      initialValue: selectedQuality,
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
      itemBuilder: (context) => ImageQuality.values
          .map(
            (provider) => PopupMenuItem<ImageQuality>(
              value: provider,
              child: _ProviderMenuItem(
                provider: provider,
                isSelected: provider == selectedQuality,
              ),
            ),
          )
          .toList(),
      child: _SelectorPill(
        provider: selectedQuality,
        isEnabled: true,
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final ImageQuality? provider;
  final bool isEnabled;

  const _SelectorPill({
    required this.provider,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        provider == null ? AppColors.grey : _ProviderStyle.colorFor(provider!);

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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _labelFor(context, provider),
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isEnabled ? color : context.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isEnabled ? color : context.textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }
}

class _ProviderMenuItem extends StatelessWidget {
  final ImageQuality provider;
  final bool isSelected;

  const _ProviderMenuItem({
    required this.provider,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = _ProviderStyle.colorFor(provider);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _labelFor(context, provider),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.primaryLight,
            ),
          ),
        ),
        if (isSelected)
          Icon(
            Icons.check_rounded,
            color: color,
            size: 18,
          ),
      ],
    );
  }
}

abstract final class _ProviderStyle {
  static Color colorFor(ImageQuality provider) {
    switch (provider) {
      case ImageQuality.Low:
        return AppColors.success;
      case ImageQuality.Medium:
        return AppColors.warning;
      case ImageQuality.High:
        return AppColors.error;
    }
  }
}

String _labelFor(BuildContext context, ImageQuality? quality) {
  final l10n = AppLocalizations.of(context)!;
  switch (quality) {
    case ImageQuality.Low:
      return l10n.qualityLow;
    case ImageQuality.Medium:
      return l10n.qualityMedium;
    case ImageQuality.High:
      return l10n.qualityHigh;
    case null:
      return l10n.imageQuality;
  }
}
