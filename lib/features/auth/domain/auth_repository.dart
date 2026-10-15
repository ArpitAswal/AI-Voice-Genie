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

  // Apple Sign-In is temporarily disabled (pending Apple Developer account setup)
  // Future<UserModel?> signInWithApple();

  /// Retrieve the currently signed-in user.
  ///
  /// Returns null if no active session exists.
  /// Reads from FirebaseAuth.currentUser — does NOT make a Firestore call.
  Future<UserModel?> getCurrentUser();

  /// Stream of authentication state changes (emits null when session ends or account is deleted).
  Stream<UserModel?> get authStateChanges;

  /// Stream that emits true if the user's Firestore profile document exists, false if deleted.
  /// Used to detect real-time remote account deletion across multiple devices.
  Stream<bool> watchUserExists(String uid);

  /// Forcefully re-verify the active Firebase session against backend servers.
  /// Throws [AuthException] if the account was deleted or disabled remotely.
  Future<void> reloadSession();

  /// Sign out the current user from all providers.
  ///
  /// Clears Firebase session, Google Sign-In state, and Hive session flags.
  Future<void> signOut();

  /// Deletes the user's account and associated data from Firestore and Auth provider.
  Future<bool> deleteAccount();

  // Apple Sign-In availability getter — disabled pending Apple Developer account
  // bool get isAppleSignInAvailable;

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
    required String email,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? country,
    String? state,
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

  /// Generic sign-in failure
  static const String signInFailed = 'sign_in_failed';

  /// Firebase credential was invalid or expired
  static const String invalidCredential = 'invalid_credential';

  /// User's account has been disabled in Firebase console
  static const String userDisabled = 'user_disabled';

  /// User account not found
  static const String userNotFound = 'user_not_found';

  /// Account exists with a different sign-in provider
  static const String accountExistsDifferentCredential =
      'account_exists_different_credential';

  /// Too many attempts from this device/IP
  static const String tooManyRequests = 'too_many_requests';

  /// Sign-in provider is not enabled in Firebase
  static const String operationNotAllowed = 'operation_not_allowed';

  /// Apple Sign-In not available on this device/OS version
  static const String appleNotAvailable = 'apple_not_available';

  /// Firestore user document write failed
  static const String firestoreWriteFailed = 'something_went_wrong';

  /// Sensitive operation requires recent authentication
  static const String requiresRecentLogin = 'requires_recent_login';

  /// Active session has expired or been terminated remotely
  static const String sessionExpired = 'session_expired';

  /// Sign-out operation failed
  static const String signOutFailed = 'sign_out_failed';

  /// Account deletion operation failed
  static const String deleteAccountFailed = 'delete_account_failed';

  /// Unknown / unexpected error
  static const String unknown = 'something_went_wrong';
}
