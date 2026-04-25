import 'package:flutter/material.dart';

import '../../../../ai_layer/models/ai_request.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';

/// Three-option image size selector used in the image generator screen.
///
/// Options: Square (1:1), Landscape (16:9), Portrait (9:16)
/// Selected option is highlighted with the primary color.
class ImageSizeSelector extends StatelessWidget {
  final AiImageSize selected;
  final bool isTablet;
  final ValueChanged<AiImageSize> onSelected;

  const ImageSizeSelector({
    super.key,
    required this.selected,
    required this.isTablet,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: AiImageSize.values.map((size) {
        final isSelected = size == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onSelected(size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: isTablet ? 72 : 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryLight.withValues(alpha: 0.12)
                      : (context.isDark
                          ? AppColors.cardDark
                          : AppColors.cardLight),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryLight
                        : (context.isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Visual size ratio indicator
                    _SizeRatioIcon(size: size, isSelected: isSelected),
                    SizedBox(height: isTablet ? 6 : 4),
                    Text(
                      _sizeLabel(size),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? AppColors.primaryLight
                            : (context.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: isTablet ? 12 : 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _sizeLabel(AiImageSize size) {
    switch (size) {
      case AiImageSize.square:
        return '1:1\nSquare';
      case AiImageSize.landscape:
        return '16:9\nLandscape';
      case AiImageSize.portrait:
        return '9:16\nPortrait';
    }
  }
}

class _SizeRatioIcon extends StatelessWidget {
  final AiImageSize size;
  final bool isSelected;

  const _SizeRatioIcon({required this.size, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primaryLight
        : (context.isDark ? AppColors.darkTextSecondary : AppColors.grey);

    final (w, h) = switch (size) {
      AiImageSize.square => (20.0, 20.0),
      AiImageSize.landscape => (28.0, 16.0),
      AiImageSize.portrait => (16.0, 24.0),
    };

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
