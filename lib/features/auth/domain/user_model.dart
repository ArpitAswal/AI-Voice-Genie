import '../../../core/enums/app_enums.dart';
import '../data/user_dto.dart';

/// Normalized domain user entity for AI Voice Genie.
///
/// Both Google and Apple Sign-In produce this same entity.
/// Immutable — use copyWith() to produce updated versions.
///
/// Only [uid] is required. All other fields have sensible default values or
/// are nullable, so callers can instantiate minimal or partial user models
/// without repetitive boilerplate.
class UserModel {
  /// Firebase UID — primary identifier across the entire app (Required).
  final String uid;

  /// Which social provider was used to authenticate (Required, e.g. Google or Apple).
  final SocialAuthProvider authProvider;

  /// User's email address (Optional, defaults to empty string).
  final String email;

  /// Display name shown in profile UI (Optional, defaults to empty string).
  final String displayName;

  /// Profile photo URL (Optional, defaults to empty string).
  final String photoUrl;

  /// Whether this is the user's first-ever sign-in (Optional, defaults to false).
  final bool isNewUser;

  /// Whether the user has completed the onboarding flow (Optional, defaults to false).
  final bool onboardingDone;

  /// Whether the user has completed the AI key setup flow (Optional, defaults to false).
  final bool keySetupDone;

  /// Whether the user accepted the Terms of Service (Optional, defaults to false).
  final bool termsAccepted;

  /// The timestamp when the user accepted the terms (Nullable, defaults to null).
  final DateTime? termsAcceptedAt;

  /// The version string of the legal terms accepted (Nullable, defaults to null, e.g. '2026-07-v1').
  final String? termsVersionAccepted;

  /// Date of birth (Nullable profile field).
  final DateTime? dateOfBirth;

  /// Age (Nullable numeric profile field).
  final int? age;

  /// Gender (Nullable profile field).
  final String? gender;

  /// Country (Nullable profile field).
  final String? country;

  /// State/Province (Nullable profile field).
  final String? state;

  /// The time this user was first created (Nullable).
  final DateTime? createdAt;

  /// The time this user last logged in (Nullable).
  final DateTime? lastLoginAt;

  /// The time this user profile was last updated (Nullable).
  final DateTime? lastUpdatedAt;

  const UserModel({
    required this.uid,
    required this.authProvider,
    this.email = '',
    this.displayName = '',
    this.photoUrl = '',
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
    this.lastUpdatedAt,
  });

  // ── DTO Serialization Bridges ─────────────────────────────────────────────

  /// Construct a UserModel from a Firestore document map via [UserDto].
  factory UserModel.fromFirestore(Map<String, dynamic> data) =>
      UserDto.fromFirestore(data);

  /// Serialize to a minimal new-user Firestore map via [UserDto].
  Map<String, dynamic> toFirestoreNewUser() => UserDto.toNewUserMap(this);

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
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  // ── Equality & String ─────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, displayName: $displayName, '
      'provider: ${authProvider.id}, termsAccepted: $termsAccepted)';
}
