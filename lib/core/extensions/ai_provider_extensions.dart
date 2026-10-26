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

  /// Returns the brand gradient for this provider, adapting to the current theme brightness.
  LinearGradient brandGradient(BuildContext context) {
    switch (this) {
      case AiProviderId.openAi:
       return AppColors.openAIGradient;
      case AiProviderId.gemini:
         return AppColors.geminiGradient;
      case AiProviderId.claude:
        return AppColors.claudeGradient;
    }
  }
}

extension AiProviderModelInfoExtension on AiProviderId {
  /// Home Screen (Discovery & Motivation):
  /// Returns a punchy, user-focused marketing message describing what the user
  /// can achieve with this specific AI provider rather than technical jargon.
  String marketingPitch(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiMarketingPitch;
      case AiProviderId.gemini:
        return l10n.geminiMarketingPitch;
      case AiProviderId.claude:
        return l10n.claudeMarketingPitch;
    }
  }

  /// Profile Tab (AI Intelligence Section):
  /// Returns clean bullet points highlighting active user-facing capabilities
  /// (e.g. Image Generation, Voice Transcription, Code, Vision).
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

  /// Key Setup Screen:
  /// Returns a transparent model-to-purpose mapping so users understand
  /// exactly which underlying model is invoked for chat, images, and audio.
  String modelPurposes(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiModelPurposes;
      case AiProviderId.gemini:
        return l10n.geminiModelPurposes;
      case AiProviderId.claude:
        return l10n.claudeModelPurposes;
    }
  }
}
