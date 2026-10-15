import 'dart:async';
import 'dart:io';

import 'package:ai_voice_genie/core/constants/firebase_collections.dart';
import 'package:ai_voice_genie/core/constants/storage_keys.dart';
import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:flutter/material.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../features/chat/data/chat_sync_service.dart';
import '../../../features/chat/presentation/chat_provider.dart';
import '../../../features/usage/presentation/usage_provider.dart';
import '../../../features/voice_speech/presentation/voice_speech_provider.dart';
import '../../key_setup/data/api_key_repository_impl.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';
import '../data/auth_repository_impl.dart';

/// Authentication state provider for AI Voice Genie.
///
/// Single source of truth for auth state.
/// SplashScreen observes [authState] to decide where to navigate.
/// LoginScreen observes [authError] to show error messages.
///
/// Initialized with lazy: false in main.dart so auth state is resolved
/// before SplashScreen finishes its minimum display duration.
///
/// Usage:
/// ```dart
/// // In main.dart providers list:
/// ChangeNotifierProvider(
///   create: (_) => AuthProvider()..initialize(),
///   lazy: false,
/// )
///
/// // In SplashScreen:
/// context.watch<AuthProvider>().authState
///
/// // In LoginScreen:
/// context.read<AuthProvider>().signInWithGoogle()
/// ```
class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthRepository _repository;
  final AnalyticsService _analytics;
  final StorageService _storage;

  AuthProvider({
    AuthRepository? repository,
    AnalyticsService? analytics,
    StorageService? storage,
  })  : _repository = repository ?? AuthRepositoryImpl(),
        _analytics = analytics ?? AnalyticsService.instance,
        _storage = storage ?? StorageService() {
    WidgetsBinding.instance.addObserver(this);
    _initAuthStateListener();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  AuthState _authState = AuthState.initial;
  UserModel? _currentUser;
  String? _authError;
  final EffectBus _effectBus = EffectBus.instance;
  StreamSubscription<UserModel?>? _authStateSub;
  StreamSubscription<bool>? _userExistsSub;
  String? _watchedUid;
  bool _isLocalSignOutOrDelete = false;
  bool _isHandlingRemoteTermination = false;

  /// Current authentication state — drives SplashScreen navigation.
  AuthState get authState => _authState;

  /// Currently signed-in user. Null if unauthenticated.
  UserModel? get currentUser => _currentUser;

  /// Localization key for the last auth error.
  /// Null when no error. Reset to null after being consumed by UI.
  String? get authError => _authError;

  // Apple Sign-In availability getter — disabled pending Apple Developer account setup
  // bool get isAppleSignInAvailable => _repository.isAppleSignInAvailable;

  /// Convenience getter — true if a user is signed in.
  bool get isAuthenticated => _authState == AuthState.authenticated;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Check for an existing Firebase session on app start.
  ///
  /// Called immediately via ..initialize() in main.dart providers.
  /// Sets authState to authenticated or unauthenticated.
  /// SplashScreen waits for this to complete before navigating.
  Future<void> initialize() async {
    // Capture login status and user ID before network verification or potential sign-out
    bool wasLoggedInOnLaunch = false;
    String? staleUid;
    try {
      wasLoggedInOnLaunch = _storage.getBool(StorageKeys.isLoggedIn);
      staleUid = _storage.getUserData<String>(StorageKeys.userId);
    } catch (_) {}

    UserModel? user;
    try {
      user = await _repository.getCurrentUser();
    } on AuthException catch (e) {
      debugPrint('⚠️ AuthProvider initialize AuthException: ${e.code}');
    } catch (e) {
      debugPrint('⚠️ AuthProvider initialize error: $e');
    } finally {
      _currentUser = user;
      if (user != null) {
        _analytics.setUserId(user.uid);
        _setAuthState(AuthState.authenticated);

        // Run chat sync in the background so it never blocks splash screen or app initialization
        unawaited(ChatSyncService.instance.start(user.uid).catchError((e) {
          debugPrint('⚠️ ChatSyncService background start error: $e');
        }));
      } else {
        await _handleExpiredSessionIfNeeded(
          wasLoggedIn: wasLoggedInOnLaunch,
          staleUid: staleUid,
        );
        _setAuthState(AuthState.unauthenticated);
      }
    }
  }

  bool _isSessionExpired = false;

  /// Whether the previous session expired or was terminated remotely.
  bool get isSessionExpired => _isSessionExpired;

  /// Consumes the session expired flag, returning true once and resetting to false.
  bool consumeSessionExpired() {
    if (_isSessionExpired) {
      _isSessionExpired = false;
      return true;
    }
    return false;
  }

  /// Cleans up local user data and alerts the user if a previous session was active but is now invalid.
  Future<void> _handleExpiredSessionIfNeeded({
    required bool wasLoggedIn,
    String? staleUid,
  }) async {
    if (wasLoggedIn) {
      debugPrint(
          '⚠️ AuthProvider: Expired or remote-terminated session detected on launch. Flagging isSessionExpired.');
      // Flag session as expired so LoginScreen can present the warning when it mounts
      _isSessionExpired = true;
      if (staleUid != null && staleUid.isNotEmpty) {
        try {
          await _storage.clearChatBoxes(staleUid);
        } catch (_) {}
      }
      try {
        await _storage.clearUserData();
        await _storage.setBool(StorageKeys.isLoggedIn, false);
      } catch (_) {}
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Sign in with Google.
  ///
  /// Returns true on success, false on cancellation.
  /// Sets authError on failure — UI observes and shows it.
  Future<void> signInWithGoogle() async {
    // Fire analytics BEFORE auth — tracks button taps independently of outcome
    // _effectBus.safeEffect(() async {
    //   _analytics.authenticationButtonTapped(SocialAuthProvider.google);
    // });
    await _performSignIn(
      () => _repository.signInWithGoogle(),
      provider: SocialAuthProvider.google,
    );
  }

  // ── Apple Sign-In (disabled pending Apple Developer account) ───────────────

  // Future<bool> signInWithApple() async {
  //   await _analytics.authenticationButtonTapped(SocialAuthProvider.apple);
  //   debugPrint('⚠️ AuthProvider performing signInWithApple');
  //   return _performSignIn(
  //     () => _repository.signInWithApple(),
  //     provider: SocialAuthProvider.apple,
  //   );
  // }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  /// Sign out the current user.
  ///
  /// Clears all session data and sets state to unauthenticated only on success.
  /// Returns [true] if sign-out succeeded, [false] otherwise.
  Future<bool> signOut() async {
    _isLocalSignOutOrDelete = true;
    _authError = null;
    final signingOutUser = _currentUser;
    final uid = signingOutUser?.uid;

    try {
      // 1. Immediately stop any active voice listening or TTS speech
      try {
        await VoiceProvider.instance?.reset();
      } catch (e) {
        debugPrint('⚠️ VoiceProvider reset error (ignored): $e');
      }

      // 2. Temporarily stop sync so in-flight queries don't hit Firestore
      try {
        await ChatSyncService.instance.stop();
      } catch (e) {
        debugPrint('⚠️ ChatSyncService stop error (ignored): $e');
      }

      // 3. Execute remote sign-out FIRST.
      // If this fails (e.g. platform error / network exception), it will jump
      // straight to catch block WITHOUT deleting local data or firing sign-out analytics!
      await _repository.signOut();

      // 4. Remote sign-out succeeded — now safe to emit analytics
      if (signingOutUser != null) {
        _effectBus.safeEffect(() async {
          await _analytics.logUserSignedOut(signingOutUser);
          await _analytics.clearUserId();
        });
      }

      // 5. Remote sign-out succeeded — now safe to wipe local Hive chat boxes
      if (uid != null) {
        try {
          await _storage.clearChatBoxes(uid);
        } catch (e) {
          debugPrint('⚠️ Clear chat boxes error (ignored): $e');
        }
      }

      // 6. Invalidate in-memory caches and reset providers across the entire app
      _resetAppProvidersAndCaches();

      // 7. Only on full success transition to unauthenticated!
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
      return true;
    } on AuthException catch (e) {
      debugPrint('⚠️ AuthProvider signOut AuthException: ${e.code}');
      _authError = e.code;
      // Signout failed: user remains authenticated. Resume background sync.
      if (uid != null) {
        unawaited(ChatSyncService.instance.start(uid).catchError((_) {}));
      }
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('⚠️ AuthProvider signOut error: $e');
      _authError = AuthErrorCodes.signOutFailed;
      // Signout failed: user remains authenticated. Resume background sync.
      if (uid != null) {
        unawaited(ChatSyncService.instance.start(uid).catchError((_) {}));
      }
      notifyListeners();
      return false;
    } finally {
      _isLocalSignOutOrDelete = false;
    }
  }

  // ── Delete Account ─────────────────────────────────────────────────────────

  /// Delete the current user's account and clear all session data.
  ///
  /// This orchestrates the termination of background sync, delegates remote
  /// deletion to the repository, logs analytics, and wipes local Hive caches.
  /// Returns [true] if deletion succeeded, [false] otherwise.
  Future<bool> deleteAccount() async {
    _isLocalSignOutOrDelete = true;
    _authError = null;
    final deletingUser = _currentUser;
    final uid = deletingUser?.uid;

    try {
      debugPrint('⚠️ AuthProvider Deleting Account');

      // 1. Immediately stop any active voice listening or TTS speech
      try {
        await VoiceProvider.instance?.reset();
      } catch (e) {
        debugPrint('⚠️ VoiceProvider reset error (ignored): $e');
      }

      // 2. Stop sync BEFORE clearing local data or deleting credentials so that
      // background workers do not attempt new Firestore reads/writes mid-deletion.
      try {
        await ChatSyncService.instance.stop();
      } catch (e) {
        debugPrint('⚠️ ChatSyncService stop error (ignored): $e');
      }

      // 3. Execute remote deletion (conversations, profile doc, API keys, auth account).
      // If any critical step fails (e.g. requires-recent-login), we abort and return false
      // so the user remains on the profile screen with an error message instead of navigating away.
      final success = await _repository.deleteAccount();
      if (!success) {
        _authError ??= AuthErrorCodes.deleteAccountFailed;
        if (uid != null) {
          unawaited(ChatSyncService.instance.start(uid).catchError((_) {}));
        }
        notifyListeners();
        return false;
      }

      // 4. Log deletion event and clear analytics tracking IDs in the background.
      // Correct order: log account deleted FIRST, then clear the user ID.
      if (deletingUser != null) {
        _effectBus.safeEffect(() async {
          await _analytics.logAccountDeleted(deletingUser);
          await _analytics.clearUserId();
        });
      }

      // 5. Wipe local Hive chat boxes
      if (uid != null) {
        try {
          await _storage.clearChatBoxes(uid);
        } catch (e) {
          debugPrint('⚠️ Storage clearChatBoxes error (ignored): $e');
        }
      }

      // 6. Invalidate in-memory caches and reset all providers across the app
      _resetAppProvidersAndCaches();

      // Only on full success transition to unauthenticated!
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
      return true;
    } on AuthException catch (e) {
      debugPrint('⚠️ AuthProvider deleteAccount AuthException: ${e.code}');
      _authError = e.code;
      if (uid != null) {
        unawaited(ChatSyncService.instance.start(uid).catchError((_) {}));
      }
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('⚠️ AuthProvider deleteAccount error: $e');
      _authError = AuthErrorCodes.deleteAccountFailed;
      if (uid != null) {
        unawaited(ChatSyncService.instance.start(uid).catchError((_) {}));
      }
      notifyListeners();
      return false;
    } finally {
      _isLocalSignOutOrDelete = false;
    }
  }

  // ── Profile Update ─────────────────────────────────────────────────────────

  /// Update profile fields and refresh the in-memory user model.
  Future<bool> updateProfile({
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
    final user = _currentUser;
    final resolvedDisplayName = displayName.trim();
    final resolvedPhotoUrl = photoUrl.trim();
    final resolvedEmail = email.trim();

    if (user == null ||
        resolvedDisplayName.isEmpty ||
        resolvedEmail.isEmpty) {
      return false;
    }

    try {
      final success = await _repository.updateProfile(
        user,
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
        email: resolvedEmail,
        dateOfBirth: dateOfBirth,
        age: age,
        gender: gender,
        country: country,
        state: state,
        photoFile: photoFile,
      );

      if (!success) return false;

      // Re-fetch the user from repository to get the updated photoUrl (Base64)
      // and other server-calculated fields if any.
      final updatedUser = await _repository.getCurrentUser();
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
      }

      return true;
    } on AuthException catch (e) {
      debugPrint('❌ AuthProvider.updateProfile AuthException: ${e.code}');
      _authError = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ AuthProvider.updateProfile error: $e');
      _authError = AuthErrorCodes.unknown;
      notifyListeners();
      return false;
    }
  }

  // ── Error Consumption ──────────────────────────────────────────────────────

  /// Consume and clear the current auth error.
  ///
  /// Called by LoginScreen after showing the error message so it does
  /// not re-show on the next rebuild.
  void clearAuthError() {
    if (_authError != null) {
      _authError = null;
      notifyListeners();
    }
  }

  // ── Private: Unified Sign-In Flow ─────────────────────────────────────────

  /// Shared sign-in logic for both Google and Apple.
  ///
  /// Handles loading state, error mapping, analytics, and state transitions.
  /// The caller provides the repository method to invoke.
  Future<void> _performSignIn(
    Future<UserModel?> Function() signInMethod, {
    required SocialAuthProvider provider,
  }) async {
    // Clear any previous error before starting
    try {
      _authError = null;
      _setAuthState(AuthState.authenticating);

      final user = await signInMethod();

      // Null means user cancelled — not an error
      if (user == null) {
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      _currentUser = user;
      _setAuthState(AuthState.authenticated);

      // Log analytics asynchronously without blocking or failing auth
      _effectBus.safeEffect(() async {
        _analytics.authenticationButtonTapped(provider, user.uid);
        if (user.isNewUser) {
          await _analytics.logUserRegistered(user);
        } else {
          await _analytics.logUserSignedIn(user);
        }
        await _analytics.setUserId(user.uid);
      });

      // Run background sync in background so sign-in finishes immediately.
      unawaited(ChatSyncService.instance.start(user.uid).catchError((e) {
        debugPrint('⚠️ ChatSyncService start error (ignored): $e');
      }));
    } on AuthException catch (e) {
      // Cancelled is not an error — just return false silently
      if (e.isCancelled) {
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      debugPrint('❌ AuthProvider sign-in failed: ${e.technicalMessage}');

      // Set the error code for UI to display localized message
      _authError = e.code;
      _setAuthState(AuthState.unauthenticated);
    } catch (e) {
      debugPrint('❌ AuthProvider unexpected sign-in error: $e');
      _authError = AuthErrorCodes.unknown;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  // ── Private: State Setter ──────────────────────────────────────────────────

  /// Set auth state and notify listeners only if state actually changed.
  void _setAuthState(AuthState newState) {
    if (_authState == newState) {
      if (newState == AuthState.authenticated &&
          _currentUser != null &&
          _watchedUid != _currentUser!.uid) {
        _startWatchingUserExists(_currentUser!.uid);
      }
      return;
    }
    _authState = newState;
    if (newState == AuthState.authenticated && _currentUser != null) {
      _startWatchingUserExists(_currentUser!.uid);
    } else if (newState == AuthState.unauthenticated) {
      _userExistsSub?.cancel();
      _watchedUid = null;
    }
    notifyListeners();
  }

  void _startWatchingUserExists(String uid) {
    if (_watchedUid == uid && _userExistsSub != null) return;
    _watchedUid = uid;
    _userExistsSub?.cancel();
    bool hasSeenExistingDoc = _currentUser != null && !_currentUser!.isNewUser;
    _userExistsSub = _repository.watchUserExists(uid).listen((exists) async {
      if (exists) {
        hasSeenExistingDoc = true;
      } else if (hasSeenExistingDoc &&
          _authState == AuthState.authenticated &&
          !_isLocalSignOutOrDelete) {
        debugPrint(
            '⚠️ AuthProvider: Remote account deletion detected via Firestore snapshot! Forcefully logging out.');
        await _handleRemoteSessionTermination();
      }
    }, onError: (e) {
      debugPrint(
          '⚠️ AuthProvider watchUserExists stream error (ignored on logout/delete): $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _authState == AuthState.authenticated &&
        !_isLocalSignOutOrDelete) {
      _verifySessionValidityOnResume();
    }
  }

  Future<void> _verifySessionValidityOnResume() async {
    try {
      await _repository.reloadSession();
      // Sync latest profile updates made remotely from another device (e.g. Device B)
      final freshUser = await _repository.getCurrentUser();
      if (freshUser != null) {
        final hasChanged = freshUser.photoUrl != _currentUser?.photoUrl ||
            freshUser.displayName != _currentUser?.displayName ||
            freshUser.email != _currentUser?.email ||
            freshUser.country != _currentUser?.country ||
            freshUser.state != _currentUser?.state ||
            freshUser.gender != _currentUser?.gender ||
            freshUser.age != _currentUser?.age ||
            freshUser.dateOfBirth != _currentUser?.dateOfBirth;
        if (hasChanged) {
          debugPrint(
              '🔄 AuthProvider: Remote profile updates synced on app resume.');
          _currentUser = freshUser;
          notifyListeners();
        }
      }
    } on AuthException catch (e) {
      if (e.code == AuthErrorCodes.sessionExpired ||
          e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired' ||
          e.technicalMessage == 'user-not-found' ||
          e.technicalMessage == 'user-disabled') {
        debugPrint(
            '⚠️ AuthProvider: Remote session termination detected on resume (${e.code} / ${e.technicalMessage})');
        await _handleRemoteSessionTermination();
      }
    } catch (_) {}
  }

  // Updating: Fields Value

  /// Set onboarding complete and notify listeners.

  Future<void> markBoardingComplete() async {
    if (currentUser == null) {
      return;
    }

    try {
      // Update the in-memory UserModel so _navigateAfterAuth (and SplashScreen)
      // read the correct value without fetching from Firestore again
      _currentUser = _currentUser?.copyWith(onboardingDone: true);

      _effectBus.safeEffect(() async {
        _repository.updateUser(_currentUser,
            field: FirebaseCollections.fieldOnboardingDone,
            value: currentUser?.onboardingDone ?? false);
      });
    } catch (e) {
      debugPrint('❌ AuthProvider onboarding error: $e');
      _authError = 'something_went_wrong';
    }
  }

  // ── Remote Session Termination Handler ──────────────────────────────────────

  void _initAuthStateListener() {
    _authStateSub = _repository.authStateChanges.listen((user) async {
      // If Firebase explicitly reports user is null while we are authenticated
      // AND we did NOT trigger a local signOut or deleteAccount,
      // it means the session was terminated remotely (e.g., account deleted on another device).
      if (user == null &&
          _authState == AuthState.authenticated &&
          !_isLocalSignOutOrDelete) {
        debugPrint(
            '⚠️ AuthProvider: Remote session termination detected (e.g. account deleted on another device)');
        await _handleRemoteSessionTermination();
      }
    });
  }

  /// Centralized in-memory cache and provider reset across the app
  void _resetAppProvidersAndCaches() {
    try {
      ApiKeyRepositoryImpl.clearMemoryCache();
      ApiKeyProvider.instance?.reset();
    } catch (e) {
      debugPrint('⚠️ ApiKeyProvider reset error (ignored): $e');
    }

    try {
      UsageProvider.instance?.clear();
    } catch (e) {
      debugPrint('⚠️ UsageProvider clear error (ignored): $e');
    }

    try {
      ChatProvider.instance?.resetSession();
    } catch (e) {
      debugPrint('⚠️ ChatProvider resetSession error (ignored): $e');
    }
  }

  Future<void> _handleRemoteSessionTermination() async {
    if (_isHandlingRemoteTermination) return;
    _isHandlingRemoteTermination = true;

    try {
      _userExistsSub?.cancel();
      _watchedUid = null;
      final uid = _currentUser?.uid;

      try {
        await VoiceProvider.instance?.reset();
      } catch (_) {}

      try {
        await ChatSyncService.instance.stop();
      } catch (_) {}

      try {
        await _repository.signOut();
      } catch (_) {}

      if (uid != null) {
        try {
          await _storage.clearChatBoxes(uid);
        } catch (_) {}
      }

      _resetAppProvidersAndCaches();

      _isSessionExpired = true;
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);

      // Clear navigation backstack and redirect to login screen
      final navContext = AppRoutes.navigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        AppRoutes.navigateAndRemoveUntil(navContext, AppRoutes.login);
      } else {
        AppRoutes.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    } finally {
      _isHandlingRemoteTermination = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userExistsSub?.cancel();
    _authStateSub?.cancel();
    _watchedUid = null;
    super.dispose();
  }
}
