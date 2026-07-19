import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../enums/app_enums.dart';
import 'build_context_extensions.dart';

extension AiProviderColorExtension on AiProviderId {
  /// Returns the brand color for this provider, adapting to the current theme brightness.
  Color brandColor(BuildContext context) {
    switch (this) {
      case AiProviderId.openAi:
        return context.isDark
            ? AppColors.openAiBrandDark
            : AppColors.openAiBrand;
      case AiProviderId.gemini:
        return context.isDark
            ? AppColors.geminiBrandDark
            : AppColors.geminiBrand;
      case AiProviderId.claude:
        return context.isDark
            ? AppColors.claudeBrandDark
            : AppColors.claudeBrand;
    }
  }
}
