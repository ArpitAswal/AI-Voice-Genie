import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firebase_collections.dart';
import '../../../core/security/encryption_service.dart';

/// Immutable domain entity representing a stored AI provider API key.
///
/// Stored in Firestore at:
///   AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}
///
/// The [apiKey] field contains the raw key string at runtime.
/// When stored at rest in Cloud Firestore, it is encrypted via AES-256-CBC.
class ApiKeyModel {
  /// Which AI provider this key belongs to (e.g. 'openai', 'gemini', 'claude')
  final String aiProviderId;

  /// AI model features supported by this key
  final String aiProviderModelFeatures;

  /// The raw (decrypted) API key string — decrypted on load, encrypted on save
  final String apiKey;

  /// When this key was first added
  final DateTime? keyAddedAt;

  /// When this key was last validated
  final DateTime? lastValidated;

  const ApiKeyModel({
    required this.aiProviderId,
    required this.apiKey,
    required this.aiProviderModelFeatures,
    this.keyAddedAt,
    this.lastValidated,
  });

  // ── Factory: from Firestore ───────────────────────────────────────────────

  /// Deserializes a Firestore document map into an ApiKeyModel instance.
  /// Automatically decrypts the AES-256-CBC ciphertext into plaintext for in-memory use.
  factory ApiKeyModel.fromFirestore(Map<String, dynamic> data) {
    return ApiKeyModel(
      aiProviderId: data[FirebaseCollections.fieldProviderId] as String? ?? '',
      aiProviderModelFeatures:
          data[FirebaseCollections.fieldProviderModelFeatures] as String? ?? '',
      apiKey: EncryptionService.decrypt(
          data[FirebaseCollections.fieldApiKey] as String? ?? ''),
      keyAddedAt:
          (data[FirebaseCollections.fieldKeyAddedAt] as Timestamp?)?.toDate(),
      lastValidated:
          (data[FirebaseCollections.fieldKeyLastValidated] as Timestamp?)
              ?.toDate(),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Serializes this model into a Firestore map for saving.
  /// Automatically encrypts the raw API key with AES-256-CBC before transmission.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldProviderId: aiProviderId,
      FirebaseCollections.fieldProviderModelFeatures: aiProviderModelFeatures,
      FirebaseCollections.fieldApiKey: EncryptionService.encrypt(apiKey),
      FirebaseCollections.fieldKeyIsValid: true,
      FirebaseCollections.fieldKeyLastValidated: FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ApiKeyModel copyWith({
    String? providerId,
    String? providerFeatures,
    String? apiKey,
    DateTime? keyAddedAt,
    DateTime? lastValidated,
  }) {
    return ApiKeyModel(
      aiProviderId: providerId ?? aiProviderId,
      aiProviderModelFeatures: providerFeatures ?? aiProviderModelFeatures,
      apiKey: apiKey ?? this.apiKey,
      keyAddedAt: keyAddedAt ?? this.keyAddedAt,
      lastValidated: lastValidated ?? this.lastValidated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiKeyModel &&
          runtimeType == other.runtimeType &&
          aiProviderId == other.aiProviderId;

  @override
  int get hashCode => aiProviderId.hashCode;

  @override
  String toString() => 'ApiKeyModel(provider: $aiProviderId)';
}
