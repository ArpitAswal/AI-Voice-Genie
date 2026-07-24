import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firebase_collections.dart';
import '../../../core/security/encryption_service.dart';

/// Immutable domain entity representing a stored AI provider API key.
///
/// Stored in Firestore at:
///   AI_Voice_Genie/users/{uid}/apiKeys/{providerId}
///
/// The [apiKey] field contains the raw key string.
/// Firestore security rules must restrict access to the owning uid only.
class ApiKeyModel {
  /// Which AI provider this key belongs to
  final String aiProviderId;

  /// AI model features supported by this key
  final String aiProviderModelFeatures;

  /// The raw API key string — stored in Firestore, read at runtime
  final String apiKey;

  /// Whether this key passed live validation
  final bool isValid;

  /// When this key was first added
  final DateTime? keyAddedAt;

  /// When this key was last validated
  final DateTime? lastValidated;

  const ApiKeyModel({
    required this.aiProviderId,
    required this.apiKey,
    required this.isValid,
    required this.aiProviderModelFeatures,
    this.keyAddedAt,
    this.lastValidated,
  });

  // ── Factory: from Firestore ───────────────────────────────────────────────

  factory ApiKeyModel.fromFirestore(Map<String, dynamic> data) {
    return ApiKeyModel(
      aiProviderId: data[FirebaseCollections.fieldProviderId] as String? ?? '',
      aiProviderModelFeatures:
          data[FirebaseCollections.fieldProviderModelFeatures] as String? ?? '',
      apiKey: EncryptionService.decrypt(
          data[FirebaseCollections.fieldApiKey] as String? ?? ''),
      isValid: data[FirebaseCollections.fieldKeyIsValid] as bool? ?? false,
      keyAddedAt:
          (data[FirebaseCollections.fieldKeyAddedAt] as Timestamp?)?.toDate(),
      lastValidated:
          (data[FirebaseCollections.fieldKeyLastValidated] as Timestamp?)
              ?.toDate(),
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Serialize to Firestore map for saving a new or updated key.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldProviderId: aiProviderId,
      FirebaseCollections.fieldProviderModelFeatures: aiProviderModelFeatures,
      FirebaseCollections.fieldApiKey: EncryptionService.encrypt(apiKey),
      FirebaseCollections.fieldKeyIsValid: isValid,
      FirebaseCollections.fieldKeyLastValidated: FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ApiKeyModel copyWith({
    String? providerId,
    String? providerFeatures,
    String? apiKey,
    bool? isValid,
    DateTime? keyAddedAt,
    DateTime? lastValidated,
  }) {
    return ApiKeyModel(
      aiProviderId: providerId ?? aiProviderId,
      aiProviderModelFeatures: providerFeatures ?? aiProviderModelFeatures,
      apiKey: apiKey ?? this.apiKey,
      isValid: isValid ?? this.isValid,
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
  String toString() => 'ApiKeyModel(provider: $aiProviderId, valid: $isValid)';
}
