import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';
import 'remote_user_dao.dart';
import 'user_dto.dart';
import '../../../../core/enums/app_enums.dart';
import '../../chat/data/remote_chat_store.dart';
import '../../usage/data/usage_repository_impl.dart';

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
  final RemoteUserDao _userDao;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    StorageService? storage,
    RemoteUserDao? userDao,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseCollections.firestore,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _storage = storage ?? StorageService(),
        _userDao = userDao ??
            RemoteUserDaoImpl(
                firestore: firestore ?? FirebaseCollections.firestore);

  // ── Apple Sign-In Availability (disabled pending Apple Developer account) ─

  // @override
  // bool get isAppleSignInAvailable => Platform.isIOS;

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

      final isNewUserFromAuth =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      // Create or update Firestore document and return normalized UserModel
      try {
        final user = await _createOrUpdateUser(
          firebaseUser: firebaseUser,
          provider: SocialAuthProvider.google,
          isNewUserFromAuth: isNewUserFromAuth,
        );
        return user;
      } catch (e) {
        // Rollback: If profile creation fails, sign out from Firebase Auth so
        // the client is not left in a half-authenticated state with no Firestore doc.
        await _firebaseAuth.signOut().catchError((_) {});
        rethrow;
      }
    } on AuthException {
      // Re-throw our typed exceptions as-is
      rethrow;
    } on SocketException {
      throw const AuthException(AuthErrorCodes.noInternet);
    } on TimeoutException {
      throw const AuthException(AuthErrorCodes.noInternet);
    } on PlatformException catch (e) {
      // Google Sign-In throws PlatformException on native dialog cancellation or network failure
      if (e.code == 'sign_in_canceled' || e.code == '12501') {
        // User cancelled native Google account picker — return null silently
        return null;
      } else if (e.code == 'network_error' || e.code == '7') {
        throw const AuthException(AuthErrorCodes.noInternet);
      }
      throw AuthException(
        AuthErrorCodes.signInFailed,
        technicalMessage: 'PlatformException: ${e.code} — ${e.message}',
      );
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

  // ── Apple Sign-In (disabled pending Apple Developer account) ───────────────

  // @override
  // Future<UserModel?> signInWithApple() async {
  //   try {
  //     final rawNonce = _generateNonce();
  //     final hashedNonce = _sha256ofString(rawNonce);
  //     AuthorizationCredentialAppleID appleCredential;
  //     try {
  //       appleCredential = await SignInWithApple.getAppleIDCredential(
  //         scopes: [
  //           AppleIDAuthorizationScopes.email,
  //           AppleIDAuthorizationScopes.fullName,
  //         ],
  //         nonce: hashedNonce,
  //       );
  //     } on SignInWithAppleAuthorizationException catch (e) {
  //       if (e.code == AuthorizationErrorCode.canceled) return null;
  //       throw AuthException(
  //         AuthErrorCodes.signInFailed,
  //         technicalMessage:
  //             'Apple authorization error: ${e.code} — ${e.message}',
  //       );
  //     }
  //     final oauthCredential = OAuthProvider('apple.com').credential(
  //       idToken: appleCredential.identityToken,
  //       rawNonce: rawNonce,
  //     );
  //     final userCredential =
  //         await _firebaseAuth.signInWithCredential(oauthCredential);
  //     final firebaseUser = userCredential.user;
  //     if (firebaseUser == null) {
  //       throw const AuthException(
  //         AuthErrorCodes.signInFailed,
  //         technicalMessage: 'Firebase user was null after Apple sign-in',
  //       );
  //     }
  //     final appleGivenName = appleCredential.givenName;
  //     final appleEmail = appleCredential.email;
  //     return await _createOrUpdateUser(
  //       firebaseUser: firebaseUser,
  //       provider: SocialAuthProvider.apple,
  //       appleGivenName: appleGivenName,
  //       appleEmail: appleEmail,
  //     );
  //   } on AuthException {
  //     rethrow;
  //   } on SocketException {
  //     throw const AuthException(AuthErrorCodes.noInternet);
  //   } on FirebaseAuthException catch (e) {
  //     throw AuthException(
  //       _mapFirebaseAuthError(e.code),
  //       technicalMessage: 'FirebaseAuthException: ${e.code} — ${e.message}',
  //     );
  //   } catch (e) {
  //     throw AuthException(
  //       AuthErrorCodes.unknown,
  //       technicalMessage: 'Unexpected Apple sign-in error: $e',
  //     );
  //   }
  // }

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
      // Fetch Firestore user profile via DAO
      final user = await _userDao.getUser(firebaseUser.uid);

      if (user == null) {
        // If the Firestore document does not exist, the account was deleted
        // (e.g. on another device). Do NOT recreate the user document! Sign out and return null.
        debugPrint(
          '⚠️ AuthRepository: Firestore doc missing for Firebase user '
          '${firebaseUser.uid} (likely deleted on another device). Signing out.',
        );
        await signOut();
        return null;
      }

      return user;
    } catch (e) {
      debugPrint('⚠️ AuthRepository: getCurrentUser Firestore error — $e');
      return null;
    }
  }

  @override
  Stream<UserModel?> get authStateChanges =>
      _firebaseAuth.userChanges().map((user) {
        if (user == null) return null;
        SocialAuthProvider provider = SocialAuthProvider.google;
        if (user.providerData.isNotEmpty) {
          final pId = user.providerData.first.providerId.toLowerCase();
          if (pId.contains('apple')) {
            provider = SocialAuthProvider.apple;
          } else if (pId.contains('google')) {
            provider = SocialAuthProvider.google;
          }
        }
        return UserModel(
          uid: user.uid,
          authProvider: provider,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          photoUrl: user.photoURL ?? '',
        );
      });

  @override
  Stream<bool> watchUserExists(String uid) {
    return _userDao.watchUserExists(uid);
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
        throw AuthException(
          AuthErrorCodes.sessionExpired,
          technicalMessage: e.code,
        );
      }
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    // 1. Sign out from Google Sign-In (clears cached Google account)
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('⚠️ AuthRepository: Google signOut error (ignored): $e');
    }

    // 2. Sign out from Firebase Auth
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ AuthRepository: Firebase signOut error — ${e.code}');
      throw AuthException(
        AuthErrorCodes.signOutFailed,
        technicalMessage: e.message,
      );
    } catch (e) {
      debugPrint('⚠️ AuthRepository: Firebase signOut error — $e');
      throw AuthException(
        AuthErrorCodes.signOutFailed,
        technicalMessage: e.toString(),
      );
    }

    // 3. Clear all local session data
    try {
      await _storage.clearUserData();
      await _storage.setBool(StorageKeys.isLoggedIn, false);
    } catch (e) {
      debugPrint('⚠️ AuthRepository: Storage clear error (ignored): $e');
    }
    debugPrint('⚠️ AuthRepositoryImpl: User signed out successfully');
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
            // Apple re-authentication is temporarily disabled pending Apple Developer account setup
            // } else if (info.providerId == 'apple.com') {
            //   debugPrint(
            //       '🔄 Attempting Apple re-authentication before account deletion...');
            //   final rawNonce = _generateNonce();
            //   final hashedNonce = _sha256ofString(rawNonce);
            //   final appleCredential = await SignInWithApple.getAppleIDCredential(
            //     scopes: [
            //       AppleIDAuthorizationScopes.email,
            //       AppleIDAuthorizationScopes.fullName,
            //     ],
            //     nonce: hashedNonce,
            //   );
            //   final oauthCredential = OAuthProvider('apple.com').credential(
            //     idToken: appleCredential.identityToken,
            //     rawNonce: rawNonce,
            //   );
            //   await user.reauthenticateWithCredential(oauthCredential);
            //   reauthSuccess = true;
            //   debugPrint(
            //       '✅ Successfully re-authenticated Apple user before account deletion');
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

      // 2. Delete user usage subcollections (events, summaries, budgets) from Firestore
      try {
        await UsageRepositoryImpl().deleteAllUsageData(uid: uid);
        debugPrint('🗑️ Deleted Firestore usage data for uid=$uid');
      } catch (e) {
        debugPrint('⚠️ Error deleting Firestore usage data: $e');
      }

      // 3. Delete user profile doc from Firestore via DAO
      try {
        await _userDao.deleteUserDoc(uid);
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
      // NOTE: We intentionally do NOT delete the hashed identity in
      // RegisteredAccounts/{emailHash}. This ensures that if the user recreates
      // an account with the same email, they are not treated as a new user again
      // (prevents re-registration credit/benefit farming exploits).
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
      try {
        await _storage.clearUserData();
        await _storage.setBool(StorageKeys.isLoggedIn, false);
      } catch (e) {
        debugPrint(
            '⚠️ AuthRepository: storage clear error during deleteAccount (ignored): $e');
      }
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
      throw AuthException(
        AuthErrorCodes.deleteAccountFailed,
        technicalMessage: e.message,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ AuthRepositoryImpl deleteAccount error: $e');
      throw AuthException(
        AuthErrorCodes.deleteAccountFailed,
        technicalMessage: e.toString(),
      );
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
    bool isNewUserFromAuth = false,
    String? appleGivenName,
    String? appleEmail,
  }) async {
    final uid = firebaseUser.uid;
    final fsStopwatch = Stopwatch()..start();

    try {
      // Resolve display name from OAuth provider
      final resolvedDisplayName = _resolveDisplayName(
        firebaseUser: firebaseUser,
        provider: provider,
        appleGivenName: appleGivenName,
      );

      // Resolve email from OAuth provider
      final resolvedEmail = _resolveEmail(
        firebaseUser: firebaseUser,
        provider: provider,
        appleEmail: appleEmail,
      );

      // Resolve profile photo URL (Google provides photo; Apple does not)
      final resolvedPhotoUrl = provider == SocialAuthProvider.google
          ? (firebaseUser.photoURL ?? '')
          : '';

      DocumentSnapshot<Map<String, dynamic>>? existingDoc;

      // OPTIMIZATION: If Firebase Auth reports a brand-new user (just-minted UID),
      // their Firestore document cannot exist yet. Skip the wasted 1.5s getUserDoc read.
      if (!isNewUserFromAuth) {
        existingDoc = await _userDao.getUserDoc(uid).timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
                message: 'Firestore connection timed out',
              ),
            );
        debugPrint(
            '⏱️ Firestore getUserDoc read completed in: ${fsStopwatch.elapsedMilliseconds}ms (exists: ${existingDoc.exists})');
      } else {
        debugPrint(
            '⚡ Fast-path: isNewUserFromAuth is true, skipping non-existent user doc read.');
      }

      if (existingDoc == null || !existingDoc.exists) {
        // ── NEW OR RE-REGISTERED USER DOCUMENT CREATION ───────────────────────
        final normalizedIdentifier =
            (resolvedEmail.isNotEmpty ? resolvedEmail : uid)
                .toLowerCase()
                .trim();
        final emailHash = _sha256ofString(normalizedIdentifier);
        final registryDocPath =
            FirebaseCollections.registeredAccountDoc(emailHash);
        final registryRef = _firestore.doc(registryDocPath);

        bool hasEverRegistered = false;
        try {
          final registryDoc = await registryRef.get().timeout(
                const Duration(seconds: 15),
              );
          hasEverRegistered = registryDoc.exists;
        } catch (e) {
          debugPrint(
              '⚠️ AuthRepository: RegisteredAccounts check skipped/failed (non-fatal): $e');
        }

        final isNewUser = !hasEverRegistered;

        // Record in permanent registry in background (non-blocking)
        if (!hasEverRegistered) {
          unawaited(registryRef.set({
            FirebaseCollections.fieldRegisteredAt: FieldValue.serverTimestamp(),
            FirebaseCollections.fieldRegisteredProvider: provider.id,
            FirebaseCollections.fieldRegisteredUid: uid,
          }).catchError((e) {
            debugPrint(
                '⚠️ AuthRepository: Failed to record email hash in registry (non-fatal): $e');
          }));
        }

        // Build the user model for the new document
        final newUser = UserModel(
          uid: uid,
          authProvider: provider,
          email: resolvedEmail,
          displayName: resolvedDisplayName,
          photoUrl: resolvedPhotoUrl,
          isNewUser: isNewUser,
          onboardingDone: false,
          keySetupDone: false,
          termsAccepted: true,
          termsAcceptedAt: DateTime.now().toUtc(),
          termsVersionAccepted: AppConstants.currentTermsVersion,
          createdAt: DateTime.now().toUtc(),
        );

        // Write new user document to Firestore via DAO — CRITICAL: AWAITED before navigation
        await _userDao.createUser(newUser).timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
                message: 'Firestore connection timed out',
              ),
            );
        debugPrint(
            "⚠️ AuthRepositoryImpl: User data set to firestore successfully in ${fsStopwatch.elapsedMilliseconds}ms (isNewUser: $isNewUser)");

        // Persist session to Hive in the background so it does not delay navigation
        unawaited(_persistSession(newUser).catchError((e) {
          debugPrint(
              '⚠️ AuthRepository: Non-fatal _persistSession Hive error: $e');
        }));

        return newUser;
      } else {
        // ── RETURNING USER ────────────────────────────────────────────────────
        final existingData = existingDoc.data()!;
        final storedUser = UserDto.fromFirestore(existingData);

        final finalDisplayName = storedUser.displayName.isNotEmpty
            ? storedUser.displayName
            : resolvedDisplayName;
        final finalEmail =
            storedUser.email.isNotEmpty ? storedUser.email : resolvedEmail;
        String finalPhotoUrl = storedUser.photoUrl;

        // If photo was missing in Firestore but provided by Google, backfill it in background
        if (finalPhotoUrl.isEmpty && resolvedPhotoUrl.isNotEmpty) {
          finalPhotoUrl = resolvedPhotoUrl;
          unawaited(_userDao
              .updateUserField(
                uid,
                FirebaseCollections.fieldPhotoUrl,
                resolvedPhotoUrl,
              )
              .catchError((_) {}));
        }

        // Update lastLoginAt asynchronously in the background via DAO so it does not delay returning to UI
        unawaited(_userDao.updateLastLogin(uid).catchError((e) {
          debugPrint('⚠️ Non-fatal lastLoginAt update error: $e');
        }));

        final returningUser = storedUser.copyWith(
          displayName: finalDisplayName,
          email: finalEmail,
          photoUrl: finalPhotoUrl,
          authProvider: provider,
          isNewUser: false,
        );

        debugPrint(
            "⚠️ AuthRepositoryImpl: Returning user profile processed in ${fsStopwatch.elapsedMilliseconds}ms");

        // Persist session to Hive in the background so it does not delay navigation
        unawaited(_persistSession(returningUser).catchError((e) {
          debugPrint(
              '⚠️ AuthRepository: Non-fatal _persistSession Hive error: $e');
        }));

        return returningUser;
      }
    } on FirebaseException catch (e) {
      debugPrint(
        '❌ AuthRepository: Firestore operation failed — ${e.code}: ${e.message}',
      );
      throw AuthException(
        _mapFirestoreError(e.code),
        technicalMessage: e.message ?? 'Firestore operation failed',
      );
    } on TimeoutException catch (e) {
      debugPrint('❌ AuthRepository: Firestore operation timed out — $e');
      throw const AuthException(
        AuthErrorCodes.noInternet,
        technicalMessage: 'Firestore operation timed out',
      );
    } catch (e) {
      debugPrint(
          '❌ AuthRepository unexpected sign-in error in _createOrUpdateUser: $e');
      throw AuthException(
        AuthErrorCodes.unknown,
        technicalMessage: 'Unexpected error in _createOrUpdateUser: $e',
      );
    }
  }

  // ── Private: Persist Session to Hive ──────────────────────────────────────

  /// Write all session-related keys to Hive for fast startup reads.
  Future<void> _persistSession(UserModel user) async {
    try {
      await Future.wait([
        _storage.setBool(StorageKeys.isLoggedIn, true),
        _storage.setBool(StorageKeys.onboardingCompleted, user.onboardingDone),
        _storage.setBool(StorageKeys.keySetupCompleted, user.keySetupDone),
        _storage.setBool(StorageKeys.termsAccepted, user.termsAccepted),
        _storage.setUserData(StorageKeys.userId, user.uid),
        _storage.setUserData(StorageKeys.userEmail, user.email),
        _storage.setUserData(StorageKeys.userDisplayName, user.displayName),
        _storage.setUserData(StorageKeys.userPhotoUrl, user.photoUrl),
        if (user.termsVersionAccepted != null)
          _storage.setUserData(
            StorageKeys.termsVersionAccepted,
            user.termsVersionAccepted!,
          ),
      ]);
    } catch (e) {
      debugPrint('⚠️ AuthRepository: Non-fatal _persistSession Hive error: $e');
    }
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

  // ── Private: Firebase Error Mapping ───────────────────────────────────────

  /// Map Firebase Auth error codes to AppLocalizations keys.
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-disabled':
        return AuthErrorCodes.userDisabled;
      case 'user-not-found':
        return AuthErrorCodes.userNotFound;
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'wrong-password':
        return AuthErrorCodes.invalidCredential;
      case 'account-exists-with-different-credential':
        return AuthErrorCodes.accountExistsDifferentCredential;
      case 'too-many-requests':
        return AuthErrorCodes.tooManyRequests;
      case 'operation-not-allowed':
        return AuthErrorCodes.operationNotAllowed;
      case 'network-request-failed':
        return AuthErrorCodes.noInternet;
      case 'requires-recent-login':
        return AuthErrorCodes.requiresRecentLogin;
      default:
        return AuthErrorCodes.signInFailed;
    }
  }

  /// Map Firestore error codes to AppLocalizations keys.
  String _mapFirestoreError(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AuthErrorCodes.noInternet;
      case 'permission-denied':
        return AuthErrorCodes.operationNotAllowed;
      default:
        return AuthErrorCodes.firestoreWriteFailed;
    }
  }

  // ── Private: Nonce Generation for Apple Sign-In (disabled) ───────────────

  // String _generateNonce([int length = 32]) {
  //   const charset =
  //       '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  //   final random = Random.secure();
  //   return List.generate(
  //     length,
  //     (_) => charset[random.nextInt(charset.length)],
  //   ).join();
  // }

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
      // Update field in Firestore via DAO
      await _userDao.updateUserField(uid, field, value);

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
    required String email,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? country,
    String? state,
    File? photoFile,
  }) async {
    final resolvedDisplayName = displayName.trim();
    String resolvedPhotoUrl = photoUrl.trim();
    final resolvedEmail = email.trim();

    if (currentUser.uid.isEmpty ||
        resolvedDisplayName.isEmpty ||
        resolvedEmail.isEmpty) {
      return false;
    }

    try {
      final authUser = _firebaseAuth.currentUser;
      final uid = authUser?.uid ?? currentUser.uid;

      // 1. Process photo in-memory (DO NOT copy to local file yet!)
      if (photoFile != null) {
        final bytes = await photoFile.readAsBytes();
        final base64String = base64Encode(bytes);
        resolvedPhotoUrl = 'data:image/jpeg;base64,$base64String';
      } else if (resolvedPhotoUrl.isEmpty) {
        resolvedPhotoUrl = currentUser.photoUrl.isNotEmpty
            ? currentUser.photoUrl
            : (authUser?.photoURL ?? '');
      }

      // 2. Prepare Firestore update map
      final updateMap = UserDto.toProfileUpdateMap(
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
        email: resolvedEmail,
        dateOfBirth: dateOfBirth,
        age: age,
        gender: gender,
        country: country,
        state: state,
      );

      // 3. REMOTE FIRST: Write to Firestore with timeout.
      // If network fails or times out, execution halts here and jumps to catch.
      // Local database and local cache file are NOT updated!
      await _userDao.updateProfile(uid, updateMap).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'Profile update timed out',
            ),
          );

      // 4. REMOTE SUCCEEDED — Safe to cache local avatar file
      if (photoFile != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final localFile = File('${appDir.path}/profile_avatar.jpg');
          await photoFile.copy(localFile.path);
        } catch (e) {
          debugPrint('⚠️ Non-fatal local avatar cache copy error: $e');
        }
      }

      // 5. Update Firebase Auth user (displayName and photo if standard URL)
      if (authUser != null) {
        try {
          EffectBus.instance.safeEffect(() async {
            if (authUser.displayName != resolvedDisplayName) {
              await authUser.updateDisplayName(resolvedDisplayName);
            }
            if (!resolvedPhotoUrl.startsWith('data:') &&
                authUser.photoURL != resolvedPhotoUrl) {
              await authUser.updatePhotoURL(resolvedPhotoUrl);
            }
          });
        } catch (_) {}
      }

      // 6. ONLY on verified remote success, update local database (Hive)
      final updatedUser = currentUser.copyWith(
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
        email: resolvedEmail,
        dateOfBirth: dateOfBirth,
        age: age,
        gender: gender,
        country: country,
        state: state,
      );

      await _persistSession(updatedUser);
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        '⚠️ AuthRepository: updateProfile Firestore failed — '
        '${e.code}: ${e.message}',
      );
      throw AuthException(
        _mapFirestoreError(e.code),
        technicalMessage: e.message ?? 'Firestore update failed',
      );
    } on TimeoutException {
      debugPrint('❌ AuthRepository: updateProfile timed out');
      throw const AuthException(
        AuthErrorCodes.noInternet,
        technicalMessage: 'Profile update timed out',
      );
    } on SocketException {
      throw const AuthException(AuthErrorCodes.noInternet);
    } catch (e) {
      debugPrint('❌ AuthRepository: updateProfile error: $e');
      throw AuthException(
        AuthErrorCodes.unknown,
        technicalMessage: e.toString(),
      );
    }
  }
}
