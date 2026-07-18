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

  /// Date of birth (optional).
  final DateTime? dateOfBirth;

  /// Age (optional numeric input).
  final int? age;

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
      this.dateOfBirth,
      this.age,
      this.createdAt,
      this.lastLoginAt,
      this.lastUpdatedAt});

  // ── Factory: from Firestore document ─────────────────────────────────────

  /// Construct a UserModel from an existing Firestore document map.
  ///
  /// Used when reading a returning user's document.
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'User',
      photoUrl: data['photoUrl'] as String? ?? '',
      authProvider: SocialAuthProvider.fromId(
        data['authProvider'] as String? ?? 'google',
      ),
      isNewUser: false,
      onboardingDone: data['onboardingDone'] as bool? ?? false,
      keySetupDone: data['keySetupDone'] as bool? ?? false,
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'] as int?,
      createdAt: data[FirebaseCollections.fieldCreatedAt] != null
          ? (data[FirebaseCollections.fieldCreatedAt] as Timestamp).toDate()
          : null,
      lastLoginAt: data[FirebaseCollections.fieldLastLoginAt] != null
          ? (data[FirebaseCollections.fieldLastLoginAt] as Timestamp).toDate()
          : null,
      lastUpdatedAt: data[FirebaseCollections.fieldLastUpdatedAt] != null
          ? (data[FirebaseCollections.fieldLastUpdatedAt] as Timestamp).toDate()
          : null,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Serialize to a map for Firestore document creation (new user only).
  ///
  /// Does NOT include createdAt/lastLoginAt — those are set with
  /// FieldValue.serverTimestamp() directly in the repository.
  Map<String, dynamic> toFirestoreNewUser() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'authProvider': authProvider.id,
      'onboardingDone': false,
      'keySetupDone': false,
      'dateOfBirth': null,
      'age': null,
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
    DateTime? dateOfBirth,
    int? age,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastUpdatedAt,
    String? preferredAiModel,
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
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        age: age ?? this.age,
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
      'displayName: $displayName, provider: ${authProvider.id})';
}
