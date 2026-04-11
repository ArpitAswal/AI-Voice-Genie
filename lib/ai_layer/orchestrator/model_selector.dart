import '../../core/enums/app_enums.dart';
import '../registry/provider_registry.dart';

/// Pure stateless model selector for the AI orchestration layer.
///
/// Takes a capability and the list of providers the user has keys for,
/// and returns an ordered list of providers that can handle the request.
///
/// Rules applied in order:
///   1. Filter: only providers with a valid user key
///   2. Filter: only providers that support the requested capability
///   3. Sort:   by priority ascending (lowest number = tried first)
///
/// Returns an empty list if no provider matches — the orchestrator
/// handles this as AiExhaustedException.
///
/// Why a separate class instead of a method on AiOrchestrator?
///   - Pure function — no side effects, no state, no async
///   - Independently testable without mocking the entire orchestrator
///   - Follows Single Responsibility Principle
///
/// Usage:
/// ```dart
/// final ordered = ModelSelector.select(
///   capability: AiCapability.imageGeneration,
///   userKeyedProviders: [AiProviderId.openAi, AiProviderId.claude],
/// );
/// // Returns [openAi] — claude filtered out (no imageGen support)
/// ```
class ModelSelector {
  // Private constructor — this class is never instantiated
  ModelSelector._();

  /// Select and order providers for a given capability.
  ///
  /// [capability]          — what the request needs to do
  /// [userKeyedProviders]  — providers the user has valid API keys for
  /// [registry]            — the capability matrix source (injectable for testing)
  static List<AiProviderId> select({
    required AiCapability capability,
    required List<AiProviderId> userKeyedProviders,
    ProviderRegistry? registry,
  }) {
    final reg = registry ?? ProviderRegistry.instance;

    // Step 1: Get all providers that support this capability, sorted by priority
    final capableConfigs = reg.providersFor(capability);

    // Step 2: Filter to only providers the user has keys for
    final userKeyedSet = userKeyedProviders.toSet();
    final eligible = capableConfigs
        .where((config) => userKeyedSet.contains(config.providerId))
        .toList();

    // Return just the provider IDs in priority order
    return eligible.map((c) => c.providerId).toList();
  }

  /// Check if any provider available to the user supports a capability.
  ///
  /// Used to show capability gap messages in the UI before attempting
  /// a request — avoids making the user wait for a guaranteed failure.
  ///
  /// ```dart
  /// if (!ModelSelector.isCapabilityAvailable(
  ///   capability: AiCapability.imageGeneration,
  ///   userKeyedProviders: [AiProviderId.claude],
  /// )) {
  ///   // Show capability gap message immediately
  /// }
  /// ```
  static bool isCapabilityAvailable({
    required AiCapability capability,
    required List<AiProviderId> userKeyedProviders,
    ProviderRegistry? registry,
  }) {
    return select(
      capability: capability,
      userKeyedProviders: userKeyedProviders,
      registry: registry,
    ).isNotEmpty;
  }

  /// Get a human-readable list of providers that support a capability.
  ///
  /// Used in capability gap messages:
  /// "image generation is supported by: ChatGPT, Gemini"
  static List<String> providerNamesFor(
      AiCapability capability, {
        ProviderRegistry? registry,
      }) {
    final reg = registry ?? ProviderRegistry.instance;
    return reg
        .providersFor(capability)
        .map((c) => c.providerId.displayName)
        .toList();
  }
}