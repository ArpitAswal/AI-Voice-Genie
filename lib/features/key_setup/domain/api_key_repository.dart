import '../../../core/enums/app_enums.dart';
import 'api_key_model.dart';

/// Abstract repository for AI provider API key management.
///
/// Handles:
///   - Live validation against provider endpoints
///   - Saving validated keys to Firestore
///   - Loading existing keys from Firestore
///   - Deleting keys from Firestore
///
/// Implementation: ApiKeyRepositoryImpl
abstract class ApiKeyRepository {
  /// Validate an API key against the provider's live endpoint.
  ///
  /// Makes the cheapest possible API call (list models) to confirm
  /// the key is valid. Returns true if valid, false if rejected.
  /// Throws [ApiKeyException] on network errors or unexpected failures.
  Future<bool> validateKey({
    required AiProviderId providerId,
    required String apiKey,
  });

  /// Save a validated API key to Firestore.
  ///
  /// Overwrites any existing key for this provider.
  /// Resolves authenticated user ID if [uid] is omitted.
  /// Should only be called AFTER validateKey() returns true.
  Future<void> saveKey({
    String? uid,
    required AiProviderId providerId,
    required String apiKey,
  });

  /// Load API keys for a user from Firestore.
  ///
  /// Resolves authenticated user ID if [uid] is omitted.
  /// If [providerId] is provided, only loads that specific provider.
  /// If [providerId] is null, loads all available providers.
  /// Returns a map of providerId → ApiKeyModel.
  /// Throws [ApiKeyException] if fetching from Firestore fails.
  Future<Map<AiProviderId, ApiKeyModel>> loadKeys({
    String? uid,
    AiProviderId? providerId,
  });

  /// Listen to all existing API keys for a user in real-time.
  ///
  /// Resolves authenticated user ID if [uid] is omitted.
  /// Returns a stream of providerId → ApiKeyModel map.
  Stream<Map<AiProviderId, ApiKeyModel>> watchKeys([String? uid]);

  /// Delete the API key for a specific provider from Firestore.
  ///
  /// Resolves authenticated user ID if [uid] is omitted.
  Future<void> deleteKey({
    String? uid,
    required AiProviderId providerId,
  });

  /// Mark key setup as complete on the user document.
  ///
  /// Resolves authenticated user ID if [uid] is omitted.
  /// Sets keySetupDone=true on the user doc and in Hive.
  Future<void> completeKeySetup([String? uid]);

  /// Reset key setup status to incomplete on the user document.
  ///
  /// Resolves authenticated user ID if [uid] is omitted.
  /// Sets keySetupDone=false in Firestore and updates Hive storage.
  /// Called when all API keys have been removed.
  Future<void> resetKeySetupStatus([String? uid]);
}

// =============================================================================
// API KEY EXCEPTION
// =============================================================================

/// Typed exception for API key operations.
class ApiKeyException implements Exception {
  /// Localization key — maps directly to AppLocalizations.translate(code)
  final String code;
  final String? technicalMessage;

  const ApiKeyException(this.code, {this.technicalMessage});

  @override
  String toString() =>
      'ApiKeyException(code: $code, technical: $technicalMessage)';
}

/// Error codes for API key operations.
class ApiKeyErrorCodes {
  /// Key was rejected by the provider (401/403)
  static const String keyInvalid = 'key_invalid';

  /// No internet connection
  static const String noInternet = 'no_internet_connection';

  /// Provider service is temporarily unavailable
  static const String serviceUnavailable = 'something_went_wrong';

  /// Request timed out
  static const String timeout = 'request_timed_out';

  /// Firestore save failed
  static const String saveFailed = 'something_went_wrong';

  /// Unknown error
  static const String unknown = 'something_went_wrong';
}
