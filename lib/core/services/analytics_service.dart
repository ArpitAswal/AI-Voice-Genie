import 'package:ai_voice_genie/features/auth/domain/user_model.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../constants/firebase_collections.dart';
import '../enums/app_enums.dart';

/// Centralized analytics service for AI Voice Genie.
///
/// All Firebase Analytics calls must go through this service.
/// Never call FirebaseAnalytics directly from features or UI.
///
/// Every AI interaction, feature usage, and key event is tracked here.
/// Analytics data drives model usage insights and failure rate monitoring.
///
/// Usage:
/// ```dart
/// AnalyticsService.instance.logAiRequestSuccess(
///   modelUsed: AiProviderId.openAi,
///   capability: AiCapability.textGeneration,
///   responseTimeMs: 1200,
///   tokenCount: 450,
/// );
/// ```
class AnalyticsService {
  // Singleton
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Returns the analytics observer to track page navigation
  FirebaseAnalyticsObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  /// Log a screen view with human-readable name and class for dashboard analytics.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('⚠️ Analytics logScreenView failed: $e');
    }
  }

  // ── AI Request Events ─────────────────────────────────────────────────────

  /// Log when a user initiates an AI request (before the API call).
  ///
  /// [requestId] links this event to the matching success/failure and usage event.
  Future<void> logAiRequestInitiated({
    required AiProviderId modelAttempted,
    required AiCapability capability,
    required String requestId,
  }) async {
    await _safeLog(FirebaseCollections.eventAiRequestInitiated, {
      FirebaseCollections.paramModelUsed: modelAttempted.id,
      FirebaseCollections.paramCapability: capability.id,
      FirebaseCollections.paramRequestId: requestId,
    });
  }

  /// Log when an AI request completes successfully.
  ///
  /// [requestId] links this event to the matching initiated and usage event.
  Future<void> logAiRequestSuccess({
    required AiProviderId modelUsed,
    required AiCapability capability,
    required int responseTimeMs,
    required String requestId,
  }) async {
    await _safeLog(FirebaseCollections.eventAiRequestSuccess, {
      FirebaseCollections.paramModelUsed: modelUsed.id,
      FirebaseCollections.paramCapability: capability.id,
      FirebaseCollections.paramResponseTimeMs: responseTimeMs,
      FirebaseCollections.paramRequestId: requestId,
    });
  }

  /// Log when an AI request fails.
  ///
  /// Response time is intentionally excluded from failure events as it is only
  /// meaningful for completed inference latency monitoring.
  Future<void> logAiRequestFailed({
    required AiProviderId modelAttempted,
    required AiCapability capability,
    required AiFailureType failureType,
    required String failureReason,
    required String requestId,
  }) async {
    await _safeLog(FirebaseCollections.eventAiRequestFailed, {
      FirebaseCollections.paramModelUsed: modelAttempted.id,
      FirebaseCollections.paramCapability: capability.id,
      FirebaseCollections.paramFailureType: failureType.value,
      FirebaseCollections.paramFailureReason: failureReason,
      FirebaseCollections.paramRequestId: requestId,
    });
  }

  /// Log when user attempts a feature their selected model does not support
  Future<void> logAiCapabilityGap({
    required AiProviderId modelSelected,
    required AiCapability capabilityAttempted,
  }) async {
    await _safeLog(FirebaseCollections.eventAiCapabilityGap, {
      FirebaseCollections.paramModelUsed: modelSelected.id,
      FirebaseCollections.paramCapability: capabilityAttempted.id,
    });
  }

  // ── Feature Usage Events ──────────────────────────────────────────────────

  /// Log which app feature the user is actively using (e.g. voice input, TTS output)
  Future<void> logFeatureUsed(AppFeature feature) async {
    await _safeLog(FirebaseCollections.eventFeatureUsed, {
      FirebaseCollections.paramFeature: feature.analyticsId,
    });
  }

  // ── Key Management Events ─────────────────────────────────────────────────

  /// Log when user successfully adds an API key for a provider
  Future<void> logModelKeyAdded(AiProviderId provider, String uid) async {
    await _safeLog(FirebaseCollections.eventModelAdded, {
      FirebaseCollections.paramUserId: uid,
      FirebaseCollections.paramModelUsed: provider.id,
    });
  }

  /// Log when user removes an API key
  Future<void> logModelKeyRemoved(AiProviderId provider, String uid) async {
    await _safeLog(FirebaseCollections.eventModelRemoved, {
      FirebaseCollections.paramUserId: uid,
      FirebaseCollections.paramModelUsed: provider.id,
    });
  }

  // ── Auth Events ───────────────────────────────────────────────────────────

  /// Log when authentication is initiated (user taps sign-in button).
  ///
  /// Tracks user sign-in intent independently of final outcome.
  Future<void> logAuthInitiated(SocialAuthProvider provider,
      {String? userId}) async {
    await _safeLog(FirebaseCollections.eventAuthenticateUser, {
      FirebaseCollections.paramAuthProvider: provider.id,
      if (userId != null && userId.isNotEmpty)
        FirebaseCollections.paramUserId: userId,
    });
  }

  /// Log when user authentication fails.
  ///
  /// Strictly safe parameters — no passwords, tokens, or PII.
  Future<void> logUserAuthFailed({
    required SocialAuthProvider authProvider,
    required String errorCode,
  }) async {
    await _safeLog(FirebaseCollections.eventUserAuthFailed, {
      FirebaseCollections.paramAuthProvider: authProvider.id,
      FirebaseCollections.paramAuthErrorCode: errorCode,
    });
  }

  /// Log when a returning user signs in successfully
  Future<void> logUserSignedIn(UserModel user) async {
    await _safeLog(FirebaseCollections.eventUserSignedIn, {
      FirebaseCollections.paramUserId: user.uid,
      FirebaseCollections.paramAuthProvider: user.authProvider.id,
      FirebaseCollections.paramUserEmail: user.email,
    });
  }

  /// Log when a brand new user signs up for the first time
  Future<void> logUserRegistered(UserModel user) async {
    await _safeLog(FirebaseCollections.eventUserRegistered, {
      FirebaseCollections.paramUserId: user.uid,
      FirebaseCollections.paramAuthProvider: user.authProvider.id,
      FirebaseCollections.paramUserEmail: user.email,
    });
  }

  /// Log when the user signs out
  Future<void> logUserSignedOut(UserModel user) async {
    await _safeLog(FirebaseCollections.eventUserSignedOut, {
      FirebaseCollections.paramUserId: user.uid,
      FirebaseCollections.paramAuthProvider: user.authProvider.id,
      FirebaseCollections.paramUserEmail: user.email,
    });
  }

  /// Log when the user deletes their account
  Future<void> logAccountDeleted(UserModel user) async {
    await _safeLog(FirebaseCollections.eventAccountDeleted, {
      FirebaseCollections.paramUserId: user.uid,
      FirebaseCollections.paramAuthProvider: user.authProvider.id,
      FirebaseCollections.paramUserEmail: user.email,
    });
  }

  /// Log a generated image download attempt and its outcome.
  ///
  /// Safe parameters only — model used, result, failure reason (no image URL, prompt text, or PII).
  Future<void> logImageDownload({
    required String provider,
    required String result,
    String failureReason = '',
  }) async {
    await _safeLog(FirebaseCollections.eventGeneratedImageDownload, {
      FirebaseCollections.paramModelUsed: provider,
      FirebaseCollections.paramDownloadResult: result,
      if (failureReason.isNotEmpty)
        FirebaseCollections.paramDownloadFailureReason: failureReason,
    });
  }

  /// Log an AI-compiled PDF document download attempt and its outcome.
  ///
  /// Safe parameters only — result, file size, failure reason (no file path or PII).
  Future<void> logPdfDownload({
    required String result,
    int? fileSizeBytes,
    String failureReason = '',
  }) async {
    await _safeLog(FirebaseCollections.eventGeneratedPdfDownload, {
      FirebaseCollections.paramDownloadResult: result,
      if (fileSizeBytes != null)
        FirebaseCollections.paramFileSizeBytes: fileSizeBytes,
      if (failureReason.isNotEmpty)
        FirebaseCollections.paramDownloadFailureReason: failureReason,
    });
  }

  /// Set the user ID for all subsequent analytics events
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('⚠️ Analytics setUserId failed: $e');
    }
  }

  /// Clear user ID on logout
  Future<void> clearUserId() async {
    try {
      await _analytics.setUserId(id: null);
    } catch (e) {
      debugPrint('⚠️ Analytics clearUserId failed: $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Safe wrapper — analytics failures must never crash the app
  Future<void> _safeLog(
    String eventName,
    Map<String, Object> parameters,
  ) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);
    } catch (e) {
      // Analytics failures are silent — never interrupt the user flow
      debugPrint('⚠️ Analytics log failed [$eventName]: $e');
    }
  }
}
