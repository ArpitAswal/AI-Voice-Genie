import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../models/ai_model_capability_profile.dart';
import '../models/ai_provider_config.dart';
import '../models/effective_ai_request_preferences.dart';

/// Registry of all AI providers and their capability configurations.
///
/// This is the single source of truth for:
///   - Which capabilities each provider supports (via [AiProviderConfig])
///   - The priority order in which they are tried
///   - Their context window sizes
///   - Which preference controls appear in the UI (via [AiModelCapabilityProfile])
///   - How raw preferences are sanitized before an [AiRequest] is built
///
/// ModelSelector reads from this registry to build the ordered
/// provider list for each request.
///
/// To add a new provider: add entries to [_configs] and [_capabilityProfiles].
/// Zero changes needed in orchestrator or features.
///
/// Capability Matrix (routing level):
/// ┌──────────┬─────────┬──────────┬────────────┬────────────┐
/// │ Provider │ TextGen │ ImageGen │ ImageRead  │ PdfParsing │
/// ├──────────┼─────────┼──────────┼────────────┼────────────┤
/// │ OpenAI   │   ✅    │   ✅     │    ✅       │    ✅      │
/// │ Gemini   │   ✅    │   ✅     │    ✅       │    ✅      │
/// │ Claude   │   ✅    │   ❌     │    ✅       │    ✅      │
/// └──────────┴─────────┴──────────┴────────────┴────────────┘
///
/// Preference Capability Matrix (UI & request sanitization):
/// ┌───────────────────┬────────┬────────┬────────┐
/// │ Control           │ OpenAI │ Gemini │ Claude │
/// ├───────────────────┼────────┼────────┼────────┤
/// │ responseLength    │  ✅    │  ✅    │  ✅    │
/// │ imageSize         │  ✅    │  ❌    │  ❌    │
/// │ imageQuality      │  ✅    │  ❌    │  ❌    │
/// │ imageBackground   │  ✅    │  ❌    │  ❌    │
/// │ imageCount        │  ✅    │  ❌    │  ❌    │
/// │ visionImageCount  │  ✅    │  ✅    │  ✅    │
/// │ visionPdfCount    │  ✅    │  ✅    │  ✅    │
/// │ visionDetailLevel │  ✅    │  ❌    │  ❌    │
/// └───────────────────┴────────┴────────┴────────┘
class ProviderRegistry {
  // Singleton — one registry instance for the entire app lifetime
  static final ProviderRegistry instance = ProviderRegistry._();
  ProviderRegistry._();

  /// All provider configurations — keyed by provider ID for O(1) lookup
  final Map<AiProviderId, AiProviderConfig> _configs = {
    AiProviderId.openAi: const AiProviderConfig(
      providerId: AiProviderId.openAi,
      supportedCapabilities: {
        AiCapability.textGeneration,
        AiCapability.imageGeneration,
        AiCapability.imageUnderstanding,
        AiCapability.pdfParsing,
      },
      priority: 1,
      contextWindowTokens: AppConstants.openAiContextTokenLimit,
    ),
    AiProviderId.gemini: const AiProviderConfig(
      providerId: AiProviderId.gemini,
      supportedCapabilities: {
        AiCapability.textGeneration,
        AiCapability.imageGeneration,
        AiCapability.imageUnderstanding,
        AiCapability.pdfParsing,
      },
      priority: 2,
      contextWindowTokens: AppConstants.geminiContextTokenLimit,
    ),
    AiProviderId.claude: const AiProviderConfig(
      providerId: AiProviderId.claude,
      // Claude does NOT support image generation — this is a hard API limitation
      // Any request for imageGeneration routed here triggers AiCapabilityGapException
      supportedCapabilities: {
        AiCapability.textGeneration,
        AiCapability.imageUnderstanding,
        AiCapability.pdfParsing,
      },
      priority: 3,
      contextWindowTokens: AppConstants.claudeContextTokenLimit,
    ),
  };

