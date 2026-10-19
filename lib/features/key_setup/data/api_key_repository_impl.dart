import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/error/effect_bus.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/api_key_model.dart';
import '../domain/api_key_repository.dart';

/// Concrete implementation of ApiKeyRepository.
///
/// Validation strategy per provider:
///   OpenAI  → GET /v1/models         Authorization: Bearer {key}
///   Gemini  → GET /v1beta/models?key={key}
///   Claude  → GET /v1/models         x-api-key: {key} + anthropic-version header
///
/// All validation calls return HTTP 200 for valid keys.
/// 401 / 403 indicates invalid key.
/// Network errors throw ApiKeyException with appropriate error code.
class ApiKeyRepositoryImpl implements ApiKeyRepository {
  final FirebaseFirestore? _customFirestore;
  final StorageService? _customStorage;
  final FirebaseAuth? _customAuth;
  final http.Client _httpClient;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseCollections.firestore;
  StorageService get _storage => _customStorage ?? StorageService();
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  /// Resolves the effective user ID: uses [uid] if provided, otherwise
  /// falls back to current authenticated user from FirebaseAuth.
  String _resolveUid(String? uid) {
    final effectiveUid =
        (uid != null && uid.isNotEmpty) ? uid : _auth.currentUser?.uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      throw const ApiKeyException(
        ApiKeyErrorCodes.unknown,
        technicalMessage: 'User is not authenticated (UID is null).',
      );
    }
    return effectiveUid;
  }

  /// Process-wide in-memory cache for API keys loaded during the current session.
  /// Shared across all repository instances (e.g. ApiKeyProvider and AiOrchestrator)
  /// to eliminate redundant Firestore reads.
  static final Map<AiProviderId, ApiKeyModel> _memoryCache = {};
  static String? _cachedUid;
  static bool _isAllKeysLoaded = false;

  /// Get cached active key for a provider.
  static ApiKeyModel? getCachedKey(AiProviderId provider) =>
      _memoryCache[provider];

  /// Clear the in-memory cache (e.g., on user logout).
  static void clearMemoryCache() {
    _memoryCache.clear();
    _cachedUid = null;
    _isAllKeysLoaded = false;
  }

  static final ApiKeyRepositoryImpl _instance =
      ApiKeyRepositoryImpl._internal();

  factory ApiKeyRepositoryImpl({
    FirebaseFirestore? firestore,
    StorageService? storage,
    FirebaseAuth? auth,
    http.Client? httpClient,
  }) {
    if (firestore == null &&
        storage == null &&
        auth == null &&
        httpClient == null) {
      return _instance;
    }
    return ApiKeyRepositoryImpl._internal(
      firestore: firestore,
      storage: storage,
      auth: auth,
      httpClient: httpClient,
    );
  }

  ApiKeyRepositoryImpl._internal({
    FirebaseFirestore? firestore,
    StorageService? storage,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _customFirestore = firestore,
        _customStorage = storage,
        _customAuth = auth,
        _httpClient = httpClient ?? http.Client();

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Validates an API key against the provider's live endpoint.
  ///
  /// Flow:
  /// 1. Trims and checks for non-empty key string.
  /// 2. Dispatches a lightweight, free HTTP GET /models request per provider.
  /// 3. Inspects response code:
  ///    - 200: Key is confirmed valid.
  ///    - 401 / 403: Definitive rejection (invalid key).
  ///    - 400: Handled specifically for Google Gemini (returns 400 INVALID_ARGUMENT on invalid key).
  ///    - 429: Rate-limited on validation endpoint; assumed valid to not block legitimate users.
  ///    - 500+: Provider server downtime / maintenance.
  /// 4. Catches SocketException and translates to typed ApiKeyException(noInternet).
  @override
  Future<bool> validateKey({
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    final sanitizedKey = apiKey.trim();
    if (sanitizedKey.isEmpty) {
      return false;
    }

    try {
      final response = await _makeValidationCall(
        providerId: providerId,
        apiKey: sanitizedKey,
      ).timeout(
        AppConstants.aiRequestTimeout,
        onTimeout: () => throw const ApiKeyException(ApiKeyErrorCodes.timeout),
      );

      debugPrint(
        '🔑 Key validation [${providerId.id}]: HTTP ${response.statusCode}',
      );

      // HTTP 200: Valid key confirmation
      if (response.statusCode == 200) return true;

      // HTTP 401 / 403: Definitive unauthorized rejection (OpenAI, Claude, Gemini)
      if (response.statusCode == 401 || response.statusCode == 403) {
        return false;
      }

      // HTTP 400: Google Gemini returns HTTP 400 INVALID_ARGUMENT with "API key not valid"
      // rather than HTTP 401/403. Treat as definitive key rejection.
      if (response.statusCode == 400) {
        final body = response.body.toLowerCase();
        if (body.contains('api key not valid') ||
            body.contains('invalid_argument') ||
            body.contains('api_key_invalid') ||
            providerId == AiProviderId.gemini) {
          debugPrint(
            '🔑 Key validation [${providerId.id}]: HTTP 400 treated as invalid key',
          );
          return false;
        }
      }

      // HTTP 429: Rate limit reached on the validation endpoint
      // The key is authentic, but quota/rate limits prevent listing models.
      // Assume valid to avoid blocking valid paying users.
      if (response.statusCode == 429) {
        debugPrint(
          '⚠️ Key validation [${providerId.id}]: 429 rate limit — assuming valid',
        );
        return true;
      }

      // HTTP 500+ or other unexpected responses indicate provider service downtime
      throw ApiKeyException(
        ApiKeyErrorCodes.serviceUnavailable,
        technicalMessage:
            'Provider ${providerId.id} returned HTTP ${response.statusCode}: ${response.body}',
      );
    } on ApiKeyException {
      rethrow;
    } on SocketException {
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('failed host lookup') ||
          msg.contains('network is unreachable') ||
          msg.contains('connection refused') ||
          msg.contains('no address associated with hostname')) {
        throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
      }
      throw ApiKeyException(
        ApiKeyErrorCodes.unknown,
        technicalMessage: 'HTTP client error: $e',
      );
    } on HttpException catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.unknown,
        technicalMessage: 'HTTP error: $e',
      );
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw ApiKeyException(
        ApiKeyErrorCodes.unknown,
        technicalMessage: 'Unexpected validation error: $e',
      );
    }
  }

  /// Make the cheapest possible HTTP call to verify the key.
  /// Uses RFC-compliant URL query parameter construction for Gemini.
  Future<http.Response> _makeValidationCall({
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    switch (providerId) {
      case AiProviderId.openAi:
        // GET /v1/models — lists available models, costs nothing
        return _httpClient.get(
          Uri.parse('${AppConstants.openAiBaseUrl}/models'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        );

      case AiProviderId.gemini:
        // GET /v1beta/models?key={key} — clean URI parameter construction to prevent encoding bugs
        final geminiUri = Uri.parse(AppConstants.geminiBaseUrl).replace(
          path: '/v1beta/models',
          queryParameters: {'key': apiKey},
        );
        return _httpClient.get(
          geminiUri,
          headers: {'Content-Type': 'application/json'},
        );

      case AiProviderId.claude:
        // GET /v1/models — Claude requires both api key and version headers
        return _httpClient.get(
          Uri.parse('${AppConstants.claudeBaseUrl}/models'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': AppConstants.claudeApiVersion,
            'Content-Type': 'application/json',
          },
        );
    }
  }

  // ── Save Key ───────────────────────────────────────────────────────────────

  /// Encrypts and persists a validated API key to Cloud Firestore and updates in-memory cache.
  @override
  Future<void> saveKey({
    String? uid,
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    final effectiveUid = _resolveUid(uid);
    final sanitizedKey = apiKey.trim();
    try {
      final model = ApiKeyModel(
        aiProviderId: providerId.id,
        aiProviderModelFeatures: providerId.features,
        apiKey: sanitizedKey,
      );

      // Write to Firestore — path: AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}
      await _firestore
          .doc(FirebaseCollections.apiKeyDoc(effectiveUid, providerId.id))
          .set({
        ...model.toFirestore(),
        FirebaseCollections.fieldKeyAddedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update process-wide in-memory cache
      _memoryCache[providerId] = model;

      debugPrint('✅ Key saved [${providerId.id}] for user $effectiveUid');

      // Key-specific Usage Summary Document setup:
      // Creates a dedicated document in usageSummaries (e.g. usageSummaries/gemini_<keyHint>)
      // Saves the encrypted key and keyHint, starts fresh spend ($0.00) for this new key,
      // and carries over any existing monthly budget cap configured for this provider.
      await _syncKeyUsageSummaryDoc(
        uid: effectiveUid,
        providerId: providerId,
        apiKey: sanitizedKey,
      );

      // Symmetrically mark key setup as complete in Firestore & Hive in background
      EffectBus.instance.safeEffect(() => completeKeySetup(effectiveUid));
    } on FirebaseException catch (e) {
      final code =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
              ? ApiKeyErrorCodes.noInternet
              : ApiKeyErrorCodes.saveFailed;
      throw ApiKeyException(
        code,
        technicalMessage: 'Firestore save failed: ${e.code} — ${e.message}',
      );
    } catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'Unexpected save error: $e',
      );
    }
  }

  /// Syncs or creates a key-specific usage summary document at
  /// `UserModel/usageSummaries/{providerId}_{keyHint}`.
  ///
  /// Guarantees:
  /// 1. Saves the AES-256 encrypted API key and non-secret keyHint directly into the summary document.
  /// 2. If the document is newly created (a fresh or different key), initializes spend to $0.00
  ///    so the new key's credits start tracking cleanly from zero.
  /// 3. Inherits any existing monthly budget spending cap preference set for this provider.
  /// 4. Preserves historical usage data if the key document already exists.
  Future<void> _syncKeyUsageSummaryDoc({
    required String uid,
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    try {
      final keyHint =
          apiKey.length >= 6 ? apiKey.substring(apiKey.length - 6) : apiKey;
      final docId = '${providerId.id}_$keyHint';
      final summaryDocRef =
          _firestore.doc(FirebaseCollections.usageSummaryDoc(uid, docId));

      final existingDoc = await summaryDocRef.get();
      final encryptedKey = EncryptionService.encrypt(apiKey);

      if (!existingDoc.exists) {
        // Fresh key document starts clean without inheriting other keys' budgets
        await summaryDocRef.set({
          FirebaseCollections.summaryFieldKeyHint: keyHint,
          FirebaseCollections.fieldApiKey: encryptedKey,
          'monthlyData': {},
          FirebaseCollections.usageFieldLifetimeTotalTokens: 0,
          FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '📊 ApiKeyRepositoryImpl: Created key usage summary doc [$docId] with clean state & encrypted key',
        );
      } else {
        // Ensure encrypted key and keyHint are synced if missing
        await summaryDocRef.set({
          FirebaseCollections.summaryFieldKeyHint: keyHint,
          FirebaseCollections.fieldApiKey: encryptedKey,
          FirebaseCollections.usageFieldUpdatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          '📊 ApiKeyRepositoryImpl: Synced existing key usage summary doc [$docId]',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Non-fatal _syncKeyUsageSummaryDoc error: $e');
    }
  }

  // ── Load Keys ──────────────────────────────────────────────────────────────

  /// Loads stored API keys for a user from Firestore with intelligent caching.
  ///
  /// Flow:
  /// 1. Checks if the cached UID matches the requested UID; if not, clears memory cache.
  /// 2. If a specific provider is requested and cached, returns immediately.
  /// 3. If all providers are requested and all known providers are already cached, returns cache hit.
  /// 4. Otherwise, concurrently fetches document snapshots from Firestore using Future.wait.
  /// 5. Decrypts and populates ApiKeyModel instances.
  /// 6. Synchronizes memory cache for instant subsequent reads.
  @override
  Future<Map<AiProviderId, ApiKeyModel>> loadKeys({
    String? uid,
    AiProviderId? providerId,
  }) async {
    final effectiveUid = _resolveUid(uid);
    // If the authenticated user changed, invalidate previous user's cached keys
    if (_cachedUid != null && _cachedUid != effectiveUid) {
      _memoryCache.clear();
      _isAllKeysLoaded = false;
    }
    _cachedUid = effectiveUid;

    // Step 1: Memory cache short-circuit for individual provider
    if (providerId != null) {
      if (_memoryCache.containsKey(providerId)) {
        debugPrint('🚀 KeyRepository: memory cache hit [${providerId.id}]');
        return {providerId: _memoryCache[providerId]!};
      }
      if (_isAllKeysLoaded) {
        // All keys are loaded and this provider is not present — confirmed no key
        debugPrint(
            '🚀 KeyRepository: full cache confirmed no key for [${providerId.id}]');
        return {};
      }
    }

    // Step 2: Memory cache short-circuit when all keys are already loaded
    if (providerId == null && _isAllKeysLoaded) {
      debugPrint(
          '🚀 KeyRepository: full memory cache hit for user $effectiveUid');
      return Map.unmodifiable(_memoryCache);
    }

    try {
      // Step 3: Fetch using watchKeys stream directly — watchKeys handles Firestore reading,
      // deserialization, and populates _memoryCache and _isAllKeysLoaded in one place.
      final keys = await watchKeys(effectiveUid).first.timeout(
            AppConstants.aiRequestTimeout,
            onTimeout: () =>
                throw const ApiKeyException(ApiKeyErrorCodes.timeout),
          );

      debugPrint(
        '📦 KeyRepository: loaded ${keys.length} keys for user $effectiveUid '
        '${providerId != null ? '[single: ${providerId.id}]' : '[all]'}',
      );

      if (providerId != null) {
        final singleKey = keys[providerId];
        return singleKey != null ? {providerId: singleKey} : {};
      }
      return keys;
    } on FirebaseException catch (e) {
      // Step 7a: Translate Firebase connection errors into typed ApiKeyException
      debugPrint('⚠️ loadKeys Firestore error: ${e.code} — ${e.message}');
      final code =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
              ? ApiKeyErrorCodes.noInternet
              : ApiKeyErrorCodes.unknown;
      throw ApiKeyException(
        code,
        technicalMessage: 'Firestore loadKeys failed: ${e.code} — ${e.message}',
      );
    } on SocketException catch (e) {
      // Step 7b: Translate low-level socket drops into noInternet error code
      debugPrint('⚠️ loadKeys network error: $e');
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } catch (e) {
      // Step 7c: Rethrow known exceptions or wrap unexpected errors safely
      if (e is ApiKeyException) rethrow;
      debugPrint('⚠️ loadKeys unexpected error: $e');
      throw ApiKeyException(ApiKeyErrorCodes.unknown, technicalMessage: '$e');
    }
  }

  // ── Watch Keys ─────────────────────────────────────────────────────────────

  /// Subscribes to real-time updates for a user's API keys collection.
  /// Keeps the in-memory cache synchronized with remote changes.
  @override
  Stream<Map<AiProviderId, ApiKeyModel>> watchKeys([String? uid]) {
    final effectiveUid =
        (uid != null && uid.isNotEmpty) ? uid : _auth.currentUser?.uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      return const Stream.empty();
    }
    final collectionPath = FirebaseCollections.apiKeysCollection(effectiveUid);

    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      final result = <AiProviderId, ApiKeyModel>{};

      for (final doc in snapshot.docs) {
        if (doc.data().isNotEmpty) {
          final model = ApiKeyModel.fromFirestore(doc.data());
          result[AiProviderId.fromId(model.aiProviderId)] = model;
        }
      }

      // Sync process-wide in-memory cache and mark as fully loaded
      _memoryCache.clear();
      _memoryCache.addAll(result);
      _cachedUid = effectiveUid;
      _isAllKeysLoaded = true;

      return result;
    });
  }

  // ── Delete Key ─────────────────────────────────────────────────────────────

  /// Deletes an API key document directly from Firestore and updates memory cache.
  @override
  Future<void> deleteKey({
    String? uid,
    required AiProviderId providerId,
  }) async {
    final effectiveUid = _resolveUid(uid);
    try {
      // Direct delete without redundant get() roundtrip
      await _firestore
          .doc(FirebaseCollections.apiKeyDoc(effectiveUid, providerId.id))
          .delete();

      // Update in-memory cache
      _memoryCache.remove(providerId);

      debugPrint('🗑️ Key deleted [${providerId.id}] for user $effectiveUid');

      // If all keys have been removed, reset key setup status in Firestore & Hive in background
      if (_memoryCache.isEmpty) {
        EffectBus.instance.safeEffect(() => resetKeySetupStatus(effectiveUid));
      }
    } on FirebaseException catch (e) {
      final code =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
              ? ApiKeyErrorCodes.noInternet
              : ApiKeyErrorCodes.saveFailed;
      throw ApiKeyException(
        code,
        technicalMessage: 'Firestore delete failed: ${e.code}',
      );
    } on SocketException {
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'Unexpected delete error: $e',
      );
    }
  }

  // ── Complete Setup ─────────────────────────────────────────────────────────

  /// Marks key setup as complete on the user's document and caches preferences in Hive.
  ///
  /// Flow:
  /// 1. Updates Firestore user document using set with merge: true (self-healing if document is initializing).
  /// 2. Persists keySetupCompleted flag to Hive storage for fast startup.
  @override
  Future<void> completeKeySetup([String? uid]) async {
    final effectiveUid = _resolveUid(uid);
    try {
      // 1. Persist to local Hive storage first for instant reads
      await _storage.setBool(StorageKeys.keySetupCompleted, true);

      // 2. Synchronize to Firestore user document
      await _firestore.doc(FirebaseCollections.userDoc(effectiveUid)).set({
        FirebaseCollections.fieldKeySetupDone: true,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      final code =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
              ? ApiKeyErrorCodes.noInternet
              : ApiKeyErrorCodes.saveFailed;
      throw ApiKeyException(
        code,
        technicalMessage:
            'completeKeySetup Firestore failed: ${e.code} — ${e.message}',
      );
    } on SocketException {
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'completeKeySetup unexpected error: $e',
      );
    }
  }

  /// Reset key setup status to incomplete on the user document.
  ///
  /// Flow:
  /// 1. Updates Hive storage to keySetupCompleted=false locally first.
  /// 2. Synchronizes Firestore user document to keySetupDone=false with merge: true.
  @override
  Future<void> resetKeySetupStatus([String? uid]) async {
    final effectiveUid = _resolveUid(uid);
    try {
      // 1. Reset in local Hive storage first
      await _storage.setBool(StorageKeys.keySetupCompleted, false);

      // 2. Synchronize Firestore user document
      await _firestore.doc(FirebaseCollections.userDoc(effectiveUid)).set({
        FirebaseCollections.fieldKeySetupDone: false,
      }, SetOptions(merge: true));

      debugPrint('ℹ️ Key setup reset to incomplete for user $effectiveUid');
    } on FirebaseException catch (e) {
      final code =
          (e.code == 'unavailable' || e.code == 'network-request-failed')
              ? ApiKeyErrorCodes.noInternet
              : ApiKeyErrorCodes.saveFailed;
      throw ApiKeyException(
        code,
        technicalMessage:
            'resetKeySetupStatus Firestore failed: ${e.code} — ${e.message}',
      );
    } on SocketException {
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'resetKeySetupStatus unexpected error: $e',
      );
    }
  }
}
