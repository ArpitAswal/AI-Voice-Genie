import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/effect_bus.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/storage_service.dart';
import '../data/api_key_repository_impl.dart';
import '../domain/api_key_model.dart';
import '../domain/api_key_repository.dart';
import '../../chat/data/chat_outbox_store.dart';
import '../../chat/domain/chat_outbox_task.dart';

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
  static ApiKeyProvider? _instance;
  static ApiKeyProvider? get instance => _instance;

  final ApiKeyRepository _repository;
  final AnalyticsService _analytics;
  final FirebaseAuth? _customAuth;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  ApiKeyProvider({
    ApiKeyRepository? repository,
    AnalyticsService? analytics,
    FirebaseAuth? auth,
  })  : _repository = repository ?? ApiKeyRepositoryImpl(),
        _analytics = analytics ?? AnalyticsService.instance,
        _customAuth = auth {
    _instance = this;
  }

  StreamSubscription<Map<AiProviderId, ApiKeyModel>>? _keysSubscription;

  /// Current authenticated user ID, or null if signed out.
  String? get currentUid => _auth.currentUser?.uid;

  // ── State ──────────────────────────────────────────────────────────────────

  /// Stored key models per provider — populated on loadExistingKeys()
  final Map<AiProviderId, ApiKeyModel> _storedKeys = {};

  /// Per-provider error messages — shown as inline card errors
  final Map<AiProviderId, String?> _errors = {};

  /// Providers currently undergoing live validation (drives in-flight card spinner)
  final Set<AiProviderId> _validatingProviders = {};

  /// Providers whose cloud persistence encountered a permanent/fatal error
  final Set<AiProviderId> _cloudSyncFailedProviders = {};

  /// Global error when loading keys from Firestore (e.g. no internet)
  String? _loadError;

  /// Whether the "complete setup" operation is in progress
  bool _isCompletingSetup = false;

  /// Internal concurrency guard to prevent duplicate concurrent Firestore fetches
  bool _isLoadingKeys = false;

  bool get isCompletingSetup => _isCompletingSetup;
  String? get loadError => _loadError;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Whether a specific provider has a key stored locally but failed cloud sync
  bool isCloudSyncFailed(AiProviderId provider) =>
      _cloudSyncFailedProviders.contains(provider);

  /// Mark a provider as failed cloud sync
  void markCloudSyncFailed(AiProviderId provider) {
    _cloudSyncFailedProviders.add(provider);
    notifyListeners();
  }

  /// Clear the cloud sync failed flag for a provider
  void clearCloudSyncFailed(AiProviderId provider) {
    if (_cloudSyncFailedProviders.remove(provider)) {
      notifyListeners();
    }
  }

  /// Get validation status for a specific provider derived dynamically from state
  ApiKeyStatus statusFor(AiProviderId provider) {
    if (_validatingProviders.contains(provider)) {
      return ApiKeyStatus.validating;
    }
    if (_storedKeys.containsKey(provider)) return ApiKeyStatus.valid;
    if (_errors[provider] != null) return ApiKeyStatus.invalid;
    return ApiKeyStatus.notAdded;
  }

  /// Get inline error message for a specific provider card
  String? errorFor(AiProviderId provider) => _errors[provider];

  /// Get the masked API key for display on a valid provider card.
  /// Protects sensitive credentials while showing enough context to identify the key.
  String? maskedKeyFor(AiProviderId provider) {
    final key = _storedKeys[provider]?.apiKey;
    if (key == null || key.isEmpty) return null;
    // Defensive check for unusually short keys
    if (key.length <= 10) return '••••••••';
    // Show first 4 and last 4 characters separated by masking bullets
    return '${key.substring(0, 4)}••••••••••${key.substring(key.length - 4)}';
  }

  /// Returns the stored [ApiKeyModel] for [provider], or null if not stored.
  ApiKeyModel? apiKeyFor(AiProviderId provider) => _storedKeys[provider];

  /// Returns the raw (decrypted) API key for [provider], or null if not stored.
  ///
  /// **Internal use only** — never display or log this value.
  /// Used by services that need to call the provider API directly (e.g. Whisper STT).
  String? rawKeyFor(AiProviderId provider) => _storedKeys[provider]?.apiKey;

  /// Whether at least one provider has a valid key configured in memory
  bool get hasAtLeastOneValidKey => _storedKeys.isNotEmpty;

  /// All providers that currently have valid keys
  List<AiProviderId> get validProviders => _storedKeys.keys.toList();

  // ── Load Existing Keys ─────────────────────────────────────────────────────

  /// Load any previously saved keys from Firestore on screen mount.
  ///
  /// Flow:
  /// 1. Short-circuits if stream is already actively watching and keys are loaded.
  /// 2. Concurrency guard prevents duplicate fetches while one is in flight.
  /// 3. Subscribes to real-time [watchKeys] stream and awaits the initial snapshot delivery.
  /// 4. Synchronizes _storedKeys and keeps stream alive to track multi-device updates.
  Future<bool> loadExistingKeys([String? uid]) async {
    // 1. If already watching, keys are already kept in sync
    if (_keysSubscription != null) return true;
    // 2. Prevent duplicate concurrent requests if a fetch is already in flight
    if (_isLoadingKeys) return false;

    _isLoadingKeys = true;
    _loadError = null;

    final completer = Completer<bool>();

    try {
      _keysSubscription = _repository.watchKeys(uid).listen(
        (keys) {
          // Synchronize _storedKeys with remote changes, keeping any provider
          // that is currently being validated on this device or has a pending outbox write
          final effectiveUid = uid ?? currentUid;
          final pendingSaved = effectiveUid != null
              ? ChatOutboxStore.instance.getPendingSavedApiKeys(effectiveUid)
              : <AiProviderId, ApiKeyModel>{};

          _storedKeys.removeWhere(
            (provider, _) =>
                !keys.containsKey(provider) &&
                !_validatingProviders.contains(provider) &&
                !pendingSaved.containsKey(provider),
          );

          for (final entry in keys.entries) {
            if (_validatingProviders.contains(entry.key)) continue;
            _storedKeys[entry.key] = entry.value;
          }

          // Merge any locally pending outbox keys so they remain visible immediately
          for (final entry in pendingSaved.entries) {
            _storedKeys[entry.key] = entry.value;
          }

          // ── Silent Self-Healing Reconciliation ────────────────────────────
          // Keeps local Hive setup flag aligned with remote cloud truth across devices/reinstalls
          final storage = StorageService();
          if (keys.isNotEmpty || pendingSaved.isNotEmpty) {
            storage.setBool(StorageKeys.keySetupCompleted, true);
          } else {
            storage.setBool(StorageKeys.keySetupCompleted, false);
          }

          _isLoadingKeys = false;
          notifyListeners();

          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (e) {
          debugPrint('⚠️ ApiKeyProvider watchKeys stream error: $e');
          _keysSubscription?.cancel();
          _keysSubscription = null;
          _isLoadingKeys = false;
          _loadError = e is ApiKeyException ? e.code : 'something_went_wrong';
          notifyListeners();

          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            _isLoadingKeys = false;
            completer.complete(false);
          }
        },
      );

      // Await initial snapshot delivery (or timeout)
      return await completer.future.timeout(
        AppConstants.aiRequestTimeout,
        onTimeout: () {
          _keysSubscription?.cancel();
          _keysSubscription = null;
          _isLoadingKeys = false;
          _loadError = ApiKeyErrorCodes.timeout;
          notifyListeners();
          return false;
        },
      );
    } catch (e) {
      debugPrint('⚠️ ApiKeyProvider.loadExistingKeys error: $e');
      _keysSubscription?.cancel();
      _keysSubscription = null;
      _isLoadingKeys = false;
      _loadError = 'something_went_wrong';
      notifyListeners();
      return false;
    }
  }

  /// Checks whether keys already exist in local memory or are actively being watched.
  ///
  /// If local memory already holds keys or the real-time stream is active,
  /// returns false immediately without making a redundant Firestore network query.
  /// Otherwise, queries the database via [loadExistingKeys].
  Future<bool> loadExistingKeysIfNeeded([String? uid]) async {
    // 1. If keys already exist in local memory, no Firestore query needed
    if (_storedKeys.isNotEmpty) {
      return false;
    }

    // 2. If real-time stream is already active, it will push any existing keys
    if (_keysSubscription != null) {
      return false;
    }

    // 3. Prevent duplicate concurrent requests if a fetch is already in flight
    if (_isLoadingKeys) {
      return false;
    }

    // 4. Both local conditions failed — fetch from repository
    return loadExistingKeys(uid);
  }

  /// Resets provider state and cancels active subscriptions (e.g. on user sign-out).
  /// Prevents memory leaks and cross-user key leaks.
  void reset() {
    _keysSubscription?.cancel();
    _keysSubscription = null;
    _storedKeys.clear();
    _errors.clear();
    _validatingProviders.clear();
    _cloudSyncFailedProviders.clear();
    _loadError = null;
    _isCompletingSetup = false;
    _isLoadingKeys = false;
    ApiKeyRepositoryImpl.clearMemoryCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _keysSubscription?.cancel();
    super.dispose();
  }

  // ── Validate and Save ──────────────────────────────────────────────────────

  /// Validate an API key against the provider's live endpoint.
  ///
  /// Flow:
  /// 1. Sanitizes (trims) key input and clears previous error.
  /// 2. Sets _validatingProvider (drives card validating status & spinner).
  /// 3. Validates against remote endpoint via repository.
  /// 4. If rejected, sets inline error (drives card invalid status).
  /// 5. If valid, updates local UI immediately (0ms wait) and persists to Firestore in the background.
  Future<void> validateAndSaveKey({
    String? uid,
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    final cleanKey = apiKey.trim();
    // Clear previous error for this provider and set validating flag
    _errors[providerId] = null;
    _validatingProviders.add(providerId);
    notifyListeners();

    try {
      final isValid = await _repository.validateKey(
        providerId: providerId,
        apiKey: cleanKey,
      );

      if (!isValid) {
        // Provider definitively rejected the key
        _errors[providerId] = 'key_invalid';
        return;
      }

      // ── Optimistic Local-First Update ─────────────────────────────────────
      // Key is confirmed valid: update local UI state immediately for instant feedback
      final model = ApiKeyModel(
        aiProviderId: providerId.id,
        aiProviderModelFeatures: providerId.features,
        apiKey: cleanKey,
      );
      _storedKeys[providerId] = model;
      _errors[providerId] = null;

      // Remove validating spinner so card immediately displays masked key
      _validatingProviders.remove(providerId);
      notifyListeners();

      // ── Direct Cloud Save with Filtered Outbox Fallback ───────────────────
      // Happy path writes directly to Firestore in background (zero Hive disk churn).
      // Transient failures (network drop, timeout, token finish) enqueue to Outbox for persistent retry.
      final effectiveUid = uid ?? currentUid;
      if (effectiveUid != null) {
        _analytics.logModelKeyAdded(providerId, effectiveUid);
        EffectBus.instance.safeEffect(() async {
          try {
            await _repository.saveKey(
              uid: effectiveUid,
              providerId: providerId,
              apiKey: cleanKey,
            );
            _cloudSyncFailedProviders.remove(providerId);
            notifyListeners();
          } catch (e, st) {
            if (isTransientSyncError(e)) {
              debugPrint(
                  '⚠️ Transient cloud save error [$e]. Enqueuing to Outbox for persistent retry.');
              await ChatOutboxStore.instance.enqueue(
                ChatOutboxTask(
                  uid: effectiveUid,
                  type: OutboxTaskType.saveApiKey,
                  payload: {
                    'providerId': providerId.id,
                    'apiKey': cleanKey,
                  },
                  idempotencyKey: 'saveApiKey:$effectiveUid:${providerId.id}',
                ),
              );
            } else {
              debugPrint(
                  '🛑 Permanent Firestore error [$e]. Skipping outbox queue.');
              _cloudSyncFailedProviders.add(providerId);
              notifyListeners();
              EffectBus.instance.emit(e, st);
            }
          }
        });
      }
    } on ApiKeyException catch (e) {
      debugPrint(
        '❌ ApiKeyProvider.validateAndSaveKey [${providerId.id}]: ${e.technicalMessage}',
      );
      _errors[providerId] = e.code;
    } catch (e) {
      debugPrint('❌ ApiKeyProvider unexpected error: $e');
      _errors[providerId] = 'something_went_wrong';
    } finally {
      _validatingProviders.remove(providerId);
      notifyListeners();
    }
  }

  // ── Delete Key ─────────────────────────────────────────────────────────────

  /// Delete the key for a specific provider.
  ///
  /// Flow:
  /// 1. Optimistically removes key from local memory and updates UI immediately.
  /// 2. Directly deletes from Firestore in background; transient errors fall back to persistent Outbox queue.
  Future<void> deleteKey({
    String? uid,
    required AiProviderId providerId,
  }) async {
    // ── Optimistic Local-First Update ───────────────────────────────────────
    _storedKeys.remove(providerId);
    _errors[providerId] = null;
    _cloudSyncFailedProviders.remove(providerId);
    notifyListeners();

    // ── Direct Cloud Deletion with Filtered Outbox Fallback ─────────────────
    final effectiveUid = uid ?? currentUid;
    if (effectiveUid != null) {
      _analytics.logModelKeyRemoved(providerId, effectiveUid);
      EffectBus.instance.safeEffect(() async {
        try {
          await _repository.deleteKey(
              uid: effectiveUid, providerId: providerId);
        } catch (e, st) {
          if (isTransientSyncError(e)) {
            debugPrint(
                '⚠️ Transient cloud delete error [$e]. Enqueuing to Outbox for persistent retry.');
            await ChatOutboxStore.instance.enqueue(
              ChatOutboxTask(
                uid: effectiveUid,
                type: OutboxTaskType.deleteApiKey,
                payload: {
                  'providerId': providerId.id,
                },
                idempotencyKey: 'deleteApiKey:$effectiveUid:${providerId.id}',
              ),
            );
          } else {
            debugPrint(
                '🛑 Permanent Firestore delete error [$e]. Skipping outbox queue.');
            EffectBus.instance.emit(e, st);
          }
        }
      });
    }
  }

  /// Retry cloud persistence for a provider that previously encountered a fatal sync error.
  Future<void> retryCloudSync(AiProviderId providerId, [String? uid]) async {
    final key = _storedKeys[providerId]?.apiKey;
    if (key == null || key.isEmpty) return;
    final effectiveUid = uid ?? currentUid;
    if (effectiveUid == null) return;

    try {
      await _repository.saveKey(
        uid: effectiveUid,
        providerId: providerId,
        apiKey: key,
      );
      _cloudSyncFailedProviders.remove(providerId);
      notifyListeners();
      _analytics.logModelKeyAdded(providerId, effectiveUid);
    } catch (e, st) {
      if (isTransientSyncError(e)) {
        await ChatOutboxStore.instance.enqueue(
          ChatOutboxTask(
            uid: effectiveUid,
            type: OutboxTaskType.saveApiKey,
            payload: {
              'providerId': providerId.id,
              'apiKey': key,
            },
            idempotencyKey: 'saveApiKey:$effectiveUid:${providerId.id}',
          ),
        );
        _cloudSyncFailedProviders.remove(providerId);
        notifyListeners();
      } else {
        _cloudSyncFailedProviders.add(providerId);
        notifyListeners();
        EffectBus.instance.emit(e, st);
      }
    }
  }

  /// Checks whether an error is transient (network disconnect, timeout,
  /// token expiration / finish, or device lifecycle interrupt) and should be enqueued.
  static bool isTransientSyncError(Object error) {
    if (error is TimeoutException || error is SocketException) return true;

    if (error is ApiKeyException) {
      if (error.code == ApiKeyErrorCodes.noInternet ||
          error.code == ApiKeyErrorCodes.timeout) {
        return true;
      }
    }

    if (error is FirebaseException) {
      const transientCodes = {
        'unavailable',
        'network-request-failed',
        'deadline-exceeded',
        'unauthenticated', // Token expired / finish, auto-refreshed on reconnect
        'resource-exhausted',
        'aborted',
      };
      if (transientCodes.contains(error.code)) return true;

      const permanentCodes = {
        'permission-denied',
        'invalid-argument',
        'not-found',
        'already-exists',
        'failed-precondition',
      };
      if (permanentCodes.contains(error.code)) return false;
    }

    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('socket') ||
        msg.contains('unavailable') ||
        msg.contains('unauthenticated') ||
        msg.contains('token');
  }

  // ── Complete Setup ─────────────────────────────────────────────────────────

  /// Mark key setup as complete and persist to Firestore + Hive.
  ///
  /// Marks the onboarding milestone completed on the user's document.
  /// Returns true on success, false on failure.
  Future<bool> completeSetup([String? uid]) async {
    _isCompletingSetup = true;
    notifyListeners();

    try {
      await _repository.completeKeySetup(uid);

      _isCompletingSetup = false;
      return true;
    } on ApiKeyException catch (e) {
      debugPrint(
        '❌ ApiKeyProvider.completeSetup failed: ${e.technicalMessage}',
      );
      _isCompletingSetup = false;
      return false;
    } catch (e) {
      debugPrint('❌ ApiKeyProvider unexpected completeSetup error: $e');
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
}
