import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/ai_exception.dart';
import '../../core/error/effect_bus.dart';
import '../../core/services/analytics_service.dart';
import '../../features/key_setup/domain/api_key_repository.dart';
import '../../features/key_setup/data/api_key_repository_impl.dart';
import '../adapters/ai_provider_adapter.dart';
import '../adapters/claude_adapter.dart';
import '../adapters/gemini_adapter.dart';
import '../adapters/openai_adapter.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../registry/provider_registry.dart';
import 'model_selector.dart';

/// The AI execution engine for AI Voice Genie.
///
/// This is the single entry point for all AI requests from feature layers.
/// Features call [execute()] and receive an [AiResponse] — they never know
/// which provider handled the request.
///
/// Responsibilities:
///   1. Select capable providers the user has keys for (via ModelSelector)
///   2. Retrieve API key from Firestore for each attempt
///   3. Execute the request via the correct adapter
///   4. Retry transient failures (max [AppConstants.maxRetryAttempts])
///   5. Fall back to next provider on rate limit or exhausted retries
///   6. Fire analytics events at every step
///   7. Emit via EffectBus on full exhaustion
///
/// Usage (from any feature Provider):
/// ```dart
/// final response = await AiOrchestrator.instance.execute(
///   request: AiRequest(
///     capability: AiCapability.textGeneration,
///     uid: authProvider.currentUser!.uid,
///     prompt: userMessage,
///     conversationHistory: history,
///   ),
///   userKeyedProviders: apiKeyProvider.validProviders,
/// );
/// ```
class AiOrchestrator {
  // Singleton — one orchestrator for the entire app
  static final AiOrchestrator instance = AiOrchestrator._();

  AiOrchestrator._();

  // ── Dependencies ───────────────────────────────────────────────────────────

  final ApiKeyRepository _keyRepository = ApiKeyRepositoryImpl();
  final AnalyticsService _analytics = AnalyticsService.instance;
  final ProviderRegistry _registry = ProviderRegistry.instance;

