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

  /// Home Screen (Discovery & Superpower):
  /// Returns a concise, punchy superpower badge text for the provider.
  String superpower(AppLocalizations l10n) {
    switch (this) {
      case AiProviderId.openAi:
        return l10n.openAiSuperpower;
      case AiProviderId.gemini:
        return l10n.geminiSuperpower;
      case AiProviderId.claude:
        return l10n.claudeSuperpower;
    }
  }

  /// Home Screen (Core Highlights):
  /// Returns discrete, localized bullet points for the provider's showcase card.
  List<String> introBulletPoints(AppLocalizations l10n) {
    final raw = switch (this) {
      AiProviderId.openAi => l10n.openAiIntroBullets,
      AiProviderId.gemini => l10n.geminiIntroBullets,
      AiProviderId.claude => l10n.claudeIntroBullets,
    };
    return raw
        .split('\n')
        .map((s) => s.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
}
