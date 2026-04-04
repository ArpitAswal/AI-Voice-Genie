import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/constants/firebase_collections.dart';

/// Immutable domain entity representing a stored AI provider API key.
///
/// Stored in Firestore at:
///   AI_Voice_Genie/users/{uid}/apiKeys/{providerId}
///
/// The [apiKey] field contains the raw key string.
/// Firestore security rules must restrict access to the owning uid only.
class ApiKeyModel {
  /// Which AI provider this key belongs to
  final AiProviderId providerId;

  /// The raw API key string — stored in Firestore, read at runtime
  final String apiKey;

  /// Whether this key passed live validation
  final bool isValid;

  /// When this key was first added
  final DateTime? keyAddedAt;

  /// When this key was last validated
  final DateTime? lastValidated;

  const ApiKeyModel({
    required this.providerId,
    required this.apiKey,
    required this.isValid,
    this.keyAddedAt,
    this.lastValidated,
  });

  // ── Factory: from Firestore ───────────────────────────────────────────────

  factory ApiKeyModel.fromFirestore(Map<String, dynamic> data) {
    return ApiKeyModel(
      providerId: AiProviderId.fromId(
        data[FirebaseCollections.fieldProviderId] as String? ?? 'openai',
      ),
      apiKey: data[FirebaseCollections.fieldApiKey] as String? ?? '',
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
      FirebaseCollections.fieldProviderId: providerId.id,
      FirebaseCollections.fieldApiKey: apiKey,
      FirebaseCollections.fieldKeyIsValid: isValid,
      FirebaseCollections.fieldKeyLastValidated: FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ApiKeyModel copyWith({
    AiProviderId? providerId,
    String? apiKey,
    bool? isValid,
    DateTime? keyAddedAt,
    DateTime? lastValidated,
  }) {
    return ApiKeyModel(
      providerId: providerId ?? this.providerId,
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
              providerId == other.providerId;

  @override
  int get hashCode => providerId.hashCode;

  @override
  String toString() =>
      'ApiKeyModel(provider: ${providerId.id}, valid: $isValid)';
}