  /// Adapter map — each provider ID maps to its concrete adapter
  final Map<AiProviderId, AiProviderAdapter> _adapters = {
    AiProviderId.openAi: OpenAiAdapter(),
    AiProviderId.gemini: GeminiAdapter(),
    AiProviderId.claude: ClaudeAdapter(),
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Execute an AI request with full retry and fallback orchestration.
  ///
  /// [request]             — what to ask and which capability to use
  /// [userKeyedProviders]  — providers the user has valid API keys for
  ///
  /// Returns [AiResponse] on success.
  /// Throws [AiException] if all providers fail or the request is invalid.
  Future<AiResponse> execute({
    required AiRequest request,
    required List<AiProviderId> userKeyedProviders,
  }) async {
    debugPrint(
      '🎯 Orchestrator: ${request.capability.id} '
          '[requestId: ${request.requestId}]',
    );

    // Step 1: Check capability availability before any network calls
    if (!ModelSelector.isCapabilityAvailable(
      capability: request.capability,
      userKeyedProviders: userKeyedProviders,
    )) {
      // User has no provider with this capability
      final supportedBy = ModelSelector.providerNamesFor(request.capability);
      const error = AiExhaustedException(
        message: 'error_no_models_with_key',
        triedProviders: [],
      );

      await _analytics.logAiCapabilityGap(
        modelSelected: userKeyedProviders.isNotEmpty
            ? userKeyedProviders.first
            : AiProviderId.openAi,
        capabilityAttempted: request.capability,
      );

      debugPrint(
        '⚠️ Orchestrator: capability gap — '
            '${request.capability.id} supported by: $supportedBy',
      );

      EffectBus.instance.emit(error, StackTrace.current);
      throw error;
    }

    // Step 2: Get ordered provider list for this capability
    final orderedProviders = ModelSelector.select(
      capability: request.capability,
      userKeyedProviders: userKeyedProviders,
    );

    debugPrint(
      '📋 Orchestrator: trying providers: '
          '${orderedProviders.map((p) => p.id).join(" → ")}',
    );

    // Step 3: Try each provider in order
    final triedProviders = <AiProviderId>[];
    AiProviderId? lastFailedProvider;

    for (int i = 0; i < orderedProviders.length; i++) {
      final providerId = orderedProviders[i];
      final isLastProvider = i == orderedProviders.length - 1;
      triedProviders.add(providerId);

      // If we are falling back, log the transition
      if (lastFailedProvider != null) {
        await _analytics.logAiFallbackTriggered(
          fromModel: lastFailedProvider,
          toModel: providerId,
          reason: AiFailureType.transient,
        );
      }

      try {
        final response = await _executeWithRetry(
          request: request,
          providerId: providerId,
          isLastProvider: isLastProvider,
        );
        return response;
      } on AiHardErrorException catch (e) {
        // Hard errors do not fallback — immediately surface to caller
        debugPrint(
          '🔴 Orchestrator: hard error on ${providerId.id} — not retrying',
        );
        await _analytics.logAiRequestFailed(
          modelAttempted: providerId,
          capability: request.capability,
          failureType: AiFailureType.hardError,
          fallbackTriggered: false,
        );
        rethrow;
      } on AiRateLimitException {
        // Rate limit — skip to next provider immediately
        debugPrint(
          '⚡ Orchestrator: rate limit on ${providerId.id} — skipping',
        );
        await _analytics.logAiRequestFailed(
          modelAttempted: providerId,
          capability: request.capability,
          failureType: AiFailureType.rateLimit,
          fallbackTriggered: !isLastProvider,
        );
        lastFailedProvider = providerId;
        continue;
      } on AiTransientException {
        // Transient — retry was already attempted inside _executeWithRetry
        debugPrint(
          '🟡 Orchestrator: transient failure on ${providerId.id} — '
              '${isLastProvider ? "no more providers" : "trying next"}',
        );
        await _analytics.logAiRequestFailed(
          modelAttempted: providerId,
          capability: request.capability,
          failureType: AiFailureType.transient,
          fallbackTriggered: !isLastProvider,
        );
        lastFailedProvider = providerId;
        continue;
      }
    }

    // Step 4: All providers exhausted
    final exhaustedError = AiExhaustedException(
      message: 'error_all_models_failed',
      triedProviders: triedProviders,
    );

    debugPrint(
      '💀 Orchestrator: all providers exhausted — '
          '${triedProviders.map((p) => p.id).join(", ")}',
    );

    EffectBus.instance.emit(exhaustedError, StackTrace.current);
    throw exhaustedError;
  }

  // ── Private: Execute with Retry ────────────────────────────────────────────

  /// Execute a request on a specific provider with transient retry logic.
  ///
  /// Retries up to [AppConstants.maxRetryAttempts] times for transient errors.
  /// Adds exponential backoff between retries.
  Future<AiResponse> _executeWithRetry({
    required AiRequest request,
    required AiProviderId providerId,
    required bool isLastProvider,
  }) async {
    final adapter = _adapters[providerId]!;
    int attempt = 0;

    while (true) {
      attempt++;

      // Retrieve API key from Firestore (uses local cache after first read)
      final keyModel = await _keyRepository.loadKey(
        uid: request.uid,
        providerId: providerId,
      );

      if (keyModel == null || keyModel.apiKey.isEmpty) {
        // Key was deleted mid-session — treat as unavailable
        debugPrint(
          '⚠️ Orchestrator: no key found for ${providerId.id} — skipping',
        );
        throw AiTransientException(
          message: 'API key not found for ${providerId.displayName}',
          provider: providerId,
        );
      }

      try {
        debugPrint(
          '▶️ Orchestrator: attempt $attempt on ${providerId.id}',
        );

        await _analytics.logAiRequestInitiated(
          modelAttempted: providerId,
          capability: request.capability,
        );

        final response = await adapter.execute(
          request: request,
          apiKey: keyModel.apiKey,
        );

        await _analytics.logAiRequestSuccess(
          modelUsed: providerId,
          capability: request.capability,
          responseTimeMs: response.responseTimeMs,
          tokenCount: response.tokenCount,
        );

        debugPrint(
          '✅ Orchestrator: success on ${providerId.id} '
              '(${response.responseTimeMs}ms)',
        );

        return response;
      } on AiHardErrorException {
        // Hard errors are never retried
        rethrow;
      } on AiRateLimitException {
        // Rate limits are never retried on the same provider
        rethrow;
      } on AiTransientException {
        if (attempt >= AppConstants.maxRetryAttempts) {
          // Retries exhausted — let the caller handle fallback
          rethrow;
        }

        // Exponential backoff: 500ms, then 1000ms
        final delayMs = 500 * attempt;
        debugPrint(
          '🔄 Orchestrator: retry $attempt in ${delayMs}ms '
              '[${providerId.id}]',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  // ── Injectable Adapters (for testing) ─────────────────────────────────────

  /// Replace an adapter — used in tests to inject mock adapters.
  @visibleForTesting
  void injectAdapter(AiProviderId providerId, AiProviderAdapter adapter) {
    _adapters[providerId] = adapter;
  }
}