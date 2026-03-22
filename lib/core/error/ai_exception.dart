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
  String toString() => 'AiException[${provider.id}/${failureType.value}]: $message';
}

/// Transient failure — network timeout, 503 service unavailable.
///
/// Orchestrator behavior: retry same model (max 2x), then fall back.
class AiTransientException extends AiException {
  const AiTransientException({
    required super.message,
    required super.provider,
    super.statusCode,
  }) : super(failureType: AiFailureType.transient);
}

/// Rate limit exceeded — HTTP 429 Too Many Requests.
///
/// Orchestrator behavior: immediately skip this model, try next.
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
/// Orchestrator behavior: show capability gap message with model switch options.
class AiCapabilityGapException extends AiException {
  final AiCapability missingCapability;

  const AiCapabilityGapException({
    required super.message,
    required super.provider,
    required this.missingCapability,
  }) : super(failureType: AiFailureType.capabilityGap);
}

/// All models exhausted — every available model with a key has failed.
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
  switch (statusCode) {
    case 429:
      return AiRateLimitException(
        message: 'Rate limit exceeded. Trying another model...',
        provider: provider,
        statusCode: statusCode,
      );
    case 401:
    case 403:
      return AiHardErrorException(
        message: 'Invalid API key for ${provider.displayName}. Please check your key in Settings.',
        provider: provider,
        statusCode: statusCode,
      );
    case 400:
      return AiHardErrorException(
        message: 'Invalid request sent to ${provider.displayName}.',
        provider: provider,
        statusCode: statusCode,
      );
    case 500:
    case 502:
    case 503:
    case 504:
      return AiTransientException(
        message: '${provider.displayName} server error. Retrying...',
        provider: provider,
        statusCode: statusCode,
      );
    default:
      return AiTransientException(
        message: 'Unexpected error from ${provider.displayName}.',
        provider: provider,
        statusCode: statusCode,
      );
  }
}