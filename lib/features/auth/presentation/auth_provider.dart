import 'dart:async';
import 'dart:io';

import 'package:ai_voice_genie/core/constants/firebase_collections.dart';
import 'package:ai_voice_genie/core/constants/storage_keys.dart';
import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:flutter/material.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../features/chat/data/chat_sync_service.dart';
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

  AuthProvider({
    AuthRepository? repository,
    AnalyticsService? analytics,
  })  : _repository = repository ?? AuthRepositoryImpl(),
        _analytics = analytics ?? AnalyticsService.instance {
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

  /// Current authentication state — drives SplashScreen navigation.
  AuthState get authState => _authState;

  /// Currently signed-in user. Null if unauthenticated.
  UserModel? get currentUser => _currentUser;

  /// Localization key for the last auth error.
  /// Null when no error. Reset to null after being consumed by UI.
  String? get authError => _authError;

  /// Whether Apple Sign-In should be shown in the UI (iOS only).
  bool get isAppleSignInAvailable => _repository.isAppleSignInAvailable;

  /// Convenience getter — true if a user is signed in.
  bool get isAuthenticated => _authState == AuthState.authenticated;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Check for an existing Firebase session on app start.
  ///
  /// Called immediately via ..initialize() in main.dart providers.
  /// Sets authState to authenticated or unauthenticated.
  /// SplashScreen waits for this to complete before navigating.
  Future<void> initialize() async {
    try {
      final user = await _repository.getCurrentUser();

      if (user != null) {
        _currentUser = user;
        _analytics.setUserId(user.uid);
        _setAuthState(AuthState.authenticated);
        // Start background sync as soon as an existing session is restored.
        // This drains any outbox tasks from the previous session and activates
        // Firestore streams for the conversation list.
        try {
          await ChatSyncService.instance.start(user.uid);
        } catch (e) {
          debugPrint('⚠️ ChatSyncService start error (ignored): $e');
        }
      } else {
        bool wasLoggedIn = false;
        try {
          wasLoggedIn = StorageService().getBool(StorageKeys.isLoggedIn);
        } catch (_) {}
        if (wasLoggedIn) {
          try {
            await StorageService().clearUserData();
          } catch (_) {}
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = AppRoutes.navigatorKey.currentContext;
            if (context != null) {
              MessageUtils.showWarning(context, context.l10n.sessionExpired);
            }
          });
        }
        _setAuthState(AuthState.unauthenticated);
      }
      debugPrint(
          '\u26a0\ufe0f AuthProvider initialize with either authenticate or unauthenticated state');
    } catch (e) {
      debugPrint('\u26a0\ufe0f AuthProvider initialize error: $e');
      bool wasLoggedIn = false;
      try {
        wasLoggedIn = StorageService().getBool(StorageKeys.isLoggedIn);
      } catch (_) {}
      if (wasLoggedIn &&
          (e.toString().contains('user-not-found') ||
              e.toString().contains('user-disabled') ||
              e.toString().contains('user-token-expired'))) {
        try {
          await StorageService().clearUserData();
        } catch (_) {}
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = AppRoutes.navigatorKey.currentContext;
          if (context != null) {
            MessageUtils.showWarning(context, context.l10n.sessionExpired);
          }
        });
      }
      // On any initialization error, treat as unauthenticated
      // Never leave the user stuck on the splash screen
      _setAuthState(AuthState.unauthenticated);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Sign in with Google.
  ///
  /// Returns true on success, false on cancellation.
  /// Sets authError on failure — UI observes and shows it.
  Future<bool> signInWithGoogle() async {
    // Fire analytics BEFORE auth — tracks button taps independently of outcome
    _effectBus.safeEffect(() async {
      _analytics.authenticationButtonTapped(SocialAuthProvider.google);
    });

    debugPrint('⚠️ AuthProvider performing signInWithGoogle');
    return _performSignIn(
      () => _repository.signInWithGoogle(),
      provider: SocialAuthProvider.google,
    );
  }

  // ── Apple Sign-In ──────────────────────────────────────────────────────────

  /// Sign in with Apple (iOS only).
  ///
  /// Returns true on success, false on cancellation.
  /// Sets authError on failure — UI observes and shows it.
  Future<bool> signInWithApple() async {
    // Fire analytics BEFORE auth — tracks button taps independently of outcome
    await _analytics.authenticationButtonTapped(SocialAuthProvider.apple);
    debugPrint('⚠️ AuthProvider performing signInWithApple');

    return _performSignIn(
      () => _repository.signInWithApple(),
      provider: SocialAuthProvider.apple,
    );
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  /// Sign out the current user.
  ///
  /// Clears all session data and sets state to unauthenticated.
  Future<void> signOut() async {
    _isLocalSignOutOrDelete = true;
    try {
      debugPrint("\u26a0\ufe0f AuthProvider Signing Out");
      final signingOutUid = _currentUser?.uid;

      // Stop sync BEFORE clearing local data to ensure no in-flight Firestore
      // operations run against stale credentials after the Firebase token expires.
      try {
        await ChatSyncService.instance.stop();
      } catch (e) {
        debugPrint('⚠️ ChatSyncService stop error (ignored): $e');
      }

      await _repository.signOut();
      await _analytics.clearUserId();
      if (_currentUser != null) {
        _analytics.logUserSignedOut(_currentUser!.uid);
      }

      // Clear this user's chat data from Hive so the next user session starts clean.
      // This is critical when two different accounts sign in on the same device.
      if (signingOutUid != null) {
        try {
          await StorageService().clearChatBoxes(signingOutUid);
        } catch (_) {}
      }
      try {
        await StorageService().clearUserData();
      } catch (_) {}

      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
    } catch (e) {
      debugPrint('\u26a0\ufe0f AuthProvider signOut error: $e');
      // Even on error, clear local state so user is not stuck
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
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
    try {
      debugPrint("⚠️ AuthProvider Deleting Account");
      final deletingUid = _currentUser?.uid;

      // Stop sync BEFORE clearing local data or deleting credentials so that
      // background workers do not attempt new Firestore reads/writes mid-deletion.
      try {
        await ChatSyncService.instance.stop();
      } catch (e) {
        debugPrint('⚠️ ChatSyncService stop error (ignored): $e');
      }

      // Execute remote deletion (conversations, profile doc, API keys, auth account).
      // If any critical step fails (e.g. requires-recent-login), we abort and return false
      // so the user remains on the profile screen with an error message instead of navigating away.
      final success = await _repository.deleteAccount();
      if (!success) {
        _authError ??= 'something_went_wrong';
        notifyListeners();
        return false;
      }

      // Log deletion event and clear analytics tracking IDs
      await _analytics.clearUserId();
      if (deletingUid != null) {
        _analytics.logAccountDeleted(deletingUid);
      }

      // Wipe local Hive databases (chat history and user preferences)
      if (deletingUid != null) {
        try {
          await StorageService().clearChatBoxes(deletingUid);
        } catch (_) {}
      }
      try {
        await StorageService().clearUserData();
      } catch (_) {}

      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
      return true;
    } on AuthException catch (e) {
      debugPrint('⚠️ AuthProvider deleteAccount AuthException: ${e.code}');
      _authError = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('⚠️ AuthProvider deleteAccount error: $e');
      _authError = 'something_went_wrong';
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

    if (user == null || resolvedDisplayName.isEmpty) {
      return false;
    }

    try {
      final success = await _repository.updateProfile(
        user,
        displayName: resolvedDisplayName,
        photoUrl: resolvedPhotoUrl,
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
    } catch (e) {
      debugPrint('❌ AuthProvider.updateProfile error: $e');
      _authError = 'something_went_wrong';
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
  Future<bool> _performSignIn(
    Future<UserModel?> Function() signInMethod, {
    required SocialAuthProvider provider,
  }) async {
    // Clear any previous error before starting
    _authError = null;
    _setAuthState(AuthState.authenticating);

    try {
      final user = await signInMethod();

      // Null means user cancelled — not an error
      if (user == null) {
        _setAuthState(AuthState.unauthenticated);
        return false;
      }

      _currentUser = user;

      // Fire the correct analytics event based on new vs returning
      if (user.isNewUser) {
        await _analytics.logUserRegistered(user);
      } else {
        await _analytics.logUserSignedIn(user);
      }

      await _analytics.setUserId(user.uid);

      _setAuthState(AuthState.authenticated);
      // Start background sync immediately after fresh sign-in so that
      // any outbox tasks and Firestore streams are active from the first screen.
      try {
        await ChatSyncService.instance.start(user.uid);
      } catch (e) {
        debugPrint('⚠️ ChatSyncService start error (ignored): $e');
      }
      return true;
    } on AuthException catch (e) {
      // Cancelled is not an error — just return false silently
      if (e.isCancelled) {
        _setAuthState(AuthState.unauthenticated);
        return false;
      }

      debugPrint('❌ AuthProvider sign-in failed: ${e.technicalMessage}');

      // Set the error code for UI to display
      _authError = e.code;
      _setAuthState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      debugPrint('❌ AuthProvider unexpected sign-in error: $e');
      _authError = 'something_went_wrong';
      _setAuthState(AuthState.unauthenticated);
      return false;
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
    _userExistsSub = _repository.watchUserExists(uid).listen((exists) async {
      if (!exists &&
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
    } on AuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'user-token-expired') {
        debugPrint(
            '⚠️ AuthProvider: Remote session termination detected on resume (${e.code})');
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

  Future<void> _handleRemoteSessionTermination() async {
    _userExistsSub?.cancel();
    _watchedUid = null;
    final uid = _currentUser?.uid;
    try {
      await ChatSyncService.instance.stop();
    } catch (_) {}

    try {
      await _repository.signOut();
    } catch (_) {}

    if (uid != null) {
      try {
        await StorageService().clearChatBoxes(uid);
      } catch (_) {}
    }
    try {
      await StorageService().clearUserData();
      await StorageService().setBool(StorageKeys.isLoggedIn, false);
    } catch (_) {}

    _currentUser = null;
    _setAuthState(AuthState.unauthenticated);

    // Show Snackbar and redirect to login screen like banking apps do
    final context = AppRoutes.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      MessageUtils.showWarning(context, context.l10n.sessionExpired);
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userExistsSub?.cancel();
    _authStateSub?.cancel();
    super.dispose();
  }
}
