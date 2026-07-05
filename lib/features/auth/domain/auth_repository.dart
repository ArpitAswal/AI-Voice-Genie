import 'dart:io';

import 'user_model.dart';

/// Abstract authentication repository for AI Voice Genie.
///
/// AuthProvider only depends on this interface — never on Firebase directly.
/// This decoupling means:
///   - Swapping Google for Apple (or adding more providers) = new method here only
///   - AuthProvider and LoginScreen require zero changes when providers change
///   - The implementation is fully testable with mock repositories
///
/// Implementations: AuthRepositoryImpl (Firebase + Firestore)
abstract class AuthRepository {
  /// Sign in using Google OAuth.
  ///
  /// Returns null if the user cancels the Google account picker.
  /// Throws [AuthException] on any other failure.
  Future<UserModel?> signInWithGoogle();

  /// Sign in using Apple Sign-In (iOS only).
  ///
  /// Returns null if the user cancels the Apple authentication sheet.
  /// Throws [AuthException] on any other failure.
  /// Must never be called on Android — guard with Platform.isIOS before calling.
  Future<UserModel?> signInWithApple();

  /// Retrieve the currently signed-in user.
  ///
  /// Returns null if no active session exists.
  /// Reads from FirebaseAuth.currentUser — does NOT make a Firestore call.
  Future<UserModel?> getCurrentUser();

  /// Sign out the current user from all providers.
  ///
  /// Clears Firebase session, Google Sign-In state, and Hive session flags.
  Future<void> signOut();

  /// Whether Apple Sign-In is available on this device.
  ///
  /// Returns true only on iOS. Always false on Android.
  /// Use this in UI to conditionally render the Apple Sign-In button.
  bool get isAppleSignInAvailable;

  /// Updating the field in the firestore
  ///
  /// User the user id or FirebaseAuth.currentUser to update only auth user
  Future<bool> updateUser(UserModel? currentUser,
      {required String field, required bool value});

  /// Update editable profile fields for the signed-in user.
  Future<bool> updateProfile(
    UserModel currentUser, {
    required String displayName,
    required String photoUrl,
    DateTime? dateOfBirth,
    int? age,
    File? photoFile,
  });
}

// =============================================================================
// AUTH EXCEPTION — typed error class for the auth layer
// =============================================================================

/// Typed exception thrown by AuthRepository implementations.
///
/// Maps provider-specific errors to app-level error codes
/// that map directly to AppLocalizations keys.
class AuthException implements Exception {
  /// Localization key — maps directly to AppLocalizations.translate(code)
  final String code;

  /// Optional technical message for debug logging (never shown to user)
  final String? technicalMessage;

  const AuthException(this.code, {this.technicalMessage});

  /// Whether this error is a user-initiated cancellation (not an error)
  bool get isCancelled => code == AuthErrorCodes.cancelled;

  @override
  String toString() =>
      'AuthException(code: $code, technical: $technicalMessage)';
}

/// All possible auth error codes — each maps to an AppLocalizations key.
class AuthErrorCodes {
  /// User cancelled the sign-in flow (not an error — silent)
  static const String cancelled = 'cancelled';

  /// No internet connection available
  static const String noInternet = 'no_internet_connection';

  /// Generic sign-in failure (wrong credentials, service error)
  static const String signInFailed = 'sign_in_failed';

  /// Firebase credential was invalid or expired
  static const String invalidCredential = 'sign_in_failed';

  /// User's account has been disabled in Firebase console
  static const String userDisabled = 'sign_in_failed';

  /// Apple Sign-In not available on this device/OS version
  static const String appleNotAvailable = 'sign_in_failed';

  /// Firestore user document write failed
  static const String firestoreWriteFailed = 'something_went_wrong';

  /// Unknown / unexpected error
  static const String unknown = 'something_went_wrong';
}
