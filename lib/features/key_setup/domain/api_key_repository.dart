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
  /// Should only be called AFTER validateKey() returns true.
  Future<void> saveKey({
    required String uid,
    required AiProviderId providerId,
    required String apiKey,
  });

  /// Load all existing API keys for a user from Firestore.
  ///
  /// Returns a map of providerId → ApiKeyModel for each stored key.
  /// Missing providers are not included in the map.
  Future<Map<AiProviderId, ApiKeyModel>> loadKeys(String uid);

  /// Load the API key for a specific provider.
  ///
  /// Returns null if no key exists for this provider.
  Future<ApiKeyModel?> loadKey({
    required String uid,
    required AiProviderId providerId,
  });

  /// Listen to all existing API keys for a user in real-time.
  ///
  /// Returns a stream of providerId → ApiKeyModel map.
  Stream<Map<AiProviderId, ApiKeyModel>> watchKeys(String uid);

  /// Delete the API key for a specific provider from Firestore.
  Future<void> deleteKey({
    required String uid,
    required AiProviderId providerId,
  });

  /// Mark key setup as complete on the user document.
  ///
  /// Called when user taps "Continue" with ≥1 valid key.
  /// Sets keySetupDone=true and preferredProvider on the user doc.
  Future<void> completeKeySetup({
    required String uid,
    required AiProviderId preferredProvider,
  });
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
