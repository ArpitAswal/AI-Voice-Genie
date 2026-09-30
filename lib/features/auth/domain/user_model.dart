import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Normalized user entity for AI Voice Genie.
///
/// Both Google and Apple Sign-In produce this same model.
/// Immutable — use copyWith() to produce updated versions.
///
/// Field guarantees:
///   uid          → always non-empty (Firebase UID)
///   email        → non-empty for Google; may be '' for Apple returning users
///   displayName  → non-empty for Google; may be 'User' fallback for Apple
///   photoUrl     → non-empty for Google; always '' for Apple
///   authProvider → always set — tracks which provider was used
class UserModel {
  /// Firebase UID — primary identifier across the entire app
  final String uid;

  /// User's email address.
  /// Google: always present.
  /// Apple first sign-in: present if user chose to share.
  /// Apple returning: empty string — read from Firestore instead.
  final String email;

  /// Display name shown in profile UI.
  /// Google: full name from Google account.
  /// Apple: given name from first sign-in, or 'User' fallback.
  final String displayName;

  /// Profile photo URL.
  /// Google: Google account photo URL.
  /// Apple: always empty string — Apple does not provide photos.
  final String photoUrl;

  /// Which social provider was used to authenticate.
  final SocialAuthProvider authProvider;

  /// Whether this is the user's first-ever sign-in (new Firestore document).
  /// Used to decide: logUserRegistered() vs logUserSignedIn()
  /// and to route to OnboardingScreen vs TabBarScreen.
  final bool isNewUser;

  /// Whether the user has completed the onboarding flow.
  /// Read from Firestore — defaults to false for new users.
  final bool onboardingDone;

  /// Whether the user has completed the AI key setup flow.
  /// Read from Firestore — defaults to false for new users.
  final bool keySetupDone;

  /// Whether the user accepted the Terms of Service and Privacy Policy.
  final bool termsAccepted;

  /// The timestamp when the user accepted the terms.
  final DateTime? termsAcceptedAt;

  /// The version string of the legal terms accepted by this user (e.g., '2026-07-v1').
  final String? termsVersionAccepted;

  /// Date of birth (optional).
  final DateTime? dateOfBirth;

  /// Age (optional numeric input).
  final int? age;

  /// Gender (optional).
  final String? gender;

  /// Country (optional).
  final String? country;

  /// State/Province (optional).
  final String? state;

  /// The time this user was first created.
  final DateTime? createdAt;

  /// The time this user last logged in.
  final DateTime? lastLoginAt;

  /// The time this user last updated.
  final DateTime? lastUpdatedAt;

  const UserModel(
      {required this.uid,
      required this.email,
      required this.displayName,
      required this.photoUrl,
      required this.authProvider,
      this.isNewUser = false,
      this.onboardingDone = false,
      this.keySetupDone = false,
      this.termsAccepted = false,
      this.termsAcceptedAt,
      this.termsVersionAccepted,
      this.dateOfBirth,
      this.age,
      this.gender,
      this.country,
      this.state,
      this.createdAt,
      this.lastLoginAt,
      this.lastUpdatedAt});

  // ── Factory: from Firestore document ─────────────────────────────────────

  /// Construct a UserModel from an existing Firestore document map.
  ///
  /// Resilient DTO parsing: uses defensive type conversion helpers so that if
  /// any field type, key, or format changes in Firestore (e.g. number as string,
  /// timestamp as ISO string, boolean as int), the app will never crash with a TypeError.
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: _parseString(data[FirebaseCollections.fieldUid]),
      email: _parseString(data[FirebaseCollections.fieldEmail]),
      displayName:
          _parseString(data[FirebaseCollections.fieldDisplayName], 'User'),
      photoUrl: _parseString(data[FirebaseCollections.fieldPhotoUrl]),
      authProvider: SocialAuthProvider.fromId(
        _parseString(data[FirebaseCollections.fieldAuthProvider], 'google'),
      ),
      // Read isNewUser from Firestore (safely handles bool, string, or int)
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

  // ── DTO Defensive Parsing Helpers ──────────────────────────────────────────

  /// Safely converts any dynamic value to a String with a default fallback.
  static String _parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  /// Safely converts dynamic value to boolean (handles bool, int 1/0, and 'true'/'false').
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

  /// Safely converts dynamic value to int (handles int, double, and numeric string).
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Safely converts dynamic value to DateTime (handles Timestamp, ISO string, and epoch int).
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Serialize to a map for Firestore document creation (new user only).
  ///
  /// Does NOT include createdAt/lastLoginAt — those are set with
  /// FieldValue.serverTimestamp() directly in the repository.
  Map<String, dynamic> toFirestoreNewUser() {
    return {
      FirebaseCollections.fieldUid: uid,
      FirebaseCollections.fieldEmail: email,
      FirebaseCollections.fieldDisplayName: displayName,
      FirebaseCollections.fieldPhotoUrl: photoUrl,
      FirebaseCollections.fieldAuthProvider: authProvider.id,
      // Persist isNewUser state (true for first-time users, false if re-registered after deletion)
      FirebaseCollections.fieldNewUser: isNewUser,
      FirebaseCollections.fieldOnboardingDone: false,
      FirebaseCollections.fieldKeySetupDone: false,
      FirebaseCollections.fieldTermsAccepted: termsAccepted,
      FirebaseCollections.fieldTermsAcceptedAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldTermsVersionAccepted: termsVersionAccepted,
      FirebaseCollections.fieldDateOfBirth: null,
      FirebaseCollections.fieldAge: null,
      FirebaseCollections.fieldGender: null,
      FirebaseCollections.fieldCountry: null,
      FirebaseCollections.fieldState: null,
      FirebaseCollections.fieldCreatedAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  /// Return a new UserModel with selected fields replaced.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    SocialAuthProvider? authProvider,
    bool? isNewUser,
    bool? onboardingDone,
    bool? keySetupDone,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? termsVersionAccepted,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? country,
    String? state,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastUpdatedAt,
  }) {
    return UserModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        authProvider: authProvider ?? this.authProvider,
        isNewUser: isNewUser ?? this.isNewUser,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        keySetupDone: keySetupDone ?? this.keySetupDone,
        termsAccepted: termsAccepted ?? this.termsAccepted,
        termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
        termsVersionAccepted: termsVersionAccepted ?? this.termsVersionAccepted,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        country: country ?? this.country,
        state: state ?? this.state,
        createdAt: createdAt ?? this.createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt);
  }

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'UserModel(uid: $uid, email: $email, '
      'displayName: $displayName, provider: ${authProvider.id}, termsAccepted: $termsAccepted)';
}
