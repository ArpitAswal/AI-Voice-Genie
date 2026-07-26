import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
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
import '../../chat/data/remote_chat_store.dart';

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

  AuthRepositoryImpl(
      {FirebaseAuth? firebaseAuth,
      FirebaseFirestore? firestore,
      GoogleSignIn? googleSignIn,
      StorageService? storage,
      EffectBus? effectBus})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
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

      debugPrint(
          "⚠️ AuthRepositoryImpl: signInWithGoogle and firebaseUser signInWithCredential");
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
    if (firebaseUser == null) {
      debugPrint(
          '⚠️ AuthRepository: getCurrentUser is null, means no user exist currently');
      return null;
    }

    // Verify session is still active and was not deleted/disabled on another device
    try {
      await firebaseUser.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired') {
        debugPrint(
            '⚠️ AuthRepository: User account terminated on remote device (${e.code}). Signing out.');
        await signOut();
        return null;
      }
    } catch (_) {
      // Ignore offline/network errors during reload so offline app launch still works
    }

    try {
      // Fetch Firestore document to get full profile including flags
      final doc = await _firestore
          .doc(FirebaseCollections.userDoc(firebaseUser.uid))
          .get();

      if (!doc.exists || doc.data() == null) {
        // If the Firestore document does not exist, the account was deleted
        // (e.g. on another device). Do NOT recreate the user document! Sign out and return null.
        debugPrint(
          '⚠️ AuthRepository: Firestore doc missing for Firebase user '
          '${firebaseUser.uid} (likely deleted on another device). Signing out.',
        );
        await signOut();
        return null;
      }

      return UserModel.fromFirestore(doc.data()!);
    } catch (e) {
      // If Firestore fails, return a minimal model from Firebase data
      // so the user is not signed out unexpectedly due to transient network errors
      debugPrint('⚠️ AuthRepository: getCurrentUser Firestore error — $e');
      return _buildMinimalUserModel(firebaseUser);
    }
  }

  @override
  Stream<UserModel?> get authStateChanges =>
      _firebaseAuth.userChanges().map((user) {
        if (user == null) return null;
        return _buildMinimalUserModel(user);
      });

  @override
  Stream<bool> watchUserExists(String uid) {
    return _firestore
        .doc(FirebaseCollections.userDoc(uid))
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Future<void> reloadSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired') {
        throw AuthException('session_expired', technicalMessage: e.code);
      }
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      // Sign out from Google Sign-In (clears cached Google account)
      await _googleSignIn.signOut();

      // Sign out from Firebase Auth
      await _firebaseAuth.signOut();

      // Clear all local session data
      _storage.clearUserData();
      _storage.setBool(StorageKeys.isLoggedIn, false);
      debugPrint('⚠️ AuthRepositoryImpl: User signed out successfully');
    } catch (e) {
      // Google sign-out failure is not critical — continue with Firebase signout
      debugPrint('⚠️ AuthRepository: Google/Firebase signOut error — $e');
    }
  }

  // ── Delete Account ────────────────────────────────────────────────────────

  @override
  Future<bool> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      final uid = user.uid;

      // ── Step 0: Ensure Recent Authentication ──────────────────────────────
      // Proactively re-authenticate the user before wiping ANY Firestore data.
      // In Firebase Auth, sensitive operations like user.delete() require recent
      // authentication. Doing this first ensures we never wipe a user's chats or
      // profile document only to fail at account deletion.
      bool reauthSuccess = false;
      try {
        for (final info in user.providerData) {
          if (info.providerId == 'google.com') {
            debugPrint(
                '🔄 Attempting Google re-authentication before account deletion...');
            final googleUser = await _googleSignIn.signInSilently() ??
                await _googleSignIn.signIn();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              if (googleAuth.accessToken != null &&
                  googleAuth.idToken != null) {
                final credential = GoogleAuthProvider.credential(
                  accessToken: googleAuth.accessToken,
                  idToken: googleAuth.idToken,
                );
                await user.reauthenticateWithCredential(credential);
                reauthSuccess = true;
                debugPrint(
                    '✅ Successfully re-authenticated Google user before account deletion');
              }
            }
          } else if (info.providerId == 'apple.com') {
            debugPrint(
                '🔄 Attempting Apple re-authentication before account deletion...');
            final rawNonce = _generateNonce();
            final hashedNonce = _sha256ofString(rawNonce);
            final appleCredential = await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
              nonce: hashedNonce,
            );
            final oauthCredential = OAuthProvider('apple.com').credential(
              idToken: appleCredential.identityToken,
              rawNonce: rawNonce,
            );
            await user.reauthenticateWithCredential(oauthCredential);
            reauthSuccess = true;
            debugPrint(
                '✅ Successfully re-authenticated Apple user before account deletion');
          }
        }
      } catch (e) {
        debugPrint(
            '⚠️ Pre-deletion re-authentication failed or was cancelled: $e');
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          throw AuthException(
            AuthErrorCodes.requiresRecentLogin,
            technicalMessage: 'Re-authentication required: ${e.message}',
          );
        }
      }

      // Check token freshness before proceeding to wipe Firestore data.
      // In Firebase Auth, delete() requires authentication within ~5 minutes.
      // If the session is older and re-auth did not succeed, aborting NOW prevents
      // partial deletion where Firestore chats/profile are wiped but user.delete() fails!
      final lastSignIn = user.metadata.lastSignInTime;
      if (!reauthSuccess &&
          lastSignIn != null &&
          DateTime.now().difference(lastSignIn).inMinutes >= 4) {
        debugPrint(
            '❌ Aborting account deletion: session is older than 4 minutes and re-auth did not complete.');
        throw const AuthException(
          AuthErrorCodes.requiresRecentLogin,
          technicalMessage:
              'Session token is too old for sensitive deletion operation.',
        );
      }

      // ── CRITICAL SEQUENCING NOTE ON FIRE-AND-FORGET VS AWAIT ─────────────
      // We MUST NOT use fire-and-forget (unawaited) for Firestore deletions!
      // Once step 4 (`user.delete()`) executes, the Firebase Auth token is
      // destroyed immediately. If Firestore deletion queries were running in the
      // background, they would instantly lose authentication and fail with
      // `permission-denied` (since security rules check `request.auth.uid == uid`).
      // Therefore, all remote database deletions MUST be awaited sequentially
      // BEFORE deleting the Firebase Auth user account.
      //
      // Furthermore, each step is wrapped in an isolated try-catch block so that
      // a failure in one (e.g., timeout or missing doc) does not abort the entire
      // account deletion chain.

      // 1. Delete remote conversations and message subcollections from Firestore
      try {
        await RemoteChatStore.instance.deleteAllConversationsRemote(uid: uid);
        debugPrint('🗑️ Deleted Firestore conversations for uid=$uid');
      } catch (e) {
        debugPrint('⚠️ Error deleting Firestore conversations: $e');
      }

      // 2. Delete user profile doc from Firestore
      try {
        await _firestore.doc(FirebaseCollections.userDoc(uid)).delete();
        debugPrint('🗑️ Deleted Firestore user doc for uid=$uid');
      } catch (e) {
        debugPrint('⚠️ Error deleting Firestore user doc: $e');
      }

      // 3. Delete stored API keys from Firestore
      for (final provider in AiProviderId.values) {
        try {
          await _firestore
              .doc(FirebaseCollections.apiKeyDoc(uid, provider.id))
              .delete();
        } catch (_) {}
      }

      // 4. Delete user from Firebase Auth
      await user.delete();
      debugPrint('🗑️ Deleted Firebase Auth user');

      // 5. Disconnect Google Sign In if signed in with Google
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      // 6. Clear local preferences and onboarding status
      _storage.clearUserData();
      _storage.setBool(StorageKeys.isLoggedIn, false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '⚠️ AuthRepositoryImpl deleteAccount FirebaseAuth error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        throw AuthException(
          AuthErrorCodes.requiresRecentLogin,
          technicalMessage:
              'FirebaseAuthException: requires-recent-login — ${e.message}',
        );
      }
      return false;
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ AuthRepositoryImpl deleteAccount error: $e');
      return false;
    }
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
      DateTime? createdAt;
      DateTime? lastLoginAt;
      DateTime? lastUpdatedAt;
      int? age;
      DateTime? dateOfBirth;
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
        await docRef.set(newUser.toFirestoreNewUser());
        debugPrint(
            "⚠️ AuthRepositoryImpl: User data set to firestore successfully");
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
        age = existingData[FirebaseCollections.fieldAge] as int?;
        dateOfBirth =
            (existingData[FirebaseCollections.fieldDateOfBirth] as Timestamp?)
                ?.toDate();
        createdAt =
            (existingData[FirebaseCollections.fieldCreatedAt] as Timestamp?)
                ?.toDate();
        lastLoginAt =
            (existingData[FirebaseCollections.fieldLastLoginAt] as Timestamp?)
                ?.toDate();
        lastUpdatedAt =
            (existingData[FirebaseCollections.fieldLastUpdatedAt] as Timestamp?)
                ?.toDate();

        // Update only lastLoginAt — preserve all other fields
        await docRef.update({
          FirebaseCollections.fieldLastLoginAt: FieldValue.serverTimestamp(),
          FirebaseCollections.fieldNewUser: false
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
          dateOfBirth: dateOfBirth,
          createdAt: createdAt,
          lastLoginAt: lastLoginAt,
          age: age,
          lastUpdatedAt: lastUpdatedAt,
        );

        debugPrint(
            "⚠️ AuthRepositoryImpl: User data get from firestore successfully");

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
      debugPrint(
          "⚠️ AuthRepository: updateUser $uid \n with update field data -> $field : $value");
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
    DateTime? dateOfBirth,
    int? age,
    File? photoFile,
  }) async {
    final resolvedDisplayName = displayName.trim();
    String resolvedPhotoUrl = photoUrl.trim();

    if (currentUser.uid.isEmpty || resolvedDisplayName.isEmpty) {
      return false;
    }

    try {
      final authUser = _firebaseAuth.currentUser;
      final uid = authUser?.uid ?? currentUser.uid;

      // ── PHOTO HANDLING (Local + Firestore Base64) ──────────────────────────
      if (photoFile != null) {
        // 1. Store locally for fast access on this device
        final appDir = await getApplicationDocumentsDirectory();
        final localFile = File('${appDir.path}/profile_avatar.jpg');
        debugPrint('📸 Saving local profile image to: ${localFile.path}');
        await photoFile.copy(localFile.path);

        // 2. Convert to Base64 for Firestore syncing (no Storage available)
        final bytes = await photoFile.readAsBytes();
        debugPrint('📸 Photo size: ${bytes.length} bytes');
        final base64String = base64Encode(bytes);
        resolvedPhotoUrl = 'data:image/jpeg;base64,$base64String';
        debugPrint('📸 Base64 string length: ${resolvedPhotoUrl.length}');
      }

      await _firestore.doc(FirebaseCollections.userDoc(uid)).update({
        FirebaseCollections.fieldDisplayName: resolvedDisplayName,
        FirebaseCollections.fieldPhotoUrl: resolvedPhotoUrl,
        FirebaseCollections.fieldDateOfBirth:
            dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
        FirebaseCollections.fieldAge: age,
        FirebaseCollections.fieldLastUpdatedAt: FieldValue.serverTimestamp(),
      });

      if (authUser != null) {
        // Firebase Auth photoURL has a length limit, so we might not be able
        // to store large Base64 strings there. We'll prioritize Firestore.
        try {
          EffectBus.instance.safeEffect(() async {
            await authUser.updateDisplayName(resolvedDisplayName);
            await authUser.updatePhotoURL(
              resolvedPhotoUrl.startsWith('data:') ? null : resolvedPhotoUrl,
            );
          });
        } catch (_) {}
      }

      final updatedUser = currentUser.copyWith(
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
        dateOfBirth: dateOfBirth,
        age: age,
      );

      _persistSession(updatedUser);
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
