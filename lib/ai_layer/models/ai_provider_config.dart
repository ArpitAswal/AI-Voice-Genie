import '../../core/enums/app_enums.dart';

/// Configuration for a single AI provider.
///
/// Holds the provider's capability set and priority ranking.
/// Used by ModelSelector to determine which providers can handle
/// a given request and in what order to try them.
///
/// Immutable — defined once in ProviderRegistry, never mutated.
class AiProviderConfig {
  /// Which provider this config describes
  final AiProviderId providerId;

  /// Set of capabilities this provider supports.
  ///
  /// The orchestrator checks this BEFORE making any HTTP call.
  /// If the requested capability is not in this set, the provider
  /// is skipped with an AiCapabilityGapException — no network call.
  final Set<AiCapability> supportedCapabilities;

  /// Selection priority — lower number = tried first.
  ///
  /// OpenAI = 1 (best overall capability coverage)
  /// Gemini  = 2 (strong free tier)
  /// Claude  = 3 (no image generation — always last resort)
  final int priority;

  /// Maximum context window in tokens for this provider.
  /// Used for context truncation before sending.
  final int contextWindowTokens;

  const AiProviderConfig({
    required this.providerId,
    required this.supportedCapabilities,
    required this.priority,
    required this.contextWindowTokens,
  });

  /// Whether this provider supports a given capability.
  bool supports(AiCapability capability) =>
      supportedCapabilities.contains(capability);

  @override
  String toString() =>
      'AiProviderConfig(${providerId.id}, priority: $priority, '
          'capabilities: ${supportedCapabilities.map((c) => c.id).join(", ")})';
}