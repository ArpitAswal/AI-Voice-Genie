import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/services/analytics_service.dart';
import '../data/api_key_repository_impl.dart';
import '../domain/api_key_model.dart';
import '../domain/api_key_repository.dart';

/// State provider for AI API key management.
///
/// Manages the validation status and stored key data for each
/// of the three AI providers independently.
///
/// Used in:
///   - KeySetupScreen (first-time setup)
///   - ApiKeyManagementScreen in Settings (Phase 8)
///
/// Usage:
/// ```dart
/// context.read<ApiKeyProvider>().validateAndSaveKey(
///   uid: uid,
///   providerId: AiProviderId.openAi,
///   apiKey: 'sk-...',
/// );
/// context.watch<ApiKeyProvider>().statusFor(AiProviderId.openAi)
/// ```
class ApiKeyProvider extends ChangeNotifier {
  final ApiKeyRepository _repository;
  final AnalyticsService _analytics;

  ApiKeyProvider({
    ApiKeyRepository? repository,
    AnalyticsService? analytics,
  })  : _repository = repository ?? ApiKeyRepositoryImpl(),
        _analytics = analytics ?? AnalyticsService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  /// Validation status per provider — drives card UI state
  final Map<AiProviderId, ApiKeyStatus> _statuses = {
    AiProviderId.openAi: ApiKeyStatus.notAdded,
    AiProviderId.gemini: ApiKeyStatus.notAdded,
    AiProviderId.claude: ApiKeyStatus.notAdded,
  };

  /// Stored key models per provider — populated on loadExistingKeys()
  final Map<AiProviderId, ApiKeyModel> _storedKeys = {};

  /// Per-provider error messages — shown as inline card errors
  final Map<AiProviderId, String?> _errors = {};

  /// Whether the "complete setup" operation is in progress
  bool _isCompletingSetup = false;

  bool get isCompletingSetup => _isCompletingSetup;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Get validation status for a specific provider
  ApiKeyStatus statusFor(AiProviderId provider) =>
      _statuses[provider] ?? ApiKeyStatus.notAdded;

  /// Get inline error message for a specific provider card
  String? errorFor(AiProviderId provider) => _errors[provider];

