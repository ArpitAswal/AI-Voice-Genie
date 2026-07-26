import 'dart:async';
import 'dart:io';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/services/analytics_service.dart';
import 'package:ai_voice_genie/features/auth/domain/auth_repository.dart';
import 'package:ai_voice_genie/features/auth/domain/user_model.dart';
import 'package:ai_voice_genie/features/auth/presentation/auth_provider.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AuthProvider initialization', () {
    test('sets authenticated state when repository returns current user',
        () async {
      final user = _user();
      final repository = _FakeAuthRepository(currentUser: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      await provider.initialize();

      expect(provider.authState, AuthState.authenticated);
      expect(provider.currentUser, user);
      expect(analytics.userIds, [user.uid]);
    });

    test('sets unauthenticated state when no current user exists', () async {
      final provider = AuthProvider(
        repository: _FakeAuthRepository(),
        analytics: _FakeAnalyticsService(),
      );

      await provider.initialize();

      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
    });
  });

  group('AuthProvider Google sign-in', () {
    test('handles new-user success and records registration analytics',
        () async {
      final user = _user(isNewUser: true);
      final repository = _FakeAuthRepository(googleResult: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(provider.authState, AuthState.authenticated);
      expect(provider.currentUser, user);
      expect(repository.googleSignInCalls, 1);
      expect(analytics.authButtonTaps, [SocialAuthProvider.google]);
      expect(analytics.registeredUsers, [user]);
      expect(analytics.signedInUsers, isEmpty);
      expect(analytics.userIds, [user.uid]);
    });

    test('handles returning-user success and records sign-in analytics',
        () async {
      final user = _user(isNewUser: false);
      final repository = _FakeAuthRepository(googleResult: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(provider.authState, AuthState.authenticated);
      expect(provider.currentUser, user);
      expect(analytics.authButtonTaps, [SocialAuthProvider.google]);
      expect(analytics.registeredUsers, isEmpty);
      expect(analytics.signedInUsers, [user]);
      expect(analytics.userIds, [user.uid]);
    });

    test('handles user cancellation without setting an error', () async {
      final repository = _FakeAuthRepository(googleResult: null);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(success, isFalse);
      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(provider.authError, isNull);
      expect(analytics.authButtonTaps, [SocialAuthProvider.google]);
      expect(analytics.registeredUsers, isEmpty);
      expect(analytics.signedInUsers, isEmpty);
    });

    test('maps AuthException failures to auth error state', () async {
      final repository = _FakeAuthRepository(
        googleError: const AuthException(AuthErrorCodes.noInternet),
      );
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(success, isFalse);
      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(provider.authError, AuthErrorCodes.noInternet);
      expect(analytics.authButtonTaps, [SocialAuthProvider.google]);
      expect(analytics.registeredUsers, isEmpty);
      expect(analytics.signedInUsers, isEmpty);
    });
  });

  group('AuthProvider Apple sign-in', () {
    test('handles Apple success and records button tap analytics', () async {
      final user = _user(provider: SocialAuthProvider.apple);
      final repository = _FakeAuthRepository(appleResult: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithApple();

      expect(success, isTrue);
      expect(provider.authState, AuthState.authenticated);
      expect(provider.currentUser, user);
      expect(repository.appleSignInCalls, 1);
      expect(analytics.authButtonTaps, [SocialAuthProvider.apple]);
      expect(analytics.signedInUsers, [user]);
    });

    test('maps Apple failures to auth error state', () async {
      final repository = _FakeAuthRepository(
        appleError: const AuthException(AuthErrorCodes.signInFailed),
      );
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      final success = await provider.signInWithApple();

      expect(success, isFalse);
      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(provider.authError, AuthErrorCodes.signInFailed);
      expect(repository.appleSignInCalls, 1);
      expect(analytics.authButtonTaps, [SocialAuthProvider.apple]);
    });
  });

  group('AuthProvider onboarding and logout', () {
    test('marks onboarding complete through repository update', () async {
      final user = _user(onboardingDone: false);
      final repository = _FakeAuthRepository(googleResult: user);
      final provider = AuthProvider(
        repository: repository,
        analytics: _FakeAnalyticsService(),
      );

      await provider.signInWithGoogle();
      await provider.markBoardingComplete();
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser?.onboardingDone, isTrue);
      expect(repository.updateUserCalls, 1);
      expect(repository.lastUpdatedUser?.onboardingDone, isTrue);
      expect(repository.lastUpdatedField, 'onboardingDone');
      expect(repository.lastUpdatedValue, isTrue);
    });

    test('signs out and clears authenticated state on success', () async {
      final user = _user();
      final repository = _FakeAuthRepository(googleResult: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      await provider.signInWithGoogle();
      await provider.signOut();

      expect(repository.signOutCalls, 1);
      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(analytics.clearUserIdCalls, 1);
      expect(analytics.signedOutUserIds, [user.uid]);
    });

    test('clears local auth state even when repository sign-out fails',
        () async {
      final user = _user();
      final repository = _FakeAuthRepository(
        googleResult: user,
        signOutError: Exception('sign out failed'),
      );
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      await provider.signInWithGoogle();
      await provider.signOut();

      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(analytics.clearUserIdCalls, 0);
      expect(analytics.signedOutUserIds, isEmpty);
    });

    test('deleteAccount deletes account, clears local state and analytics',
        () async {
      final user = _user();
      final repository = _FakeAuthRepository(googleResult: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      await provider.signInWithGoogle();
      final success = await provider.deleteAccount();

      expect(success, isTrue);
      expect(repository.deleteAccountCalls, 1);
      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(analytics.clearUserIdCalls, 1);
      expect(analytics.deletedAccountUserIds, [user.uid]);
    });

    test('deleteAccount sets authError when AuthException is thrown (e.g., requires-recent-login)',
        () async {
      final user = _user();
      final repository = _FakeAuthRepository(
        googleResult: user,
        deleteAccountError: const AuthException(AuthErrorCodes.requiresRecentLogin),
      );
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );

      await provider.signInWithGoogle();
      final success = await provider.deleteAccount();

      expect(success, isFalse);
      expect(repository.deleteAccountCalls, 1);
      expect(provider.authError, AuthErrorCodes.requiresRecentLogin);
    });

    test('remote session termination sets unauthenticated state when user emitted is null',
        () async {
      final user = _user();
      final repository = _FakeAuthRepository(currentUser: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );
      await provider.initialize();
      expect(provider.authState, AuthState.authenticated);

      // Simulate Firebase Auth emitting null remotely (e.g. account deleted on another device)
      repository.authStateController.add(null);
      await Future.delayed(Duration.zero);

      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
    });

    test('remote profile deletion via watchUserExists sets unauthenticated state and signs out', () async {
      final user = _user();
      final repository = _FakeAuthRepository(currentUser: user);
      final analytics = _FakeAnalyticsService();
      final provider = AuthProvider(
        repository: repository,
        analytics: analytics,
      );
      await provider.initialize();
      expect(provider.authState, AuthState.authenticated);

      // Simulate Firestore profile doc being deleted from another device
      repository.userExistsController.add(false);
      await Future.delayed(Duration.zero);

      expect(provider.authState, AuthState.unauthenticated);
      expect(provider.currentUser, isNull);
      expect(repository.signOutCalls, 1);
    });
  });
}

UserModel _user({
  bool isNewUser = false,
  bool onboardingDone = true,
  bool keySetupDone = true,
  SocialAuthProvider provider = SocialAuthProvider.google,
}) {
  return UserModel(
    uid: 'uid-123',
    email: 'tester@example.com',
    displayName: 'Test User',
    photoUrl: 'https://example.com/avatar.png',
    authProvider: provider,
    isNewUser: isNewUser,
    onboardingDone: onboardingDone,
    keySetupDone: keySetupDone,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.currentUser,
    this.googleResult,
    this.appleResult,
    this.googleError,
    this.appleError,
    this.signOutError,
    this.deleteAccountError,
  });

  final authStateController = StreamController<UserModel?>.broadcast();
  final userExistsController = StreamController<bool>.broadcast();

  @override
  Stream<UserModel?> get authStateChanges => authStateController.stream;

  @override
  Stream<bool> watchUserExists(String uid) => userExistsController.stream;

  @override
  Future<void> reloadSession() async {}

  UserModel? currentUser;
  UserModel? googleResult;
  UserModel? appleResult;
  Object? googleError;
  Object? appleError;
  Object? signOutError;
  Object? deleteAccountError;

  int googleSignInCalls = 0;
  int appleSignInCalls = 0;
  int signOutCalls = 0;
  int deleteAccountCalls = 0;
  bool deleteAccountResult = true;
  int updateUserCalls = 0;
  UserModel? lastUpdatedUser;
  String? lastUpdatedField;
  bool? lastUpdatedValue;

  @override
  bool get isAppleSignInAvailable => true;

  @override
  Future<UserModel?> getCurrentUser() async => currentUser;

  @override
  Future<UserModel?> signInWithGoogle() async {
    googleSignInCalls += 1;
    final error = googleError;
    if (error != null) throw error;
    return googleResult;
  }

  @override
  Future<UserModel?> signInWithApple() async {
    appleSignInCalls += 1;
    final error = appleError;
    if (error != null) throw error;
    return appleResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final error = signOutError;
    if (error != null) throw error;
  }

  @override
  Future<bool> deleteAccount() async {
    deleteAccountCalls += 1;
    final error = deleteAccountError;
    if (error != null) throw error;
    return deleteAccountResult;
  }

  @override
  Future<bool> updateUser(
    UserModel? currentUser, {
    required String field,
    required bool value,
  }) async {
    updateUserCalls += 1;
    lastUpdatedUser = currentUser;
    lastUpdatedField = field;
    lastUpdatedValue = value;
    return true;
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
    return true;
  }
}

class _FakeAnalyticsService implements AnalyticsService {
  final authButtonTaps = <SocialAuthProvider>[];
  final registeredUsers = <UserModel>[];
  final signedInUsers = <UserModel>[];
  final signedOutUserIds = <String>[];
  final deletedAccountUserIds = <String>[];
  final userIds = <String>[];
  int clearUserIdCalls = 0;

  @override
  FirebaseAnalyticsObserver getAnalyticsObserver() {
    throw UnimplementedError('Not used by AuthProvider tests.');
  }

  @override
  Future<void> authenticationButtonTapped(SocialAuthProvider provider) async {
    authButtonTaps.add(provider);
  }

  @override
  Future<void> logUserRegistered(UserModel user) async {
    registeredUsers.add(user);
  }

  @override
  Future<void> logUserSignedIn(UserModel user) async {
    signedInUsers.add(user);
  }

  @override
  Future<void> logUserSignedOut(String uid) async {
    signedOutUserIds.add(uid);
  }

  @override
  Future<void> logAccountDeleted(String uid) async {
    deletedAccountUserIds.add(uid);
  }

  @override
  Future<void> setUserId(String userId) async {
    userIds.add(userId);
  }

  @override
  Future<void> clearUserId() async {
    clearUserIdCalls += 1;
  }

  @override
  Future<void> logAiCapabilityGap({
    required AiProviderId modelSelected,
    required AiCapability capabilityAttempted,
  }) async {}

  @override
  Future<void> logAiFallbackTriggered({
    required AiProviderId fromModel,
    required AiProviderId toModel,
    required AiFailureType reason,
  }) async {}

  @override
  Future<void> logAiRequestFailed({
    required AiProviderId modelAttempted,
    required AiCapability capability,
    required AiFailureType failureType,
    required String failureReason,
    required String requestId,
  }) async {}

  @override
  Future<void> logAiRequestInitiated({
    required AiProviderId modelAttempted,
    required AiCapability capability,
    required String requestId,
  }) async {}

  @override
  Future<void> logAiRequestSuccess({
    required AiProviderId modelUsed,
    required AiCapability capability,
    required int responseTimeMs,
    required String requestId,
    int tokenCount = 0,
  }) async {}

  @override
  Future<void> logConversationStarted({
    required AiCapability capability,
    required AiProviderId provider,
  }) async {}

  @override
  Future<void> logFeatureUsed(AppFeature feature) async {}

  @override
  Future<void> logModelKeyAdded(AiProviderId provider, String uid) async {}

  @override
  Future<void> logModelKeyRemoved(AiProviderId provider, String uid) async {}

  @override
  Future<void> logModelSwitched({
    required AiProviderId fromModel,
    required AiProviderId toModel,
  }) async {}

  @override
  Future<void> logVoiceInputUsed({required bool usedAiStt}) async {}

  @override
  Future<void> logVoiceOutputUsed({required bool usedAiTts}) async {}
}
