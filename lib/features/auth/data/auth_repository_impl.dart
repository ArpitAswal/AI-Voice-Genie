import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';
import '../../../../core/enums/app_enums.dart';

/// Concrete implementation of AuthRepository.
///
/// Handles:
///   - Google Sign-In (Android + iOS)
///   - Apple Sign-In (iOS only)
///   - Firestore user document creation and update
///   - Hive session persistence
///   - Apple missing-field fallback via Firestore lookup
///
/// Never instantiated directly — always accessed via AuthRepository interface.
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final StorageService _storage;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    StorageService? storage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _storage = storage ?? StorageService();

  // ── Apple Sign-In Availability ─────────────────────────────────────────────

  @override
  bool get isAppleSignInAvailable => Platform.isIOS;

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Trigger the native Google account picker
      final googleUser = await _googleSignIn.signIn();

      // User cancelled the picker — not an error, return null silently
      if (googleUser == null) return null;

      // Obtain auth tokens from the selected Google account
      final googleAuth = await googleUser.authentication;

      // Validate tokens are present before creating credential
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw const AuthException(
          AuthErrorCodes.signInFailed,
          technicalMessage: 'Google auth tokens were null after sign-in',
        );
      }

      // Create Firebase credential from Google tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthException(
          AuthErrorCodes.signInFailed,
          technicalMessage: 'Firebase user was null after Google sign-in',
        );
      }

      // Create or update Firestore document and return normalized UserModel
      return await _createOrUpdateUser(
        firebaseUser: firebaseUser,
        provider: SocialAuthProvider.google,
      );
    } on AuthException {
      // Re-throw our typed exceptions as-is
      rethrow;
    } on SocketException {
      throw const AuthException(AuthErrorCodes.noInternet);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        technicalMessage: 'FirebaseAuthException: ${e.code} — ${e.message}',
      );
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.unknown,
        technicalMessage: 'Unexpected Google sign-in error: $e',
      );
    }
  }

  // ── Apple Sign-In ──────────────────────────────────────────────────────────

  @override
  Future<UserModel?> signInWithApple() async {
    try {
      // Generate a cryptographic nonce for Apple Sign-In security
      // The raw nonce is sent to Apple, the hashed nonce is sent to Firebase
      // Firebase verifies that hash(rawNonce) == hashedNonce
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // Request Apple credential with the hashed nonce
      AuthorizationCredentialAppleID appleCredential;
      try {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );
      } on SignInWithAppleAuthorizationException catch (e) {
        // User cancelled the Apple sheet — not an error
        if (e.code == AuthorizationErrorCode.canceled) return null;
        throw AuthException(
          AuthErrorCodes.signInFailed,
          technicalMessage:
              'Apple authorization error: ${e.code} — ${e.message}',
        );
      }

      // Create Firebase OAuth credential with the raw nonce
      // Firebase will hash it internally and compare with hashedNonce
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with Apple credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(oauthCredential);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthException(
          AuthErrorCodes.signInFailed,
          technicalMessage: 'Firebase user was null after Apple sign-in',
        );
      }

      // Apple only provides name and email on the FIRST sign-in
      // Extract them here — they will be null on subsequent sign-ins
      final appleGivenName = appleCredential.givenName;
      final appleEmail = appleCredential.email;

      return await _createOrUpdateUser(
        firebaseUser: firebaseUser,
        provider: SocialAuthProvider.apple,
        appleGivenName: appleGivenName,
        appleEmail: appleEmail,
      );
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthException(AuthErrorCodes.noInternet);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code),
        technicalMessage: 'FirebaseAuthException: ${e.code} — ${e.message}',
      );
    } catch (e) {
      throw AuthException(
        AuthErrorCodes.unknown,
        technicalMessage: 'Unexpected Apple sign-in error: $e',
      );
    }
  }

  // ── Get Current User ───────────────────────────────────────────────────────

  @override
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    try {
      // Fetch Firestore document to get full profile including flags
      final doc = await _firestore
          .doc(FirebaseCollections.userDoc(firebaseUser.uid))
          .get();

      if (!doc.exists || doc.data() == null) {
        // Firebase session exists but Firestore doc is missing
        // This can happen if Firestore write failed on first sign-in
        // Re-create the document from Firebase user data
        debugPrint(
          '⚠️ AuthRepository: Firestore doc missing for existing Firebase user '
          '${firebaseUser.uid} — re-creating',
        );
        return await _createOrUpdateUser(
          firebaseUser: firebaseUser,
          provider: SocialAuthProvider.google, // safest fallback
        );
      }

      return UserModel.fromFirestore(doc.data()!);
    } catch (e) {
      // If Firestore fails, return a minimal model from Firebase data
      // so the user is not signed out unexpectedly
      debugPrint('⚠️ AuthRepository: getCurrentUser Firestore error — $e');
      return _buildMinimalUserModel(firebaseUser);
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      // Sign out from Google Sign-In (clears cached Google account)
      await _googleSignIn.signOut();
    } catch (e) {
      // Google sign-out failure is not critical — continue with Firebase signout
      debugPrint('⚠️ AuthRepository: Google signOut error — $e');
    }

    // Sign out from Firebase Auth
    await _firebaseAuth.signOut();

    // Clear all local session data
    await _storage.clearUserData();
    await _storage.setBool(StorageKeys.isLoggedIn, false);
  }

  // ── Private: Create or Update Firestore User Document ─────────────────────

  /// Core logic that handles both new and returning users for both providers.
  ///
  /// For NEW users: creates full document with all required fields.
  /// For RETURNING users: updates lastLoginAt only.
  /// For APPLE returning users: reads stored email/name from existing doc.
  Future<UserModel?> _createOrUpdateUser({
    required User firebaseUser,
    required SocialAuthProvider provider,
    String? appleGivenName,
    String? appleEmail,
  }) async {
    final uid = firebaseUser.uid;
    final docRef = _firestore.doc(FirebaseCollections.userDoc(uid));

    try {
      // Fetch existing document to determine new vs returning user
      final existingDoc = await docRef.get();
      final isNewUser = !existingDoc.exists;

      String resolvedDisplayName;
      String resolvedEmail;
      String resolvedPhotoUrl;
      bool onboardingDone = false;
      bool keySetupDone = false;

      if (isNewUser) {
        // ── NEW USER ─────────────────────────────────────────────────────────
        // For Google: use Firebase user data directly
        // For Apple: use credential data (available on first sign-in only)
        resolvedDisplayName = _resolveDisplayName(
          firebaseUser: firebaseUser,
          provider: provider,
          appleGivenName: appleGivenName,
        );
        resolvedEmail = _resolveEmail(
          firebaseUser: firebaseUser,
          provider: provider,
          appleEmail: appleEmail,
        );
        resolvedPhotoUrl = provider == SocialAuthProvider.google
            ? (firebaseUser.photoURL ?? '')
            : ''; // Apple never provides photo

        // Build the user model for the new document
        final newUser = UserModel(
          uid: uid,
          email: resolvedEmail,
          displayName: resolvedDisplayName,
          photoUrl: resolvedPhotoUrl,
          authProvider: provider,
          isNewUser: true,
          onboardingDone: false,
          keySetupDone: false,
        );

        // Write new user document with server timestamps
        await docRef.set({
          ...newUser.toFirestoreNewUser(),
          FirebaseCollections.fieldCreatedAt: FieldValue.serverTimestamp(),
          FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
        });

        // Persist session to Hive
        await _persistSession(newUser);

        return newUser;
      } else {
        // ── RETURNING USER ────────────────────────────────────────────────────
        final existingData = existingDoc.data()!;

        // For Apple returning users — name and email are null from Apple
        // Read the stored values from Firestore instead
        resolvedDisplayName =
            existingData[FirebaseCollections.fieldDisplayName] as String? ?? '';
        resolvedEmail =
            existingData[FirebaseCollections.fieldEmail] as String? ?? '';
        resolvedPhotoUrl =
            existingData[FirebaseCollections.fieldPhotoUrl] as String? ?? '';
        onboardingDone =
            existingData[FirebaseCollections.fieldOnboardingDone] as bool? ??
                false;
        keySetupDone =
            existingData[FirebaseCollections.fieldKeySetupDone] as bool? ??
                false;

        // Update only lastLoginAt — preserve all other fields
        await docRef.update({
          FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
        });

        final returningUser = UserModel(
          uid: uid,
          email: resolvedEmail,
          displayName: resolvedDisplayName,
          photoUrl: resolvedPhotoUrl,
          authProvider: provider,
          isNewUser: false,
          onboardingDone: onboardingDone,
          keySetupDone: keySetupDone,
        );

        // Re-hydrate Hive with latest data from Firestore
        await _persistSession(returningUser);

        return returningUser;
      }
    } on FirebaseException catch (e) {
      debugPrint(
        '❌ AuthRepository: Firestore write failed — ${e.code}: ${e.message}',
      );
      // Return minimal model from Firebase data so auth still succeeds
      // Firestore failure must not block the user from using the app
      return _buildMinimalUserModel(firebaseUser, provider: provider);
    } catch (e) {
      debugPrint('❌ AuthProvider unexpected sign-in error: $e');
      return null;
    }
  }

  // ── Private: Persist Session to Hive ──────────────────────────────────────

  /// Write all session-related keys to Hive for fast startup reads.
  Future<void> _persistSession(UserModel user) async {
    await _storage.setBool(StorageKeys.isLoggedIn, true);
    await _storage.setUserData(StorageKeys.userId, user.uid);
    await _storage.setUserData(StorageKeys.userEmail, user.email);
    await _storage.setUserData(StorageKeys.userDisplayName, user.displayName);
    await _storage.setUserData(StorageKeys.userPhotoUrl, user.photoUrl);
    await _storage.setBool(
      StorageKeys.onboardingCompleted,
      user.onboardingDone,
    );
    await _storage.setBool(StorageKeys.keySetupCompleted, user.keySetupDone);
  }

  // ── Private: Field Resolution Helpers ─────────────────────────────────────

  /// Resolve display name with Apple fallback strategy.
  String _resolveDisplayName({
    required User firebaseUser,
    required SocialAuthProvider provider,
    String? appleGivenName,
  }) {
    if (provider == SocialAuthProvider.google) {
      return firebaseUser.displayName?.isNotEmpty == true
          ? firebaseUser.displayName!
          : firebaseUser.email?.split('@').first ?? 'User';
    }
    // Apple: use given name from credential (first sign-in only)
    // Fall back to 'User' if not provided
    return appleGivenName?.isNotEmpty == true ? appleGivenName! : 'User';
  }

  /// Resolve email with Apple fallback strategy.
  String _resolveEmail({
    required User firebaseUser,
    required SocialAuthProvider provider,
    String? appleEmail,
  }) {
    if (provider == SocialAuthProvider.google) {
      return firebaseUser.email ?? '';
    }
    // Apple: use email from credential if available (first sign-in)
    // Fall back to Firebase user email (sometimes populated by Firebase)
    // Final fallback: empty string
    if (appleEmail?.isNotEmpty == true) return appleEmail!;
    if (firebaseUser.email?.isNotEmpty == true) return firebaseUser.email!;
    return '';
  }

  /// Build a minimal UserModel from Firebase user data only (no Firestore).
  ///
  /// Used as a safety fallback when Firestore is unavailable.
  UserModel _buildMinimalUserModel(
    User firebaseUser, {
    SocialAuthProvider provider = SocialAuthProvider.google,
  }) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      photoUrl: firebaseUser.photoURL ?? '',
      authProvider: provider,
      isNewUser: false,
      onboardingDone: false,
      keySetupDone: false,
    );
  }

  // ── Private: Firebase Error Mapping ───────────────────────────────────────

  /// Map Firebase Auth error codes to AppLocalizations keys.
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-disabled':
        return AuthErrorCodes.userDisabled;
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return AuthErrorCodes.invalidCredential;
      case 'network-request-failed':
        return AuthErrorCodes.noInternet;
      default:
        return AuthErrorCodes.signInFailed;
    }
  }

  // ── Private: Nonce Generation for Apple Sign-In ────────────────────────────

  /// Generate a cryptographically secure random nonce string.
  ///
  /// Used to prevent replay attacks in Apple Sign-In.
  /// The raw nonce is sent to Apple; its SHA-256 hash is sent to Firebase.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Return the SHA-256 hash of a string (used for Apple nonce).
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<bool> updateUser(UserModel? currentUser,
      {required String field, required bool value}) async {
    if (currentUser == null) {
      return false;
    }

    try {
      final uid = _firebaseAuth.currentUser?.uid ?? '';

      // Update only lastUpdatedAt and given field — preserve all other fields
      await _firestore.doc(FirebaseCollections.userDoc(uid)).update({
        FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
        field: value,
      });

      // Re-hydrate Hive with latest data from Firestore
      await _persistSession(currentUser);

      // Write to Hive — makes SplashScreen routing instant on next cold start
      await _storage.setBool(StorageKeys.onboardingCompleted, true);
      debugPrint("return true");
      return true;
    } on FirebaseException catch (e) {
      // Non-fatal — if Firestore fails, Hive still has the flag.
      // On next sign-in, Firestore will re-fetch and may show Onboarding again.
      // Acceptable edge case — much less disruptive than blocking the user.
      debugPrint(
        '⚠️ AuthRepository: markOnboardingComplete Firestore failed — '
        '${e.code}: ${e.message}',
      );
      // Still write Hive so the current session routes correctly
      await _storage.setBool(StorageKeys.onboardingCompleted, true);
      return false;
    } catch (e) {
      debugPrint('❌ AuthRepository: markOnboardingComplete error : $e');
      await _storage.setBool(StorageKeys.onboardingCompleted, true);
      return false;
    }
  }

  @override
  Future<bool> updateProfile(
    UserModel currentUser, {
    required String displayName,
    required String photoUrl,
  }) async {
    final resolvedDisplayName = displayName.trim();
    final resolvedPhotoUrl = photoUrl.trim();

    if (currentUser.uid.isEmpty || resolvedDisplayName.isEmpty) {
      return false;
    }

    try {
      final authUser = _firebaseAuth.currentUser;
      final uid = authUser?.uid ?? currentUser.uid;

      if (authUser != null) {
        await authUser.updateDisplayName(resolvedDisplayName);
        await authUser.updatePhotoURL(
          resolvedPhotoUrl.isEmpty ? null : resolvedPhotoUrl,
        );
      }

      await _firestore.doc(FirebaseCollections.userDoc(uid)).update({
        FirebaseCollections.fieldDisplayName: resolvedDisplayName,
        FirebaseCollections.fieldPhotoUrl: resolvedPhotoUrl,
        FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
      });

      final updatedUser = currentUser.copyWith(
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
      );

      await _persistSession(updatedUser);
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        '⚠️ AuthRepository: updateProfile Firestore failed — '
        '${e.code}: ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('❌ AuthRepository: updateProfile error : $e');
      return false;
    }
  }
}
