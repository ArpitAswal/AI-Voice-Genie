/// App-wide constants for AI Voice Genie.
///
/// All magic values must be referenced from here.
/// Never hardcode strings, numbers, or paths in feature code.
class AppConstants {
  AppConstants._();

  // ── Secrets (loaded via compile-time environment variables) ────────────────
  // Run or build with: flutter run --dart-define-from-file=secrets.json
  // secrets.json is git-ignored and must never be bundled as an asset.
  static const String encryptionKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: '',
  );

  // ── App Info ───────────────────────────────────────────────────────────────
  static const String appVersion = '1.0.0 + 1';
  static const String copyrightOwner = 'AI Voice Genie';

  // Fill these before publishing the app on Google Play.
  static const String privacyPolicyUrl =
      'https://github.com/ArpitAswal/AI-Voice-Genie/blob/main/assets/legal/privacy_policy.md';
  static const String termsOfServiceUrl =
      'https://github.com/ArpitAswal/AI-Voice-Genie/blob/main/assets/legal/terms_of_service.md';
  static const String supportEmail = 'arpitaswal995@gmail.com';
  static const String helpCenterUrl = '';

  // ── Legal Versioning ──────────────────────────────────────────────────────
  // Current active version of the Terms of Service and Privacy Policy.
  // Bump this when publishing updated terms to prompt re-acceptance if required.
  static const String currentTermsVersion = '2026-07-v1';

  // ── Regex Patterns ────────────────────────────────────────────────────────
  static const String emailPattern = r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$';

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 700);

  // ── Network ───────────────────────────────────────────────────────────────
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

  // ── AI Model Capabilities (features offered by each adapter) ──────────────
  // PDF reading uses locally extracted PDF text, not native file/URL upload.
  static const String openAICapabilities =
      '• Image Generation (GPT-Image-1)\n• Text, Vision & PDF Analysis (GPT-4o)';
  static const String geminiAICapabilities =
      '• Image Generation (Gemini 2.5 Flash Image)\n• Fast Multimodal Reasoning (Gemini 2.5 Flash)';
  static const String claudeAICapabilities =
      '• Advanced Reasoning & Coding (Claude 3.5 Sonnet)\n• Deep PDF & Vision Analysis (Claude 3.5 Sonnet)';

  // ── AI Standard System Instructions ───────────────────────────────────────
  static const String aiTextSystemInstruction =
      'You are AI Voice Genie, a helpful, accurate, and intelligent AI assistant. '
      'Provide clear, concise, and well-structured answers using Markdown formatting (headings, bold, lists, and code blocks) where appropriate.';
  static const String aiVisionSystemInstruction =
      'You are AI Voice Genie, an expert visual analyst assistant. '
      'Analyze the provided image(s) accurately and thoroughly. Answer the user\'s questions clearly, identify key details, objects, text (OCR), and visual patterns, and format your findings using Markdown.';
  static const String aiPdfSystemInstruction =
      'You are AI Voice Genie, an expert document analysis assistant. '
      'Carefully examine the provided PDF document(s). Extract key facts, summarize information accurately without hallucinating, answer the user\'s questions based on the document contents, and structure your response using Markdown.';

  // ── OpenAI Model Names ────────────────────────────────────────────────────
  // Default models used for each capability
  static const String openAiTextModel = 'gpt-4o';
  static const String openAiImageGenModel = 'gpt-image-1';
  static const String openAiVisionModel = 'gpt-4o';

  // ── Gemini Model Names ────────────────────────────────────────────────────
  static const String geminiTextModel = 'gemini-2.5-flash';
  static const String geminiVisionModel = 'gemini-2.5-flash'; // multimodal
  static const String geminiImageGenModel = 'gemini-2.5-flash-image';

  // ── Claude Model Names ────────────────────────────────────────────────────
  static const String claudeTextModel = 'claude-3-5-sonnet-latest';
  static const String claudeVisionModel =
      'claude-3-5-sonnet-latest'; // same, multimodal
  // Claude does NOT support image generation — no constant needed

  // ── AI API Base URLs ──────────────────────────────────────────────────────
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';

  // ── Claude API Version Header ─────────────────────────────────────────────
  // Claude requires this specific header on every request
  static const String claudeApiVersion = '2023-06-01';

  // ── Token / Context Window Limits ────────────────────────────────────────
  // Context window token limits per model (approximate)
  static const int openAiContextTokenLimit = 128000; // GPT-4o
  static const int geminiContextTokenLimit = 1000000; // Gemini 2.5 Flash
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

  // Maximum allowed image size in bytes — guards against OOM on decode.
  // Set to 25 MB as recommended in the image download plan.
  static const int maxImageDownloadBytes = 25 * 1024 * 1024;

  // ── Voice ─────────────────────────────────────────────────────────────────
  // Maximum recording duration in seconds
  static const Duration maxRecordingSeconds = Duration(minutes: 2);
  // Silence detection timeout (auto-stop recording after silence)
  static const Duration silenceTimeout = Duration(seconds: 3);
}
