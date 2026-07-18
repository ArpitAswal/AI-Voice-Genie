import 'dart:io';

import 'package:ai_voice_genie/core/constants/firebase_collections.dart';
import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/services/analytics_service.dart';
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
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final AnalyticsService _analytics;

  AuthProvider({
    AuthRepository? repository,
    AnalyticsService? analytics,
  })  : _repository = repository ?? AuthRepositoryImpl(),
        _analytics = analytics ?? AnalyticsService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  AuthState _authState = AuthState.initial;
  UserModel? _currentUser;
  String? _authError;
  final EffectBus _effectBus = EffectBus.instance;

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
      } else {
        _setAuthState(AuthState.unauthenticated);
      }
      debugPrint(
          '⚠️ AuthProvider initialize with either authenticate or unauthenticated state');
    } catch (e) {
      debugPrint('⚠️ AuthProvider initialize error: $e');
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
    try {
      debugPrint("⚠️ AuthProvider Signing Out");
      await _repository.signOut();
      await _analytics.clearUserId();
      if (_currentUser != null) {
        _analytics.logUserSignedOut(_currentUser!.uid);
      }
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
    } catch (e) {
      debugPrint('⚠️ AuthProvider signOut error: $e');
      // Even on error, clear local state so user is not stuck
      _currentUser = null;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  // ── Profile Update ─────────────────────────────────────────────────────────

  /// Update profile fields and refresh the in-memory user model.
  Future<bool> updateProfile({
    required String displayName,
    required String photoUrl,
    DateTime? dateOfBirth,
    int? age,
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
    if (_authState == newState) return;
    _authState = newState;
    notifyListeners();
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
}
