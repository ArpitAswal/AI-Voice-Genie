import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';

/// Centralized AI provider pricing table.
///
/// All prices are in USD per million tokens unless otherwise noted.
/// Update these values when provider pricing changes.
///
/// Sources (as of 2025-07):
///   OpenAI: https://openai.com/api/pricing/
///   Gemini: https://ai.google.dev/pricing
///   Claude: https://www.anthropic.com/pricing
abstract final class UsagePricingTable {
  // ── OpenAI GPT-4o ────────────────────────────────────────────────────────────

  /// GPT-4o input: $2.50 per 1M tokens
  static const double openAiGpt4oInputPerMillion = 2.50;

  /// GPT-4o output: $10.00 per 1M tokens
  static const double openAiGpt4oOutputPerMillion = 10.00;

  // ── OpenAI Image Generation (gpt-image-1) ───────────────────────────────────
  // Price per image generated at each quality level

  /// Low quality image: $0.011 per image (1024×1024)
  static const double openAiImageLowPerImage = 0.011;

  /// Medium quality image: $0.042 per image
  static const double openAiImageMediumPerImage = 0.042;

  /// High quality image: $0.167 per image
  static const double openAiImageHighPerImage = 0.167;

  // ── Gemini 2.5 Flash ─────────────────────────────────────────────────────────

  /// Gemini 2.5 Flash input: $0.30 per 1M tokens
  static const double geminiFlashInputPerMillion = 0.30;

  /// Gemini 2.5 Flash output: $2.50 per 1M tokens
  static const double geminiFlashOutputPerMillion = 2.50;

  // ── Claude 3.5 Sonnet ────────────────────────────────────────────────────────

  /// Claude 3.5 Sonnet input: $3.00 per 1M tokens
  static const double claudeSonnetInputPerMillion = 3.00;

  /// Claude 3.5 Sonnet output: $15.00 per 1M tokens
  static const double claudeSonnetOutputPerMillion = 15.00;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the input price per million tokens for a given provider.
  /// Returns null if pricing is unknown (cost estimate will be hidden).
  static double? inputPricePerMillion(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return openAiGpt4oInputPerMillion;
      case AiProviderId.gemini:
        return geminiFlashInputPerMillion;
      case AiProviderId.claude:
        return claudeSonnetInputPerMillion;
    }
  }

  /// Returns the output price per million tokens for a given provider.
  static double? outputPricePerMillion(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return openAiGpt4oOutputPerMillion;
      case AiProviderId.gemini:
        return geminiFlashOutputPerMillion;
      case AiProviderId.claude:
        return claudeSonnetOutputPerMillion;
    }
  }

  /// Returns the image generation price per image for a given quality.
  /// Only applies to OpenAI (Gemini image pricing is approximate).
  static double imageGenerationPrice(
    AiProviderId provider,
    ImageQuality quality,
  ) {
    // OpenAI gpt-image-1 has explicit per-quality pricing
    if (provider == AiProviderId.openAi) {
      switch (quality) {
        case ImageQuality.low:
          return openAiImageLowPerImage;
        case ImageQuality.medium:
          return openAiImageMediumPerImage;
        case ImageQuality.high:
          return openAiImageHighPerImage;
      }
    }
    // Gemini image gen: approximate at low quality price
    return openAiImageLowPerImage;
  }

  /// Model string shown on the profile/usage card for a provider
  static String modelName(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppConstants.openAiTextModel;
      case AiProviderId.gemini:
        return AppConstants.geminiTextModel;
      case AiProviderId.claude:
        return AppConstants.claudeTextModel;
    }
  }
}
