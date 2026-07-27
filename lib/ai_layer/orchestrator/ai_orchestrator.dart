import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/ai_exception.dart';
import '../../core/error/effect_bus.dart';
import '../../core/services/analytics_service.dart';
import '../../features/key_setup/domain/api_key_repository.dart';
import '../../features/key_setup/data/api_key_repository_impl.dart';
import '../../features/usage/data/usage_cost_estimator.dart';
import '../../features/usage/data/usage_pricing_table.dart';
import '../../features/usage/domain/usage_repository.dart';
import '../../features/usage/data/usage_repository_impl.dart';
import '../../features/usage/domain/usage_event_model.dart';
import '../adapters/ai_provider_adapter.dart';
import '../adapters/claude_adapter.dart';
import '../adapters/gemini_adapter.dart';
import '../adapters/openai_adapter.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../registry/provider_registry.dart';

/// The AI execution engine for AI Voice Genie.
///
/// This is the single entry point for all AI requests from feature layers.
/// Features call [execute()] and receive an [AiResponse] — they never know
/// which provider handled the request.
///
/// Responsibilities:
///   1. Validate the selected provider can handle the requested capability
///   2. Retrieve that provider's API key from Firestore
///   3. Execute the request via the correct adapter
///   4. Retry transient failures (max [AppConstants.maxRetryAttempts])
///   5. Fire analytics events at every step
///   6. Emit via EffectBus on selected-model exhaustion
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
///   selectedProvider: selectedProvider,
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
  final EffectBus _effectBus = EffectBus.instance;
  final UsageRepository _usageRepo = UsageRepositoryImpl();

  /// Adapter map — each provider ID maps to its concrete adapter
  final Map<AiProviderId, AiProviderAdapter> _adapters = {
    AiProviderId.openAi: OpenAiAdapter(),
    AiProviderId.gemini: GeminiAdapter(),
    AiProviderId.claude: ClaudeAdapter(),
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Execute an AI request against the selected provider.
  ///
  /// [request]             — what to ask and which capability to use
  /// [selectedProvider]    — the single provider chosen by the user
  ///
  /// Returns [AiResponse] on success.
  /// Throws [AiException] if the selected provider fails or is invalid.
  Future<AiResponse> execute({
    required AiRequest request,
    required AiProviderId selectedProvider,
  }) async {
    debugPrint(
      '🎯 Orchestrator: ${selectedProvider.displayName}, ${request.capability.id}, '
      '[requestId: ${request.requestId}]',
    );

    _effectBus.safeEffect(() async {
      await _analytics.logAiRequestInitiated(
        modelAttempted: selectedProvider,
        capability: request.capability,
        requestId: request.requestId,
      );
    });

    // Step 1: Ensure: Fail fast if the selected provider cannot do this task.
    if (!_registry.supports(selectedProvider, request.capability)) {
      final error = AiCapabilityGapException(
        message: 'error_selected_model_capability_gap',
        provider: selectedProvider,
        missingCapability: request.capability,
      );

      await _analytics.logAiCapabilityGap(
        modelSelected: selectedProvider,
        capabilityAttempted: request.capability,
      );

      debugPrint(
        '⚠️ Orchestrator: ${selectedProvider.id} does not support '
        '${request.capability.id}',
      );

      throw error;
    }

    // Step 3: Execute only the selected provider.
    try {
      return await _executeWithRetry(
        request: request,
        providerId: selectedProvider,
      );
    } on AiException catch (e) {
      await _analytics.logAiRequestFailed(
          modelAttempted: selectedProvider,
          capability: request.capability,
          failureType: e.failureType,
          failureReason: e.message,
          requestId: request.requestId);

      if (e is AiTransientException) {
        final exhaustedError = AiExhaustedException(
          message: 'server_busy',
          triedProviders: [selectedProvider],
        );
        _effectBus.emit(exhaustedError, StackTrace.current);
        throw exhaustedError;
      } else if (e is AiRateLimitException) {
        final exhaustedError = AiExhaustedException(
          message: 'error_quota_exceeded',
          triedProviders: [selectedProvider],
        );
        _effectBus.emit(exhaustedError, StackTrace.current);
        throw exhaustedError;
      }
      rethrow;
    }
  }

  // ── Private: Execute with Retry ────────────────────────────────────────────

  /// Execute a request on a specific provider with transient retry logic.
  ///
  /// Retries up to [AppConstants.maxRetryAttempts] times for transient errors.
  /// Adds exponential backoff between retries.
  Future<AiResponse> _executeWithRetry({
    required AiRequest request,
    required AiProviderId providerId,
  }) async {
    final adapter = _adapters[providerId]!;
    int attempt = 0;

    // Retrieve API key from Firestore (uses local cache after first read)
    final keyModel = await _keyRepository.loadKey(
      uid: request.uid,
      providerId: providerId,
    );

    if (keyModel == null || keyModel.apiKey.isEmpty) {
      // Key was deleted mid-session — treat as unavailable
      debugPrint(
        '⚠️ Orchestrator: no key found for ${providerId.id}',
      );
      throw AiHardErrorException(
        message: 'error_no_models_with_key',
        provider: providerId,
      );
    }

    while (true) {
      attempt++;

      try {
        debugPrint(
          '▶️ Orchestrator: attempt $attempt on ${providerId.id}',
        );

        final response = await adapter.execute(
          request: request,
          apiKey: keyModel.apiKey,
        );

        _effectBus.safeEffect(() async {
          await _analytics.logAiRequestSuccess(
            modelUsed: providerId,
            capability: request.capability,
            responseTimeMs: response.responseTimeMs,
            tokenCount: response.tokenCount,
            requestId: request.requestId,
          );
        });

        // Fire-and-forget usage tracking — must never block the AI response
        _effectBus.safeEffect(() async {
          _saveUsageEvent(
              uid: request.uid, request: request, response: response);
        });

        debugPrint(
          '✅ Orchestrator: success on ${providerId.id}, '
          'completion time (${response.responseTimeMs}ms)',
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
          // Retries exhausted — surface failure for the selected provider.
          debugPrint("🔄 Maximum orchestra retry attempts reached");
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

  // ── Usage Tracking ─────────────────────────────────────────────────────────

  /// Records usage data to Firestore after every successful AI request.
  ///
  /// This is a fire-and-forget call — any failure is silently logged and
  /// never propagates back to the AI response caller.
  void _saveUsageEvent({
    required String uid,
    required AiRequest request,
    required AiResponse response,
  }) async {
    debugPrint(
        '📊 Orchestrator: _saveUsageEvent called for ${response.modelUsed.id}');
    try {
      final summary =
          await _usageRepo.getSummary(uid: uid, provider: response.modelUsed);
      if (summary == null || !summary.enabled) {
        debugPrint(
            '📊 Orchestrator: Skipping usage event — usage tracking not enabled for ${response.modelUsed.id}');
        return;
      }
      final now = DateTime.now();
      final monthKey = UsageEventModel.monthKeyFrom(now);
      final capability = request.capability;

      final imageCount = (capability == AiCapability.imageGeneration)
          ? (request.imageCount ?? 1)
          : 0;
      final pdfCount = (capability == AiCapability.pdfParsing)
          ? (request.pdfBytes?.length ?? 0)
          : 0;

      final estimatedCost = UsageCostEstimator.estimate(
        provider: response.modelUsed,
        capability: capability,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        imageCount: imageCount,
        imageQuality: request.imageQuality ?? ImageQuality.low,
      );

      final event = UsageEventModel(
        id: '${request.requestId}_${now.millisecondsSinceEpoch}',
        provider: response.modelUsed,
        model:
            UsagePricingTable.modelName(response.modelUsed, request.capability),
        capability: capability,
        requestId: request.requestId,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        totalTokens: response.tokenCount,
        imageCount: imageCount,
        pdfCount: pdfCount,
        estimatedCostUsd: estimatedCost,
        createdAt: now,
        monthKey: monthKey,
      );

      // Intentionally unawaited — usage must never block the chat UI
      _usageRepo.saveEvent(uid: uid, event: event);
    } catch (e) {
      debugPrint('⚠️ Usage event construction failed (non-fatal): $e');
    }
  }
}
