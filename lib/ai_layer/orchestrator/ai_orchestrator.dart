import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/ai_exception.dart';
import '../../core/error/effect_bus.dart';
import '../../core/services/analytics_service.dart';
import '../../features/key_setup/domain/api_key_model.dart';
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
///     prompt: userMessage,
///     conversationHistory: history,
///   ),
///   selectedProvider: selectedProvider,
/// );
/// ```
class AiOrchestrator {
  // Singleton — one orchestrator for the entire app
  static final AiOrchestrator instance = AiOrchestrator._();

  /// Cached UID of the active authenticated user.
  /// Initialized once on startup and updated via authStateChanges so it is not
  /// rechecked on every execute call.
  static String currentUid = '';

  AiOrchestrator._() {
    _initAuth();
  }

  void _initAuth() {
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      FirebaseAuth.instance.authStateChanges().listen((user) {
        currentUid = user?.uid ?? '';
      });
    } catch (e) {
      // Gracefully handled for headless unit testing environments
      debugPrint('ℹ️ AiOrchestrator: Auth listener skipped ($e)');
    }
  }

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
    // Step 1: Capability Guard.
    // Fail fast if the selected provider cannot perform this capability
    // (e.g. Claude does not support image generation). Prevents unnecessary API calls.
    if (!_registry.supports(selectedProvider, request.capability)) {
      debugPrint(
        '⚠️ Orchestrator: ${selectedProvider.id} does not support '
        '${request.capability.id}',
      );

      throw AiCapabilityGapException(
        message: 'error_selected_model_capability_gap',
        provider: selectedProvider,
        missingCapability: request.capability,
      );
    }

    // Step 2: Asynchronously track initiation for valid executable requests.
    // Wrapped in safeEffect so analytics failures never disrupt the AI flow.
    _effectBus.safeEffect(() async {
      await _analytics.logAiRequestInitiated(
        modelAttempted: selectedProvider,
        capability: request.capability,
        requestId: request.requestId,
      );
    });

    // Step 3: Execute single-provider workflow with automatic transient retry.
    try {
      final response = await _executeWithRetry(
        request: request,
        providerId: selectedProvider,
      );

      // Track successful completion with response latency
      _effectBus.safeEffect(() async {
        await _analytics.logAiRequestSuccess(
          modelUsed: selectedProvider,
          capability: request.capability,
          responseTimeMs: response.responseTimeMs,
          requestId: request.requestId,
        );
      });

      return response;
    } on AiException catch (e) {
      // Step 3a: Track AI failure event in analytics
      _effectBus.safeEffect(() async {
        await _analytics.logAiRequestFailed(
          modelAttempted: selectedProvider,
          capability: request.capability,
          failureType: e.failureType,
          failureReason: e.message,
          requestId: request.requestId,
        );
      });

      // Step 3b: Convert transient retry-exhausted errors and rate limits to AiExhaustedException
      // bound explicitly to the selected provider, then emit to EffectBus for global UI notification.
      if (e is AiTransientException) {
        final exhaustedError = AiExhaustedException(
          message: e.message,
          provider: selectedProvider,
        );
        _effectBus.emit(exhaustedError, StackTrace.current);
        throw exhaustedError;
      } else if (e is AiRateLimitException) {
        final exhaustedError = AiExhaustedException(
          message: e.message,
          provider: selectedProvider,
        );
        _effectBus.emit(exhaustedError, StackTrace.current);
        throw exhaustedError;
      }
      rethrow;
    } catch (e) {
      // Step 3c: Catch any unexpected exceptions, convert to AiHardErrorException, and log
      final hardError = AiHardErrorException(
        message: 'something_went_wrong',
        provider: selectedProvider,
      );
      _effectBus.safeEffect(() async {
        await _analytics.logAiRequestFailed(
          modelAttempted: selectedProvider,
          capability: request.capability,
          failureType: hardError.failureType,
          failureReason: e.toString(),
          requestId: request.requestId,
        );
      });
      throw hardError;
    }
  }

  // ── Private: Execute with Retry ────────────────────────────────────────────

  /// Execute a request on a specific provider with transient retry logic.
  ///
  /// Flow:
  /// 1. Fetches the provider's API key from repository (memory cache or Firestore).
  /// 2. If no key is found, throws [AiHardErrorException].
  /// 3. Executes the provider adapter within a retry loop:
  ///    - [AiHardErrorException]: Never retried (invalid key, bad prompt).
  ///    - [AiRateLimitException]: Never retried on the same provider (quota exhausted).
  ///    - [AiTransientException]: Retried up to [AppConstants.maxRetryAttempts] with exponential backoff.
  /// 4. Dispatches asynchronous usage recording via [_saveUsageEvent] without blocking return.
  Future<AiResponse> _executeWithRetry({
    required AiRequest request,
    required AiProviderId providerId,
  }) async {
    final adapter = _adapters[providerId]!;
    int attempt = 0;

    // Retrieve API key from repository (short-circuits to local cache if present)
    Map<AiProviderId, ApiKeyModel> keys;
    try {
      keys = await _keyRepository.loadKeys(
        uid: currentUid,
        providerId: providerId,
      );
    } on ApiKeyException catch (e) {
      if (e.code == ApiKeyErrorCodes.noInternet) {
        throw AiTransientException(
          message: 'no_internet_connection',
          provider: providerId,
        );
      }
      throw AiHardErrorException(
        message: e.code,
        provider: providerId,
      );
    } catch (e) {
      throw AiHardErrorException(
        message: 'something_went_wrong',
        provider: providerId,
      );
    }

    final keyModel = keys[providerId];

    if (keyModel == null || keyModel.apiKey.isEmpty) {
      // Key was deleted or not registered — treat as unavailable
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
        // Execute request against provider adapter
        final response = await adapter.execute(
          request: request,
          apiKey: keyModel.apiKey,
        );

        // Fire-and-forget usage tracking — must never block returning the AI response to UI
        _effectBus.safeEffect(() async {
          _saveUsageEvent(
            uid: currentUid,
            request: request,
            response: response,
          );
        });
        return response;
      } on AiHardErrorException {
        // Hard errors are permanent (e.g. invalid key, bad parameters) — never retried
        rethrow;
      } on AiRateLimitException {
        // Rate limits are exhausted quotas — never retried on the same provider
        rethrow;
      } on AiTransientException {
        // Transient errors (network blips, 503 engine overload) are retried with backoff
        if (attempt >= AppConstants.maxRetryAttempts) {
          // Maximum retries reached — rethrow to surface failure
          rethrow;
        }

        // Exponential backoff: 500ms on 1st retry, 1000ms on 2nd retry
        final delayMs = 500 * attempt;
        await Future.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        throw AiHardErrorException(
          message: 'something_went_wrong',
          provider: providerId,
        );
      }
    }
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
    try {
      final summary =
          await _usageRepo.getSummary(uid: uid, provider: response.modelUsed);
      if (summary == null || !summary.enabled) {
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
