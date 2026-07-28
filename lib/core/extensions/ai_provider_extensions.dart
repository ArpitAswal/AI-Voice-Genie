import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../enums/app_enums.dart';
import '../localization/app_localizations.dart';
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

extension AiProviderModelInfoExtension on AiProviderId {
  /// Returns tailored capabilities info for Intro/Home screen
  String capabilitiesInfo(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiCapabilitiesInfo;
      case AiProviderId.gemini:
        return l10n.geminiCapabilitiesInfo;
      case AiProviderId.claude:
        return l10n.claudeCapabilitiesInfo;
    }
  }

  /// Returns active models & technical specs for Manage API Keys screen
  String technicalSpecs(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiTechSpecs;
      case AiProviderId.gemini:
        return l10n.geminiTechSpecs;
      case AiProviderId.claude:
        return l10n.claudeTechSpecs;
    }
  }

  /// Returns pricing & efficiency info for AI Intelligence / Usage screen
  String pricingAndEfficiency(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiPricingInfo;
      case AiProviderId.gemini:
        return l10n.geminiPricingInfo;
      case AiProviderId.claude:
        return l10n.claudePricingInfo;
    }
  }
}

