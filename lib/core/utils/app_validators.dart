import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../enums/app_enums.dart';
import '../localization/app_localizations.dart';

/// Centralized validator functions for AI Voice Genie.
///
/// All form validation must use these static methods.
/// No inline validation logic anywhere in the UI layer.
/// All methods return String? — null means valid.
///
/// Validators accept an optional BuildContext for localized error messages.
/// If context is null, falls back to English strings.
class Validators {
  // ── Email ─────────────────────────────────────────────────────────────────

  static String? validateEmail(
    String? value, {
    BuildContext? context,
    String? errorMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.emailRequired
          : errorMessage ?? 'Email is required';
    }

    final emailRegex = RegExp(AppConstants.emailPattern);
    if (!emailRegex.hasMatch(value.trim())) {
      return context != null
          ? context.l10n.invalidEmail
          : 'Please enter a valid email address';
    }

    return null;
  }

  // ── Required Field ────────────────────────────────────────────────────────

  static String? validateRequired(
    String? value, {
    BuildContext? context,
    String? fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.fieldRequired
          : '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  // ── AI Prompt ─────────────────────────────────────────────────────────────

  /// Validates user's AI prompt before sending
  static String? validatePrompt(String? value, {BuildContext? context}) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.promptRequired
          : 'Please enter a message';
    }

    if (value.trim().length > 10000) {
      return context != null
          ? context.l10n.promptTooLong
          : 'Message is too long (max 10,000 characters)';
    }

    return null;
  }

  // ── API Key ───────────────────────────────────────────────────────────────

  /// Validates an AI provider API key before initiating remote validation or saving.
  ///
  /// Flow:
  /// 1. Verifies non-empty input.
  /// 2. Asserts minimum key length (>= 20 characters).
  /// 3. Cross-checks known provider prefixes to prevent accidental cross-provider paste mistakes
  ///    (e.g., pasting an OpenAI key into the Gemini field).
  static String? validateApiKey(
    String? value, {
    required String providerName,
    AiProviderId? providerId,
    BuildContext? context,
  }) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.apiKeyRequired
          : 'API key is required';
    }

    final trimmed = value.trim();
    if (trimmed.length < 20) {
      return context != null
          ? context.l10n.apiKeyTooShort
          : 'This doesn\'t look like a valid $providerName API key';
    }

    // Fast client-side mismatch prevention: catch accidental cross-provider pasting
    if (providerId != null) {
      switch (providerId) {
        case AiProviderId.gemini:
          if (trimmed.startsWith('sk-') || trimmed.startsWith('sk-ant-')) {
            return 'This looks like an OpenAI or Claude key, not a Gemini key';
          }
          break;
        case AiProviderId.openAi:
          if (trimmed.startsWith('AIzaSy')) {
            return 'This looks like a Google Gemini key, not an OpenAI key';
          }
          if (trimmed.startsWith('sk-ant-')) {
            return 'This looks like an Anthropic Claude key, not an OpenAI key';
          }
          break;
        case AiProviderId.claude:
          if (trimmed.startsWith('AIzaSy')) {
            return 'This looks like a Google Gemini key, not a Claude key';
          }
          if (trimmed.startsWith('sk-proj-') ||
              (trimmed.startsWith('sk-') && !trimmed.startsWith('sk-ant-'))) {
            return 'This looks like an OpenAI key, not an Anthropic Claude key';
          }
          break;
      }
    }

    return null;
  }

  // ── Image Generation Prompt ───────────────────────────────────────────────

  /// Validates image generation prompts (stricter than regular chat prompts)
  static String? validateImagePrompt(String? value, {BuildContext? context}) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.imagePromptRequired
          : 'Please describe the image you want to generate';
    }

    if (value.trim().length < 3) {
      return context != null
          ? context.l10n.imagePromptTooShort
          : 'Please provide a more detailed description';
    }

    if (value.trim().length > 4000) {
      return context != null
          ? context.l10n.imagePromptTooLong
          : 'Image description is too long (max 4,000 characters)';
    }

    return null;
  }

  // ── Conversation Title ────────────────────────────────────────────────────

  static String? validateConversationTitle(
    String? value, {
    BuildContext? context,
  }) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? context.l10n.titleRequired
          : 'Conversation title is required';
    }

    if (value.trim().length > 100) {
      return context != null
          ? context.l10n.titleTooLong
          : 'Title must not exceed 100 characters';
    }

    return null;
  }

  // ── Date Validators ───────────────────────────────────────────────────────

  static String? validateDate(
    DateTime? date, {
    BuildContext? context,
    String? errorMessage,
  }) {
    if (date == null) {
      return context != null
          ? context.l10n.dateRequired
          : errorMessage ?? 'Date is required';
    }
    return null;
  }
}
