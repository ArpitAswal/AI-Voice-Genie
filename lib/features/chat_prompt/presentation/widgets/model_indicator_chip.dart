import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

/// Small chip displayed above AI response bubbles.
///
/// Shows which AI model generated the response.
/// Color-coded per provider brand.
class ModelIndicatorChip extends StatelessWidget {
  final AiProviderId provider;
  final bool isTablet;

  const ModelIndicatorChip({
    super.key,
    required this.provider,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, icon) = _providerStyle(provider);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 8,
        vertical: isTablet ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 18 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            provider.displayName,
            style: context.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: isTablet ? 14 : 10,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _providerStyle(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return (
          AppColors.openAiBrand,
          AppColors.openAiBrand,
          Icons.auto_awesome_rounded,
        );
      case AiProviderId.gemini:
        return (
          AppColors.geminiBrand,
          AppColors.white,
          Icons.diamond_outlined,
        );
      case AiProviderId.claude:
        return (
          AppColors.claudeBrand,
          AppColors.claudeBrand,
          Icons.psychology_outlined,
        );
    }
  }
}