  /// Get the masked API key for display on a valid provider card
  String? maskedKeyFor(AiProviderId provider) {
    final key = _storedKeys[provider]?.apiKey;
    if (key == null || key.isEmpty) return null;
    // Show first 4 and last 4 characters only
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  /// Whether at least one provider has a valid key
  bool get hasAtLeastOneValidKey =>
      _statuses.values.any((status) => status == ApiKeyStatus.valid);

  /// The first provider with a valid key — used as preferred provider
  AiProviderId? get firstValidProvider {
    for (final provider in AiProviderId.values) {
      if (_statuses[provider] == ApiKeyStatus.valid) return provider;
    }
    return null;
  }

  /// All providers that currently have valid keys
  List<AiProviderId> get validProviders => AiProviderId.values
      .where((p) => _statuses[p] == ApiKeyStatus.valid)
      .toList();

  /// Get valid providers for a specific capability.
  ///
  /// Uses ModelSelector to filter currently valid keys against capability requirements.
  // ── Load Existing Keys ─────────────────────────────────────────────────────

  /// Load any previously saved keys from Firestore on screen mount.
  ///
  /// Populates status map so returning users see their valid keys immediately.
  Future<bool> loadExistingKeys(String uid) async {
    try {
      final keys = await _repository.loadKeys(uid);

      for (final entry in keys.entries) {
        _storedKeys[entry.key] = entry.value;
        _statuses[entry.key] =
            entry.value.isValid ? ApiKeyStatus.valid : ApiKeyStatus.invalid;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ ApiKeyProvider.loadExistingKeys error: $e');
      // Non-fatal — all cards will show notAdded state
      return false;
    } finally {
      notifyListeners();
    }
  }

  // ── Validate and Save ──────────────────────────────────────────────────────

  /// Validate an API key against the provider's live endpoint.
  ///
  /// On success: saves to Firestore, updates status to valid.
  /// On failure: updates status to invalid, sets inline error.
  Future<void> validateAndSaveKey({
    required String uid,
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    // Clear previous error for this provider
    _errors[providerId] = null;
    _setStatus(providerId, ApiKeyStatus.validating);

    try {
      final isValid = await _repository.validateKey(
        providerId: providerId,
        apiKey: apiKey,
      );

      if (!isValid) {
        // Provider definitively rejected the key
        _errors[providerId] = 'key_invalid';
        _setStatus(providerId, ApiKeyStatus.invalid);
        return;
      }

      // Key is valid — save to Firestore
      await _repository.saveKey(
        uid: uid,
        providerId: providerId,
        apiKey: apiKey,
      );

      // Cache locally for masked display
      _storedKeys[providerId] = ApiKeyModel(
        aiProviderId: providerId.id,
        aiProviderModelFeatures: providerId.features,
        apiKey: apiKey,
        isValid: true,
      );

      // Fire analytics BEFORE auth — tracks button taps independently of outcome
      EffectBus.instance.safeEffect(() async {
        _analytics.logModelKeyAdded(providerId, uid);
      });

      _setStatus(providerId, ApiKeyStatus.valid);
    } on ApiKeyException catch (e) {
      debugPrint(
        '❌ ApiKeyProvider.validateAndSaveKey [${providerId.id}]: ${e.technicalMessage}',
      );
      _errors[providerId] = e.code;
      _setStatus(providerId, ApiKeyStatus.invalid);
    } catch (e) {
      debugPrint('❌ ApiKeyProvider unexpected error: $e');
      _errors[providerId] = 'something_went_wrong';
      _setStatus(providerId, ApiKeyStatus.invalid);
    } finally {
      notifyListeners();
    }
  }

  // ── Delete Key ─────────────────────────────────────────────────────────────

  /// Delete the key for a specific provider.
  ///
  /// Resets the provider card to notAdded state.
  Future<void> deleteKey({
    required String uid,
    required AiProviderId providerId,
  }) async {
    try {
      await _repository.deleteKey(uid: uid, providerId: providerId);

      _storedKeys.remove(providerId);
      _errors[providerId] = null;
      _setStatus(providerId, ApiKeyStatus.notAdded);
      EffectBus.instance.safeEffect(() async {
        _analytics.logModelKeyRemoved(providerId, uid);
      });
      notifyListeners();
    } on ApiKeyException catch (e) {
      debugPrint(
        '❌ ApiKeyProvider.deleteKey [${providerId.id}]: ${e.technicalMessage}',
      );
      // Show error but keep current status
      _errors[providerId] = e.code;
      notifyListeners();
    } finally {
      notifyListeners();
    }
  }

  // ── Complete Setup ─────────────────────────────────────────────────────────

  /// Mark key setup as complete and persist to Firestore + Hive.
  ///
  /// Only callable when hasAtLeastOneValidKey is true.
  /// Returns true on success, false on failure.
  Future<bool> completeSetup(String uid) async {
    final preferred = firstValidProvider;
    if (preferred == null) return false;

    _isCompletingSetup = true;
    notifyListeners();

    try {
      await _repository.completeKeySetup(
        uid: uid,
        preferredProvider: preferred,
      );

      _isCompletingSetup = false;
      return true;
    } on ApiKeyException catch (e) {
      debugPrint(
        '❌ ApiKeyProvider.completeSetup failed: ${e.technicalMessage}',
      );
      _isCompletingSetup = false;
      return false;
    } finally {
      notifyListeners();
    }
  }

  // ── Clear Error ────────────────────────────────────────────────────────────

  /// Clear the inline error for a provider card.
  ///
  /// Called when user starts editing the key field again.
  void clearError(AiProviderId providerId) {
    if (_errors[providerId] != null) {
      _errors[providerId] = null;
      notifyListeners();
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _setStatus(AiProviderId provider, ApiKeyStatus status) {
    if (_statuses[provider] == status) return;
    _statuses[provider] = status;
    notifyListeners();
  }
}
