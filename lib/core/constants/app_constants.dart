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
  static const String appVersion = '1.2.0';
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
      '• Image Generation (GPT-Image-2.5 Flare)\n• Text, Vision & PDF Analysis (GPT-6 Luna)\n• High-Precision Voice (Whisper)';
  static const String geminiAICapabilities =
      '• Image Generation (Gemini 3.1 Flash-Lite Image)\n• Fast Multimodal Reasoning (Gemini 3.5 Flash-Lite)';
  static const String claudeAICapabilities =
      '• Advanced Reasoning & Coding (Claude Haiku 4.5)\n• Deep PDF & Vision Analysis (Claude Haiku 4.5)';

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
  static const String aiPdfGenerationSystemInstruction =
      'You are AI Voice Genie, an elite publication and executive document compiler. '
      'When asked to generate or create a document, PDF, report, invoice, resume, comparison, or whitepaper, '
      'produce impeccably structured, publication-ready Markdown tailored for PDF compilation.\n\n'
      'CRITICAL FORMATTING RULES FOR PDF COMPILATION:\n'
      '1. Start immediately with a clean H1 title: # Document Title\n'
      '2. Follow with an optional short italicized subtitle or document meta info (e.g. *Published: October 2026 | Prepared for Executive Review*)\n'
      '3. Use hierarchical numbered or named section headers: ## 1. Section Title, ### Subsection\n'
      '4. TABLES: Always format comparative or pricing data using standard GitHub Markdown tables (| Column 1 | Column 2 |). NEVER use ASCII art, box-drawing characters (such as ┌, ─, │), or pseudo-text diagrams inside code blocks.\n'
      '5. CALLOUTS & KEY TAKEAWAYS: Use standard blockquotes (> **Key Takeaway:** description) for important highlights and insights.\n'
      '6. BULLETS & LISTS: Use clean bullet points (- or *) with concise, substantive descriptions.\n'
      '7. CITATIONS & SOURCES: When citing sources or web references, use clean readable domain labels (e.g., "- Source: Google Developers (ai.google.dev)" or "- Reference: DeepMind Research"). NEVER output raw search redirect URLs, tracking query strings, or unshortened search engine redirect tokens.\n'
      '8. CLEANLINESS: Strictly NO conversational filler (e.g., "Sure, here is your PDF", "Below is the document", "I hope this helps"). Output ONLY the document content starting directly from the # title.';

  // ── OpenAI Model Names ────────────────────────────────────────────────────
  // Verified 2026-09-27: gpt-6-luna (released 2026-09-22, 1.05M context)
  static const String openAiTextModel = 'gpt-6-luna';
  // Verified 2026-09-27: gpt-image-2.5-flare (released 2026-09-08, low-latency tier)
  static const String openAiImageGenModel = 'gpt-image-2.5-flare';
  // Vision uses same text model — gpt-6-luna natively supports multimodal input
  static const String openAiVisionModel = 'gpt-6-luna';
  // Whisper STT — used when the user has an OpenAI key configured
  static const String openAiWhisperModel = 'whisper-1';

  // ── Whisper STT Config ────────────────────────────────────────────────────
  // Amplitude threshold (dBFS) above which audio is classified as speech.
  // Values above -40 dBFS are treated as active speech for silence detection.
  static const double whisperSpeechAmplitudeThreshold = -40.0;
  // How often to poll amplitude for silence detection during Whisper recording
  static const Duration whisperAmplitudePollInterval =
      Duration(milliseconds: 300);

  // ── Gemini Model Names ────────────────────────────────────────────────────
  // Primary: gemini-3.8-flash (Latest Flash with reasoning, multimodal, and fresh 2026 knowledge)
  static const String geminiTextModel = 'gemini-3.8-flash';
  static const String geminiVisionModel = 'gemini-3.8-flash'; // multimodal
  // Budget Fallback: gemini-3.5-flash-lite
  static const String geminiFlashLiteModel = 'gemini-3.5-flash-lite';
  // Image Generation: gemini-3.1-flash-lite-image
  static const String geminiImageGenModel = 'gemini-3.1-flash-lite-image';

  // ── Claude Model Names ────────────────────────────────────────────────────
  // Verified 2026-09-27: claude-haiku-4-5-20251001 (fast/cheap, replaces sonnet)
  static const String claudeTextModel = 'claude-haiku-4-5-20251001';
  static const String claudeVisionModel =
      'claude-haiku-4-5-20251001'; // same model, natively multimodal
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
  // Context window token limits per model (verified 2026-09-27)
  static const int openAiContextTokenLimit = 1050000; // GPT-6 Luna
  static const int geminiContextTokenLimit = 1000000; // Gemini 3.5 Flash-Lite
  static const int claudeContextTokenLimit = 200000; // Claude Haiku 4.5

  /// Maximum recent conversation turns (user + assistant message pairs) sent as LLM context.
  /// A value of 3 preserves up to 6 alternating messages (3 user prompts + 3 assistant responses),
  /// keeping prompt payload sizes lean, controlling token expenditure, and preventing context dilution.
  static const int maxHistoryConversationTurns = 3;

  // Safety margin — only use 70% of context limit to avoid cutoffs
  static const double contextSafetyMargin = 0.70;

  // Rough approximation: 4 characters ≈ 1 token (used for local estimation)
  static const int charsPerToken = 4;

  // ── AI Request Retry ──────────────────────────────────────────────────────
  // Maximum retries for transient failures before moving to fallback model
  static const int maxRetryAttempts = 2;

  // ── PDF Handling ──────────────────────────────────────────────────────────
  // Maximum single PDF file size allowed (10MB)
  static const int maxPdfSizeBytes = 10 * 1024 * 1024;
  // Maximum combined PDF payload size for AI inline request (15MB -> ~20MB base64)
  static const int maxPdfCombinedSizeBytes = 15 * 1024 * 1024;
  // Maximum characters extracted from PDF sent to AI (cost optimization)
  static const int maxPdfCharactersForAi = 20000;

  // ── Image Handling ────────────────────────────────────────────────────────
  // Maximum single image size for vision requests (compressed before sending)
  static const int maxImageSizeBytes = 5 * 1024 * 1024;
  // Maximum combined image payload size for AI inline request (15MB -> ~20MB base64)
  static const int maxImageCombinedSizeBytes = 15 * 1024 * 1024;

  // Maximum allowed image size in bytes — guards against OOM on decode.
  // Set to 25 MB as recommended in the image download plan.
  static const int maxImageDownloadBytes = 25 * 1024 * 1024;

  // ── Voice ─────────────────────────────────────────────────────────────────
  // Maximum recording duration in seconds
  static const Duration maxRecordingSeconds = Duration(minutes: 2);
  // Silence detection timeout (auto-stop recording after silence)
  static const Duration silenceTimeout = Duration(seconds: 3);
}
