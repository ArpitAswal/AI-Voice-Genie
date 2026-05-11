import '../enums/app_enums.dart';

/// Normalized AI exception hierarchy for AI Voice Genie.
///
/// Every AI provider's raw errors (HTTP status codes, SDK errors) are
/// mapped to one of these types by the provider adapters.
/// The orchestrator only sees AiException — never raw provider errors.
///
/// This decouples failure handling from provider-specific error formats.
sealed class AiException implements Exception {
  final String message;
  final AiProviderId provider;
  final AiFailureType failureType;
  final int? statusCode;

  const AiException({
    required this.message,
    required this.provider,
    required this.failureType,
    this.statusCode,
  });

  @override
  String toString() =>
      'AiException[${provider.id}/${failureType.value}]: $message';
}

/// Transient failure — network timeout, 503 service unavailable.
///
/// Orchestrator behavior: retry same model (max 2x), then report failure.
class AiTransientException extends AiException {
  const AiTransientException({
    required super.message,
    required super.provider,
    super.statusCode,
  }) : super(failureType: AiFailureType.transient);
}

/// Rate limit exceeded — HTTP 429 Too Many Requests.
///
/// Orchestrator behavior: immediately report failure for the selected model.
class AiRateLimitException extends AiException {
  const AiRateLimitException({
    required super.message,
    required super.provider,
    super.statusCode,
  }) : super(failureType: AiFailureType.rateLimit);
}

/// Hard error — 401 Unauthorized, 400 Bad Request, invalid configuration.
///
/// Orchestrator behavior: do not retry, report to user with friendly message.
class AiHardErrorException extends AiException {
  const AiHardErrorException({
    required super.message,
    required super.provider,
    super.statusCode,
  }) : super(failureType: AiFailureType.hardError);
}

/// Capability gap — model does not support the requested feature.
///
/// This is NOT a runtime failure. It is detected before the API call is made.
/// Orchestrator behavior: show capability gap message for the selected model.
class AiCapabilityGapException extends AiException {
  final AiCapability missingCapability;

  const AiCapabilityGapException({
    required super.message,
    required super.provider,
    required this.missingCapability,
  }) : super(failureType: AiFailureType.capabilityGap);
}

/// Selected model exhausted — the selected model failed after retry policy.
///
/// Orchestrator behavior: emit via EffectBus, show global error to user.
class AiExhaustedException extends AiException {
  final List<AiProviderId> triedProviders;

  const AiExhaustedException({
    required super.message,
    required this.triedProviders,
  }) : super(
          provider: AiProviderId.openAi, // placeholder — all failed
          failureType: AiFailureType.exhausted,
        );
}

/// Utility to map HTTP status codes to the correct AiException subtype.
///
/// Called by each provider adapter in its error handler.
AiException mapHttpErrorToAiException({
  required int statusCode,
  required AiProviderId provider,
  required String rawMessage,
}) {
  final messageLower = rawMessage.toLowerCase();

  switch (statusCode) {
    case 400:
      // Bad Request - often invalid parameters or prompt
      return AiHardErrorException(
        message: 'error_invalid_ai_request',
        provider: provider,
        statusCode: statusCode,
      );
    case 401:
      // Unauthorized - Invalid API Key
      return AiHardErrorException(
        message: 'error_invalid_key',
        provider: provider,
        statusCode: statusCode,
      );
    case 403:
      // Forbidden - often country/region restriction
      if (messageLower.contains('location') ||
          messageLower.contains('region') ||
          messageLower.contains('country')) {
        return AiHardErrorException(
          message: 'error_region_not_supported',
          provider: provider,
          statusCode: statusCode,
        );
      }
      return AiHardErrorException(
        message: 'error_permission_denied',
        provider: provider,
        statusCode: statusCode,
      );
    case 429:
      // Rate Limit or Quota Exceeded
      if (messageLower.contains('quota') || messageLower.contains('credit')) {
        return AiRateLimitException(
          message: 'error_quota_exceeded',
          provider: provider,
          statusCode: statusCode,
        );
      }
      return AiRateLimitException(
        message: 'error_rate_limit',
        provider: provider,
        statusCode: statusCode,
      );
    case 500:
      return AiTransientException(
        message: 'error_ai_server',
        provider: provider,
        statusCode: statusCode,
      );
    case 503:
      // Engine Overloaded
      return AiTransientException(
        message: 'error_engine_overloaded',
        provider: provider,
        statusCode: statusCode,
      );
    case 502:
    case 504:
      return AiTransientException(
        message: 'request_timed_out',
        provider: provider,
        statusCode: statusCode,
      );
    default:
      return AiTransientException(
        message: 'error_unexpected_ai',
        provider: provider,
        statusCode: statusCode,
      );
  }
}
