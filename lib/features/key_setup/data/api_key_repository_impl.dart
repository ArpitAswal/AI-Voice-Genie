import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/enums/app_enums.dart';
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
  final FirebaseFirestore _firestore;
  final StorageService _storage;
  final http.Client _httpClient;

  /// Process-wide in-memory cache for API keys loaded during the current session.
  /// Shared across all repository instances (e.g. ApiKeyProvider and AiOrchestrator)
  /// to eliminate redundant Firestore reads.
  static final Map<AiProviderId, ApiKeyModel> _memoryCache = {};
  static String? _cachedUid;

  /// Clear the in-memory cache (e.g., on user logout).
  static void clearMemoryCache() {
    _memoryCache.clear();
    _cachedUid = null;
  }

  static final ApiKeyRepositoryImpl _instance =
      ApiKeyRepositoryImpl._internal();

  factory ApiKeyRepositoryImpl({
    FirebaseFirestore? firestore,
    StorageService? storage,
    http.Client? httpClient,
  }) {
    if (firestore == null && storage == null && httpClient == null) {
      return _instance;
    }
    return ApiKeyRepositoryImpl._internal(
      firestore: firestore,
      storage: storage,
      httpClient: httpClient,
    );
  }

  ApiKeyRepositoryImpl._internal({
    FirebaseFirestore? firestore,
    StorageService? storage,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseCollections.firestore,
        _storage = storage ?? StorageService(),
        _httpClient = httpClient ?? http.Client();

  // ── Validation ─────────────────────────────────────────────────────────────

  @override
  Future<bool> validateKey({
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    try {
      final response = await _makeValidationCall(
        providerId: providerId,
        apiKey: apiKey.trim(),
      ).timeout(
        AppConstants.aiRequestTimeout,
        onTimeout: () => throw const ApiKeyException(ApiKeyErrorCodes.timeout),
      );

      debugPrint(
        '🔑 Key validation [${providerId.id}]: HTTP ${response.statusCode}',
      );

      if (response.statusCode == 200) return true;

      if (response.statusCode == 401 || response.statusCode == 403) {
        return false; // Definitive rejection — key is invalid
      }

      if (response.statusCode == 429) {
        // Rate limit on the validation endpoint — key might be valid
        // Treat as valid to avoid blocking users with heavily used keys
        debugPrint(
          '⚠️ Key validation [${providerId.id}]: 429 rate limit — assuming valid',
        );
        return true;
      }

      // 500+ server errors — service issue, not a key issue
      throw ApiKeyException(
        ApiKeyErrorCodes.serviceUnavailable,
        technicalMessage:
            'Provider ${providerId.id} returned ${response.statusCode}',
      );
    } on ApiKeyException {
      rethrow;
    } on SocketException {
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
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
        // GET /v1beta/models?key={key} — lists available models
        return _httpClient.get(
          Uri.parse(
            '${AppConstants.geminiBaseUrl}/models?key=$apiKey',
          ),
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

  @override
  Future<void> saveKey({
    required String uid,
    required AiProviderId providerId,
    required String apiKey,
  }) async {
    try {
      final model = ApiKeyModel(
        aiProviderId: providerId.id,
        aiProviderModelFeatures: providerId.features,
        apiKey: apiKey.trim(),
        isValid: true,
      );

      // Write to Firestore — path: AI_Voice_Genie/apiKeys/{uid}/{providerId}
      await _firestore
          .doc(FirebaseCollections.apiKeyDoc(uid, providerId.id))
          .set({
        ...model.toFirestore(),
        FirebaseCollections.fieldKeyAddedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update memory cache
      _memoryCache[providerId] = model;

      debugPrint('✅ Key saved [${providerId.id}] for user $uid');
    } on FirebaseException catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'Firestore save failed: ${e.code} — ${e.message}',
      );
    } catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'Unexpected save error: $e',
      );
    }
  }

  // ── Load Keys ──────────────────────────────────────────────────────────────

  @override
  Future<Map<AiProviderId, ApiKeyModel>> loadKeys({
    required String uid,
    AiProviderId? providerId,
  }) async {
    // If the authenticated user changed, invalidate previous user's cached keys
    if (_cachedUid != null && _cachedUid != uid) {
      _memoryCache.clear();
    }
    _cachedUid = uid;

    // Step 1: Memory cache short-circuit.
    // If the caller requested an individual provider whose key is already cached,
    // return immediately without initiating a Firestore roundtrip.
    if (providerId != null && _memoryCache.containsKey(providerId)) {
      debugPrint('🚀 KeyRepository: memory cache hit [${providerId.id}]');
      return {providerId: _memoryCache[providerId]!};
    }

    // Step 2: Determine target documents to fetch.
    // If providerId is specified, fetch only that document (1 read).
    // Otherwise, fetch all known providers in parallel.
    final targets = providerId != null ? [providerId] : AiProviderId.values;
    final result = <AiProviderId, ApiKeyModel>{};

    try {
      // Step 3: Concurrently fetch targeted Firestore documents via Future.wait.
      final futures = targets.map(
        (provider) => _firestore
            .doc(FirebaseCollections.apiKeyDoc(uid, provider.id))
            .get(),
      );

      final snapshots = await Future.wait(futures);

      // Step 4: Parse valid Firestore documents into ApiKeyModel domain instances.
      for (final snapshot in snapshots) {
        if (snapshot.exists && snapshot.data() != null) {
          final model = ApiKeyModel.fromFirestore(snapshot.data()!);
          result[AiProviderId.fromId(model.aiProviderId)] = model;
        }
      }

      // Step 5: Merge fetched results into local in-memory cache for fast subsequent access.
      _memoryCache.addAll(result);

      debugPrint(
        '📦 KeyRepository: loaded ${result.length} keys for user $uid '
        '${providerId != null ? '[single: ${providerId.id}]' : '[all]'}',
      );
      return result;
    } on FirebaseException catch (e) {
      // Step 6a: Translate Firebase connection errors into typed ApiKeyException.
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
      // Step 6b: Translate low-level socket drops into noInternet error code.
      debugPrint('⚠️ loadKeys network error: $e');
      throw const ApiKeyException(ApiKeyErrorCodes.noInternet);
    } catch (e) {
      // Step 6c: Rethrow known exceptions or wrap unexpected errors safely.
      if (e is ApiKeyException) rethrow;
      debugPrint('⚠️ loadKeys unexpected error: $e');
      throw ApiKeyException(ApiKeyErrorCodes.unknown, technicalMessage: '$e');
    }
  }

  @override
  Stream<Map<AiProviderId, ApiKeyModel>> watchKeys(String uid) {
    // The collection path for a user's API keys is derived from the doc path
    // by removing the specific providerId.
    // Example doc path: AIVoiceGenie/apiKeys/{uid}/{providerId}
    // So collection path is: AIVoiceGenie/apiKeys/{uid}
    final collectionPath =
        '${FirebaseCollections.root}/${FirebaseCollections.apiKeys}/$uid';

    return _firestore.collection(collectionPath).snapshots().map((snapshot) {
      final result = <AiProviderId, ApiKeyModel>{};

      for (final doc in snapshot.docs) {
        if (doc.data().isNotEmpty) {
          final model = ApiKeyModel.fromFirestore(doc.data());
          result[AiProviderId.fromId(model.aiProviderId)] = model;
        }
      }

      // Sync memory cache
      _memoryCache.clear();
      _memoryCache.addAll(result);

      return result;
    });
  }

  // ── Delete Key ─────────────────────────────────────────────────────────────

  @override
  Future<void> deleteKey({
    required String uid,
    required AiProviderId providerId,
  }) async {
    try {
      await _firestore
          .doc(FirebaseCollections.apiKeyDoc(uid, providerId.id))
          .get()
          .then((doc) => doc.reference.delete());

      // Update memory cache
      _memoryCache.remove(providerId);

      debugPrint('🗑️ Key deleted [${providerId.id}] for user $uid');
    } on FirebaseException catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'Firestore delete failed: ${e.code}',
      );
    }
  }

  // ── Complete Setup ─────────────────────────────────────────────────────────

  @override
  Future<void> completeKeySetup({
    required String uid,
    required AiProviderId preferredProvider,
  }) async {
    try {
      // Update user document — mark key setup complete
      await _firestore.doc(FirebaseCollections.userDoc(uid)).update({
        FirebaseCollections.fieldKeySetupDone: true,
      });

      // Persist to Hive for fast splash-screen reads
      await _storage.setBool(StorageKeys.keySetupCompleted, true);
      await _storage.setString(
        StorageKeys.preferredProviderId,
        preferredProvider.id,
      );

      debugPrint(
        '✅ Key setup complete for $uid — preferred: ${preferredProvider.id}',
      );
    } on FirebaseException catch (e) {
      throw ApiKeyException(
        ApiKeyErrorCodes.saveFailed,
        technicalMessage: 'completeKeySetup Firestore failed: ${e.code}',
      );
    }
  }
}
