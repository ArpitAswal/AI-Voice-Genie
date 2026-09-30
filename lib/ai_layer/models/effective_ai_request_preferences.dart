import '../../core/enums/app_enums.dart';

/// The result of sanitizing raw saved preferences for a specific provider and
/// capability combination.
///
/// [ProviderRegistry.sanitizePreferences] returns this object. Only the fields
/// that the selected provider actually supports are populated. Unused fields
/// are null.
///
/// [ChatProvider] uses this when building [AiRequest] to ensure no
/// OpenAI-specific values bleed into a Gemini or Claude request.
class EffectiveAiRequestPreferences {
  // ── Text / Shared ───────────────────────────────────────────────────────────

  /// Max output token bound — present for all providers that support it.
  final ResponseLength? responseLength;

  // ── OpenAI Image Generation ─────────────────────────────────────────────────

  /// Generated image pixel size — OpenAI only.
  final AiImageSize? imageSize;

  /// Generated image quality tier — OpenAI only.
  final ImageQuality? imageQuality;

  /// Generated image background style — OpenAI only.
  final ImageGenerateBackground? imageBackground;

  /// Number of images to generate — OpenAI only.
  final int? imageCount;

  // ── Gemini Image Generation ─────────────────────────────────────────────────

  /// Gemini output image size tier (1K / 2K / 4K) — Gemini only.
  final GeminiImageSize? geminiImageSize;

  /// Gemini output aspect ratio (1:1, 16:9, etc.) — Gemini only.
  final GeminiAspectRatio? geminiAspectRatio;

  // ── Gemini Reasoning / Thinking ─────────────────────────────────────────────

  /// Gemini reasoning thinking level (low / medium / high) — Gemini only.
  final GeminiThinkingLevel? geminiThinkingLevel;

  // ── Vision ─────────────────────────────────────────────────────────────────

  /// Resolution hint for vision image analysis — OpenAI only.
  final VisionDetailLevel? visionDetailLevel;

  // ── Audit Trail ────────────────────────────────────────────────────────────

  /// List of preference controls that were stripped because the selected
  /// provider does not support them. Used for debug logging and analytics.
  final List<AiPreferenceControl> droppedControls;

  const EffectiveAiRequestPreferences({
    this.responseLength,
    this.imageSize,
    this.imageQuality,
    this.imageBackground,
    this.imageCount,
    this.geminiImageSize,
    this.geminiAspectRatio,
    this.geminiThinkingLevel,
    this.visionDetailLevel,
    this.droppedControls = const [],
  });

  @override
  String toString() => 'EffectiveAiRequestPreferences('
      'provider: ${droppedControls.isEmpty ? 'all supported' : 'dropped: $droppedControls'}, '
      'responseLength: $responseLength, imageSize: $imageSize, '
      'imageQuality: $imageQuality, geminiImageSize: $geminiImageSize, '
      'geminiAspectRatio: $geminiAspectRatio, geminiThinkingLevel: $geminiThinkingLevel)';
}
