import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../models/ai_provider_config.dart';

/// Registry of all AI providers and their capability configurations.
///
/// This is the single source of truth for:
///   - Which capabilities each provider supports
///   - The priority order in which they are tried
///   - Their context window sizes
///
/// ModelSelector reads from this registry to build the ordered
/// provider list for each request.
///
/// To add a new provider: add a new entry to [_configs].
/// Zero changes needed in orchestrator, adapters, or features.
///
/// Capability Matrix:
/// ┌──────────┬─────────┬──────────┬────────────┬────────────┐
/// │ Provider │ TextGen │ ImageGen │ ImageRead  │ PdfParsing │
/// ├──────────┼─────────┼──────────┼────────────┼────────────┤
/// │ OpenAI   │   ✅    │   ✅     │    ✅       │    ✅      │
/// │ Gemini   │   ✅    │   ✅     │    ✅       │    ✅      │
/// │ Claude   │   ✅    │   ❌     │    ✅       │    ✅      │
/// └──────────┴─────────┴──────────┴────────────┴────────────┘
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

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Get the config for a specific provider.
  AiProviderConfig? configFor(AiProviderId providerId) =>
      _configs[providerId];

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
}