import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../domain/user_model.dart';

/// Data Transfer Object (DTO) for User entity serialization and deserialization.
///
/// Encapsulates all Firestore network mapping logic, resilient type conversions,
/// and ensures only necessary (non-null) data is stored in the database.
class UserDto {
  UserDto._();

  // ── Deserialization: Firestore Map -> UserModel ───────────────────────────

  /// Converts a Firestore document data map into a domain [UserModel].
  ///
  /// Uses defensive parsing to prevent runtime crashes if fields in Firestore
  /// have unexpected types or are missing.
  static UserModel fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: _parseString(data[FirebaseCollections.fieldUid]),
      authProvider: SocialAuthProvider.fromId(
        _parseString(data[FirebaseCollections.fieldAuthProvider], 'google'),
      ),
      email: _parseString(data[FirebaseCollections.fieldEmail]),
      displayName: _parseString(data[FirebaseCollections.fieldDisplayName]),
      photoUrl: _parseString(data[FirebaseCollections.fieldPhotoUrl]),
      isNewUser: _parseBool(data[FirebaseCollections.fieldNewUser]),
      onboardingDone: _parseBool(data[FirebaseCollections.fieldOnboardingDone]),
      keySetupDone: _parseBool(data[FirebaseCollections.fieldKeySetupDone]),
      termsAccepted: _parseBool(data[FirebaseCollections.fieldTermsAccepted]),
      termsAcceptedAt:
          _parseDateTime(data[FirebaseCollections.fieldTermsAcceptedAt]),
      termsVersionAccepted:
          data[FirebaseCollections.fieldTermsVersionAccepted]?.toString(),
      dateOfBirth: _parseDateTime(data[FirebaseCollections.fieldDateOfBirth]),
      age: _parseInt(data[FirebaseCollections.fieldAge]),
      gender: data[FirebaseCollections.fieldGender]?.toString(),
      country: data[FirebaseCollections.fieldCountry]?.toString(),
      state: data[FirebaseCollections.fieldState]?.toString(),
      createdAt: _parseDateTime(data[FirebaseCollections.fieldCreatedAt]),
      lastLoginAt: _parseDateTime(data[FirebaseCollections.fieldLastLoginAt]),
      lastUpdatedAt:
          _parseDateTime(data[FirebaseCollections.fieldLastUpdatedAt]),
    );
  }

  // ── Serialization: UserModel -> Firestore Map ─────────────────────────────

  /// Builds a minimal, clean map for new user document creation.
  ///
  /// Only includes necessary initial fields and omits null values to save
  /// storage and bandwidth in Firestore.
  static Map<String, dynamic> toNewUserMap(UserModel user) {
    final map = <String, dynamic>{
      FirebaseCollections.fieldUid: user.uid,
      FirebaseCollections.fieldEmail: user.email,
      FirebaseCollections.fieldDisplayName: user.displayName,
      FirebaseCollections.fieldPhotoUrl: user.photoUrl,
      FirebaseCollections.fieldAuthProvider: user.authProvider.id,
      FirebaseCollections.fieldNewUser: user.isNewUser,
      FirebaseCollections.fieldOnboardingDone: user.onboardingDone,
      FirebaseCollections.fieldKeySetupDone: user.keySetupDone,
      FirebaseCollections.fieldTermsAccepted: user.termsAccepted,
      FirebaseCollections.fieldTermsAcceptedAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldCreatedAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (user.termsVersionAccepted != null &&
        user.termsVersionAccepted!.isNotEmpty) {
      map[FirebaseCollections.fieldTermsVersionAccepted] =
          user.termsVersionAccepted;
    }

    return map;
  }

  /// Builds an update map for user profile changes, omitting nulls.
  static Map<String, dynamic> toProfileUpdateMap({
    required String displayName,
    required String photoUrl,
    required String email,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? country,
    String? state,
  }) {
    final map = <String, dynamic>{
      FirebaseCollections.fieldDisplayName: displayName,
      FirebaseCollections.fieldPhotoUrl: photoUrl,
      FirebaseCollections.fieldEmail: email.trim(),
      FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (dateOfBirth != null) {
      map[FirebaseCollections.fieldDateOfBirth] =
          Timestamp.fromDate(dateOfBirth);
    }
    if (age != null) {
      map[FirebaseCollections.fieldAge] = age;
    }
    if (gender != null && gender.isNotEmpty) {
      map[FirebaseCollections.fieldGender] = gender;
    }
    if (country != null && country.isNotEmpty) {
      map[FirebaseCollections.fieldCountry] = country;
    }
    if (state != null && state.isNotEmpty) {
      map[FirebaseCollections.fieldState] = state;
    }

    return map;
  }

  // ── Defensive Type Parsing Helpers ────────────────────────────────────────

  static String _parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static bool _parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      return lower == 'true' || lower == '1';
    }
    return fallback;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
