import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/app_enums.dart';
import '../../core/extensions/build_context_extensions.dart';

class DefaultValueDropdownSelector<T> extends StatelessWidget {
  final T selectedValue;
  final List<T> options;
  final ValueChanged<T> onChanged;

  /// Function to get the main title string for an option
  final String Function(T) getTitle;

  /// Optional function to get a suffix string appended to the title
  final String Function(T)? getTitleSuffix;

  /// Optional function to get a subtitle/description string for an option
  final String Function(T)? getSubtitle;

  const DefaultValueDropdownSelector({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    required this.getTitle,
    this.getTitleSuffix,
    this.getSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      enabled: true,
      initialValue: selectedValue,
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
      menuPadding: const EdgeInsetsGeometry.symmetric(vertical: 8),
      itemBuilder: (context) => options.map((option) {
        final title = getTitle(option);
        final suffix = getTitleSuffix?.call(option);
        final fullTitle = suffix != null ? "$title $suffix" : title;
        final subtitle = getSubtitle?.call(option);

        return PopupMenuItem<T>(
          value: option,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.white
                          : AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fullTitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: option == selectedValue
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: context.isDark
                            ? AppColors.white
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  if (option == selectedValue)
                    Icon(
                      Icons.check_rounded,
                      color: context.isDark
                          ? AppColors.white
                          : AppColors.primaryLight,
                      size: context.textTheme.bodyMedium?.fontSize,
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding / 2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: context.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(context.screenWidth * 0.05),
          border: Border.all(
            color: context.isDark
                ? context.theme.colorScheme.primary
                : context.theme.colorScheme.secondary,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(getTitle(selectedValue),
                style: context.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: context.textTheme.bodySmall?.fontSize,
                color: context.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

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
    return DefaultValueDropdownSelector<AiImageSize>(
      selectedValue: selectedSize,
      options: AiImageSize.values,
      onChanged: onChanged,
      getTitle: (size) => size.name,
    );
  }
}

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
    return DefaultValueDropdownSelector<int>(
      selectedValue: selectedCount,
      options: const [1, 2, 3, 4],
      onChanged: onChanged,
      getTitle: (count) => count.toString(),
    );
  }
}

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
    return DefaultValueDropdownSelector<VisionDetailLevel>(
      selectedValue: selectedLevel,
      options: VisionDetailLevel.values,
      onChanged: onChanged,
      getTitle: (level) => level.displayName,
    );
  }
}

class ImageBackgroundSelector extends StatelessWidget {
  final ImageGenerateBackground selectedBackground;
  final ValueChanged<ImageGenerateBackground> onChanged;

  const ImageBackgroundSelector({
    super.key,
    required this.selectedBackground,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultValueDropdownSelector<ImageGenerateBackground>(
      selectedValue: selectedBackground,
      options: ImageGenerateBackground.values,
      onChanged: onChanged,
      getTitle: (bg) => bg.displayName,
    );
  }
}

class ModelImageQualitySelector extends StatelessWidget {
  final ImageQuality selectedQuality;
  final ValueChanged<ImageQuality> onChanged;

  const ModelImageQualitySelector({
    super.key,
    required this.selectedQuality,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultValueDropdownSelector<ImageQuality>(
      selectedValue: selectedQuality,
      options: ImageQuality.values,
      onChanged: onChanged,
      getTitle: (quality) => quality.value,
    );
  }
}

class ResponseLengthSelector extends StatelessWidget {
  final ResponseLength selectedLength;
  final ValueChanged<ResponseLength> onChanged;
  final AiProviderId? provider;

  const ResponseLengthSelector({
    super.key,
    required this.selectedLength,
    required this.onChanged,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultValueDropdownSelector<ResponseLength>(
      selectedValue: selectedLength,
      options: ResponseLength.values,
      onChanged: onChanged,
      getTitle: (length) => length.displayName,
      getTitleSuffix: (length) {
        final tokens =
            provider != null ? length.tokensFor(provider!) : length.maxTokens;
        return "($tokens tokens)";
      },
      getSubtitle: (length) => length.description,
    );
  }
}
