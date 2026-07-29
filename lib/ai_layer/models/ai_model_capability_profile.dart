import '../../core/enums/app_enums.dart';

/// Describes the preference-level capability of a specific AI provider.
///
/// This is the single source of truth for:
///   - Which preference controls to show in [ProfileAiPreferencesPanel].
///   - Which preference values are safe to include in an [AiRequest] for this
///     provider, used by [ProviderRegistry.sanitizePreferences].
///
/// Unlike [AiProviderConfig] which tracks high-level capability routing
/// (textGeneration / imageGeneration / vision / pdf), this profile operates
/// at the preference-control level — it answers "what can the user configure?"
class AiModelCapabilityProfile {
  /// The provider this profile describes.
  final AiProviderId providerId;

  /// The set of preference controls that should be visible for this provider.
  ///
  /// [ProfileAiPreferencesPanel] checks this set to decide whether to render
  /// each row. If a control is not in this set, its row is never shown.
  final Set<AiPreferenceControl> visiblePreferenceControls;

  /// Max supported image count per generation request.
  /// Only applies when [AiPreferenceControl.imageCount] is in [visiblePreferenceControls].
  final int maxImageCount;

  /// Max supported vision image attachments per message.
  final int maxVisionImageCount;

  /// Max supported PDF attachments per message.
  final int maxVisionPdfCount;

  /// Whether this provider uses Gemini-specific [GeminiAspectRatio] and
  /// [GeminiImageSize] fields instead of OpenAI's [AiImageSize].
  ///
  /// When true, the image preference UI shows aspect-ratio and tier selectors
  /// instead of the pixel-dimension [AiImageSizeSelector].
  final bool usesGeminiImageFormat;

  const AiModelCapabilityProfile({
    required this.providerId,
    required this.visiblePreferenceControls,
    this.maxImageCount = 1,
    this.maxVisionImageCount = 4,
    this.maxVisionPdfCount = 4,
    this.usesGeminiImageFormat = false,
  });

  /// Whether a specific preference control is supported by this provider.
  bool supports(AiPreferenceControl control) =>
      visiblePreferenceControls.contains(control);
}