  /// Preference-level capability profiles — keyed by provider ID.
  ///
  /// These are used by [ProfileAiPreferencesPanel] for UI visibility and by
  /// [sanitizePreferences] to strip unsupported values before [AiRequest] is built.
  final Map<AiProviderId, AiModelCapabilityProfile> _capabilityProfiles = {
    AiProviderId.openAi: const AiModelCapabilityProfile(
      providerId: AiProviderId.openAi,
      visiblePreferenceControls: {
        AiPreferenceControl.preferredProvider,
        AiPreferenceControl.responseLength,
        AiPreferenceControl.imageSize,
        AiPreferenceControl.imageQuality,
        AiPreferenceControl.imageBackground,
        AiPreferenceControl.imageCount,
        AiPreferenceControl.visionImageCount,
        AiPreferenceControl.visionPdfCount,
        AiPreferenceControl.visionDetailLevel,
      },
      maxImageCount: 4,
      maxVisionImageCount: 4,
      maxVisionPdfCount: 4,
      usesGeminiImageFormat: false,
    ),
    AiProviderId.gemini: const AiModelCapabilityProfile(
      providerId: AiProviderId.gemini,
      // Gemini 3.8 Flash supports thinkingLevel; Gemini 3.1 Flash-Lite Image supports aspectRatio.
      visiblePreferenceControls: {
        AiPreferenceControl.preferredProvider,
        AiPreferenceControl.responseLength,
        AiPreferenceControl.geminiThinkingLevel,
        AiPreferenceControl.geminiAspectRatio,
        AiPreferenceControl.visionImageCount,
        AiPreferenceControl.visionPdfCount,
      },
      maxImageCount: 1, // Gemini generates 1 image per request
      maxVisionImageCount: 4,
      maxVisionPdfCount: 4,
      usesGeminiImageFormat: true,
    ),
    AiProviderId.claude: const AiModelCapabilityProfile(
      providerId: AiProviderId.claude,
      // Claude has no image generation capability — hide all image gen controls.
      // Vision detail level is also hidden because the Claude adapter does not
      // use the OpenAI-style detail parameter.
      visiblePreferenceControls: {
        AiPreferenceControl.preferredProvider,
        AiPreferenceControl.responseLength,
        AiPreferenceControl.visionImageCount,
        AiPreferenceControl.visionPdfCount,
      },
      maxImageCount: 0,
      maxVisionImageCount: 4,
      maxVisionPdfCount: 4,
      usesGeminiImageFormat: false,
    ),
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Get the routing config for a specific provider.
  AiProviderConfig? configFor(AiProviderId providerId) => _configs[providerId];

  /// Get the preference-level capability profile for a specific provider.
  ///
  /// Falls back to the most restrictive (Claude-level) profile if the provider
  /// is not found, so the UI hides rather than shows unsupported controls.
  AiModelCapabilityProfile profileFor(AiProviderId providerId) =>
      _capabilityProfiles[providerId] ??
      const AiModelCapabilityProfile(
        providerId: AiProviderId.claude,
        visiblePreferenceControls: {
          AiPreferenceControl.preferredProvider,
          AiPreferenceControl.responseLength,
        },
      );

  /// Get all registered provider configs as a list.
  List<AiProviderConfig> get allConfigs => _configs.values.toList();

  /// Get all providers that support a given capability,
  /// sorted by priority ascending (lowest priority number = first).
  List<AiProviderConfig> providersFor(AiCapability capability) {
    return _configs.values
        .where((config) => config.supports(capability))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Whether a specific provider supports a given capability.
  bool supports(AiProviderId providerId, AiCapability capability) {
    return _configs[providerId]?.supports(capability) ?? false;
  }

  /// Get the context window size for a provider.
  int contextWindowFor(AiProviderId providerId) {
    return _configs[providerId]?.contextWindowTokens ?? 4096;
  }

  /// Sanitize raw [AiPreferencesProvider] values for the given [providerId]
  /// and [capability], returning only the values that are safe to send.
  ///
  /// Any preference control not in [AiModelCapabilityProfile.visiblePreferenceControls]
  /// is stripped and recorded in [EffectiveAiRequestPreferences.droppedControls].
  ///
  /// Call this in [ChatProvider.sendMessage] after resolving the chat-time
  /// selected provider, BEFORE constructing [AiRequest].
  EffectiveAiRequestPreferences sanitizePreferences(
      {required AiProviderId providerId,
      required AiCapability capability,
      required ResponseLength rawResponseLength,
      required AiImageSize rawImageSize,
      required ImageQuality rawImageQuality,
      required ImageGenerateBackground rawImageBackground,
      required int rawImageCount,
      required VisionDetailLevel rawVisionDetailLevel,
      GeminiThinkingLevel? rawGeminiThinkingLevel,
      GeminiAspectRatio? rawGeminiAspectRatio}) {
    final profile = profileFor(providerId);
    final dropped = <AiPreferenceControl>[];

    // ── Response Length ───────────────────────────────────────────────────────
    final ResponseLength? effectiveResponseLength =
        profile.supports(AiPreferenceControl.responseLength)
            ? rawResponseLength
            : null;
    if (!profile.supports(AiPreferenceControl.responseLength)) {
      dropped.add(AiPreferenceControl.responseLength);
    }

    // ── Gemini Thinking Level ─────────────────────────────────────────────────
    final isText = capability == AiCapability.textGeneration;
    final GeminiThinkingLevel? effectiveGeminiThinkingLevel =
        (isText && profile.supports(AiPreferenceControl.geminiThinkingLevel))
            ? (rawGeminiThinkingLevel ?? GeminiThinkingLevel.medium)
            : null;
    if (isText && !profile.supports(AiPreferenceControl.geminiThinkingLevel)) {
      dropped.add(AiPreferenceControl.geminiThinkingLevel);
    }

    // For non-image-generation capabilities, always drop image-gen fields
    final isImageGen = capability == AiCapability.imageGeneration;

    // ── Gemini Image Aspect Ratio ─────────────────────────────────────────────
    final GeminiAspectRatio? effectiveGeminiAspectRatio =
        (isImageGen && profile.supports(AiPreferenceControl.geminiAspectRatio))
            ? (rawGeminiAspectRatio ?? GeminiAspectRatio.square)
            : null;
    if (isImageGen &&
        !profile.supports(AiPreferenceControl.geminiAspectRatio)) {
      dropped.add(AiPreferenceControl.geminiAspectRatio);
    }

    // ── OpenAI Image Size ─────────────────────────────────────────────────────
    final AiImageSize? effectiveImageSize =
        (isImageGen && profile.supports(AiPreferenceControl.imageSize))
            ? rawImageSize
            : null;
    if (isImageGen && !profile.supports(AiPreferenceControl.imageSize)) {
      dropped.add(AiPreferenceControl.imageSize);
    }

    // ── OpenAI Image Quality ──────────────────────────────────────────────────
    final ImageQuality? effectiveImageQuality =
        (isImageGen && profile.supports(AiPreferenceControl.imageQuality))
            ? rawImageQuality
            : null;
    if (isImageGen && !profile.supports(AiPreferenceControl.imageQuality)) {
      dropped.add(AiPreferenceControl.imageQuality);
    }

    // ── OpenAI Image Background ───────────────────────────────────────────────
    final ImageGenerateBackground? effectiveImageBackground =
        (isImageGen && profile.supports(AiPreferenceControl.imageBackground))
            ? rawImageBackground
            : null;
    if (isImageGen && !profile.supports(AiPreferenceControl.imageBackground)) {
      dropped.add(AiPreferenceControl.imageBackground);
    }

    // ── OpenAI Image Count ────────────────────────────────────────────────────
    final int? effectiveImageCount =
        (isImageGen && profile.supports(AiPreferenceControl.imageCount))
            ? rawImageCount.clamp(1, profile.maxImageCount)
            : null;
    if (isImageGen && !profile.supports(AiPreferenceControl.imageCount)) {
      dropped.add(AiPreferenceControl.imageCount);
    }

    // ── Vision Detail Level ───────────────────────────────────────────────────
    final isVision = capability == AiCapability.imageUnderstanding;
    final VisionDetailLevel? effectiveVisionDetail =
        (isVision && profile.supports(AiPreferenceControl.visionDetailLevel))
            ? rawVisionDetailLevel
            : null;
    if (isVision && !profile.supports(AiPreferenceControl.visionDetailLevel)) {
      dropped.add(AiPreferenceControl.visionDetailLevel);
    }

    return EffectiveAiRequestPreferences(
      responseLength: effectiveResponseLength,
      imageSize: effectiveImageSize,
      imageQuality: effectiveImageQuality,
      imageBackground: effectiveImageBackground,
      imageCount: effectiveImageCount,
      geminiAspectRatio: effectiveGeminiAspectRatio,
      geminiThinkingLevel: effectiveGeminiThinkingLevel,
      visionDetailLevel: effectiveVisionDetail,
      droppedControls: dropped,
    );
  }
}
