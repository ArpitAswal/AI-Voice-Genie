/// All Hive and local storage key constants for AI Voice Genie.
///
/// Every storage read/write must reference a key from this class.
/// No raw string keys anywhere in feature code.
class StorageKeys {
  // ── User Session ──────────────────────────────────────────────────────────
  static const String isLoggedIn = 'isLoggedIn';
  static const String userId = 'userId';
  static const String userEmail = 'userEmail';
  static const String userDisplayName = 'userDisplayName';
  static const String userPhotoUrl = 'userPhotoUrl';

  // ── Onboarding ────────────────────────────────────────────────────────────
  static const String onboardingCompleted = 'onboardingCompleted';
  // Whether user has completed the AI key setup screen after first login
  static const String keySetupCompleted = 'keySetupCompleted';

  // ── App Settings ──────────────────────────────────────────────────────────
  static const String themeMode = 'themeMode';
  static const String locale = 'locale';
  static const String notificationsEnabled = 'notificationsEnabled';

  // ── AI Model Preferences ──────────────────────────────────────────────────
  // The user's currently selected/preferred AI provider ID
  static const String preferredProviderId = 'preferredProviderId';
  // The user's preferred image quality for generation
  static const String preferredImageQuality = 'preferredImageQuality';
  // The user's preferred image size for generation
  static const String preferredImageSize = 'preferredImageSize';
  // The user's preferred number of generated images
  static const String preferredImageCount = 'preferredImageCount';

  // ── Active Conversation Cache ──────────────────────────────────────────────
  // ID of the last open conversation (to restore on app resume)
  static const String lastOpenConversationId = 'lastOpenConversationId';

  // ── Voice Settings ────────────────────────────────────────────────────────
  // Whether to use device-native TTS or AI-powered TTS (if key available)
  static const String useAiTts = 'useAiTts';
  // Whether to use device-native STT or Whisper STT (if OpenAI key available)
  static const String useAiStt = 'useAiStt';
  // TTS playback speed (0.5 – 2.0)
  static const String ttsSpeed = 'ttsSpeed';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String fcmToken = 'fcmToken';
  static const String lastNotificationDate = 'lastNotificationDate';

  // ── Analytics ─────────────────────────────────────────────────────────────
  // Tracks which session analytics have been sent (prevents duplicate events)
  static const String lastAnalyticsDate = 'lastAnalyticsDate';
}
