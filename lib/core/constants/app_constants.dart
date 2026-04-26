/// App-wide constants for AI Voice Genie.
///
/// All magic values must be referenced from here.
/// Never hardcode strings, numbers, or paths in feature code.
class AppConstants {
  // ── App Info ───────────────────────────────────────────────────────────────
  static const String appVersion = '1.0.0';

  // ── Validation ────────────────────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 20;
  static const int minNameLength = 3;
  static const int maxNameLength = 30;

  // ── Regex Patterns ────────────────────────────────────────────────────────
  static const String emailPattern = r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$';

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 700);
  static const Duration voicePulseDuration = Duration(milliseconds: 800);

  // ── Network ───────────────────────────────────────────────────────────────
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  // AI API calls can take longer — generous timeout for image generation
  static const Duration aiRequestTimeout = Duration(seconds: 90);

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notificationChannelId = 'ai_voice_genie_channel';
  static const String notificationChannelName = 'AI Voice Genie Notifications';
  static const String notificationChannelDescription =
      'Reminders and updates from AI Voice Genie';

  // ── Hive Box Names ─────────────────────────────────────────────────────────
  // Each box holds one category of data for clean separation
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String conversationCacheBox = 'conversation_cache_box';
  static const String messageCacheBox = 'message_cache_box';

  // ── Pagination ────────────────────────────────────────────────────────────
  // Number of conversations fetched per page in history screen
  static const int conversationPageSize = 15;
  // Number of messages loaded initially when opening a conversation
  static const int initialMessageLoadCount = 30;
  // Number of older messages loaded on scroll-up
  static const int messagePageSize = 20;

  // ── AI Model Display Names ────────────────────────────────────────────────
  // Human-readable names shown in the UI for each provider
  static const String openAiDisplayName = 'ChatGPT';
  static const String geminiDisplayName = 'Gemini';
  static const String claudeDisplayName = 'Claude';

  // ── AI Model IDs (used internally and in analytics) ───────────────────────
  static const String openAiProviderId = 'openai';
  static const String geminiProviderId = 'gemini';
  static const String claudeProviderId = 'claude';

  // ── AI Model Capabilities (features offered by each) ───────────────────────
  static const String openAICapabilities = 'GPT-4o • DALL-E 3 • Whisper';
  static const String geminiAICapabilities = 'GPT-4o • DALL-E 3 • Whisper';
  static const String claudeAICapabilities = 'GPT-4o • DALL-E 3 • Whisper';

  // ── OpenAI Model Names ────────────────────────────────────────────────────
  // Default models used for each capability
  static const String openAiTextModel = 'gpt-4o';
  static const String openAiImageGenModel = 'dall-e-3';
  static const String openAiVisionModel =
      'gpt-4o'; // same model, vision capable
  static const String openAiSttModel = 'whisper-1';
  static const String openAiTtsModel = 'tts-1';
  static const String openAiTtsVoice = 'alloy'; // default voice

  // ── Gemini Model Names ────────────────────────────────────────────────────
  static const String geminiTextModel = 'gemini-2.5-flash';
  static const String geminiVisionModel = 'gemini-2.5-flash'; // multimodal
  static const String geminiImageGenModel =
      'gemini-2.0-flash-exp-image-generation';

  // ── Claude Model Names ────────────────────────────────────────────────────
  static const String claudeTextModel = 'claude-sonnet-4-5';
  static const String claudeVisionModel =
      'claude-sonnet-4-5'; // same, multimodal
  // Claude does NOT support image generation — no constant needed

  // ── AI API Base URLs ──────────────────────────────────────────────────────
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';

  // ── AI API Validation Endpoints ───────────────────────────────────────────
  // Lightweight endpoints used to validate user API keys on first entry
  static const String openAiValidationEndpoint = '/models';
  static const String geminiValidationEndpoint = '/models';
  static const String claudeValidationEndpoint = '/models';

  // ── Claude API Version Header ─────────────────────────────────────────────
  // Claude requires this specific header on every request
  static const String claudeApiVersion = '2023-06-01';

  // ── Token / Context Window Limits ────────────────────────────────────────
  // Context window token limits per model (approximate)
  static const int openAiContextTokenLimit = 128000; // GPT-4o
  static const int geminiContextTokenLimit = 1000000; // Gemini 2.0 Flash
  static const int claudeContextTokenLimit = 200000; // Claude Sonnet

  // Safety margin — only use 70% of context limit to avoid cutoffs
  static const double contextSafetyMargin = 0.70;

  // Rough approximation: 4 characters ≈ 1 token (used for local estimation)
  static const int charsPerToken = 4;

  // ── AI Request Retry ──────────────────────────────────────────────────────
  // Maximum retries for transient failures before moving to fallback model
  static const int maxRetryAttempts = 2;

  // ── PDF Handling ──────────────────────────────────────────────────────────
  // Maximum PDF file size allowed (10MB)
  static const int maxPdfSizeBytes = 10 * 1024 * 1024;
  // Maximum characters extracted from PDF sent to AI (cost optimization)
  static const int maxPdfCharactersForAi = 20000;

  // ── Image Handling ────────────────────────────────────────────────────────
  // Maximum image size for vision requests (compressed before sending)
  static const int maxImageSizeBytes = 5 * 1024 * 1024;
  static const String defaultImageQuestion = 'Please analyze this image.';
  static const String defaultPdfQuestion = 'Please summarize this PDF.';
  // DALL-E 3 image size options
  static const String imageSize1024 = '1024x1024';
  static const String imageSize1792x1024 = '1792x1024';
  static const String imageSize1024x1792 = '1024x1792';

  // ── Voice ─────────────────────────────────────────────────────────────────
  // Maximum recording duration in seconds
  static const int maxRecordingSeconds = 60;
  // Silence detection timeout (auto-stop recording after silence)
  static const Duration silenceTimeout = Duration(seconds: 3);

  // ── Free Tier Quota (for users using their own key) ───────────────────────
  // Default daily request quota when user first adds their key
  static const int defaultDailyQuota = 50;
  // Quota resets at midnight UTC daily
  static const String quotaResetTime = 'midnight_utc';
}
