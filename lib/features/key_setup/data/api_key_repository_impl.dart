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

  /// In-memory cache for API keys loaded during the current session.
  /// Minimizes Firestore reads during AI orchestration and fallbacks.
  final Map<AiProviderId, ApiKeyModel> _memoryCache = {};

  ApiKeyRepositoryImpl({
    FirebaseFirestore? firestore,
    StorageService? storage,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
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
        providerId: providerId,
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
  Future<Map<AiProviderId, ApiKeyModel>> loadKeys(String uid) async {
    final result = <AiProviderId, ApiKeyModel>{};

    try {
      // Fetch all three provider docs in parallel — max 3 Firestore reads
      final futures = AiProviderId.values.map(
            (provider) => _firestore
            .doc(FirebaseCollections.apiKeyDoc(uid, provider.id))
            .get(),
      );

      final snapshots = await Future.wait(futures);

      for (final snapshot in snapshots) {
        if (snapshot.exists && snapshot.data() != null) {
          final model = ApiKeyModel.fromFirestore(snapshot.data()!);
          result[model.providerId] = model;
        }
      }

      // Sync memory cache
      _memoryCache.clear();
      _memoryCache.addAll(result);

      debugPrint('📦 Loaded ${result.length} keys for user $uid (and cached locally)');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('⚠️ loadKeys Firestore error: ${e.code}');
      // Return empty map — UI will show all providers as notAdded
      return result;
    } catch (e) {
      debugPrint('⚠️ loadKeys unexpected error: $e');
      return result;
    }
  }

  @override
  Future<ApiKeyModel?> loadKey({
    required String uid,
    required AiProviderId providerId,
  }) async {
    // Check memory cache first
    if (_memoryCache.containsKey(providerId)) {
      debugPrint('🚀 KeyRepository: memory cache hit [${providerId.id}]');
      return _memoryCache[providerId];
    }

    try {
      final doc = await _firestore
          .doc(FirebaseCollections.apiKeyDoc(uid, providerId.id))
          .get();

      if (!doc.exists || doc.data() == null) return null;
      final model = ApiKeyModel.fromFirestore(doc.data()!);

      // Update memory cache
      _memoryCache[providerId] = model;

      return model;
    } catch (e) {
      debugPrint('⚠️ loadKey [${providerId.id}] error: $e');
      return null;
    }
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
        FirebaseCollections.fieldPreferredProvider: preferredProvider.id,
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
        technicalMessage:
        'completeKeySetup Firestore failed: ${e.code}',
      );
    }
  }
}