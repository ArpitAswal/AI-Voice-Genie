/// AI provider identifiers used throughout the orchestration system.
///
/// These match the provider IDs stored in Firestore and fired in analytics.
enum AiProviderId {
  openAi(
    'openai',
    'ChatGPT',
    '• Image Generation (GPT-Image-2.5 Flare)\n• Text, Vision & PDF Analysis (GPT-6 Luna)\n• High-Precision Voice (Whisper)',
  ),
  gemini(
    'gemini',
    'Gemini',
    '• Image Generation (Gemini 3.1 Flash-Lite Image)\n• Fast Multimodal Reasoning (Gemini 3.5 Flash-Lite)',
  ),
  claude(
    'claude',
    'Claude',
    '• Advanced Reasoning & Coding (Claude Haiku 4.5)\n• Deep PDF & Vision Analysis (Claude Haiku 4.5)',
  );

  /// Internal ID used in Firestore, analytics, and API routing
  final String id;

  /// Human-readable display name shown in the UI
  final String displayName;

  /// AI Model features
  final String features;

  const AiProviderId(this.id, this.displayName, this.features);

  /// Convert a string ID back to the enum (used when reading from Firestore)
  static AiProviderId fromId(String id) {
    return AiProviderId.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AiProviderId.openAi,
    );
  }
}

/// All capabilities that an AI provider can support.
///
/// The capability matrix is built from these enum values.
/// Used by the orchestrator to route requests and detect capability gaps.
enum AiCapability {
  /// Standard text conversation / prompt-response
  textGeneration('text_generation', 'Text Generation'),

  /// Generate an image from a text description
  imageGeneration('image_generation', 'Image Generation'),

  /// Analyze and describe an uploaded image
  imageUnderstanding('image_understanding', 'Image Reading'),

  /// Extract text from a PDF and answer questions about it
  pdfParsing('pdf_parsing', 'PDF Reading'),

  /// Generate a formatted PDF document from a user prompt
  pdfGeneration('pdf_generation', 'PDF Generation');

  final String id;
  final String displayName;

  const AiCapability(this.id, this.displayName);

  static AiCapability fromId(String id) {
    return AiCapability.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AiCapability.textGeneration,
    );
  }

  static AiCapability fromValue(String value) {
    return AiCapability.values.firstWhere(
      (e) => e.id == value || e.displayName == value,
      orElse: () => AiCapability.textGeneration,
    );
  }
}

/// Roles in a conversation message.
///
/// Mirrors the role field in Firestore message documents.
enum MessageRole {
  user('user'),
  assistant('assistant'),
  system('system');

  final String value;
  const MessageRole(this.value);

  static MessageRole fromValue(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageRole.user,
    );
  }
}

/// Content type of a message — determines how the UI renders it.
enum MessageContentType {
  text('prompt_text'),
  imageUrl('image_url'),
  pdfSummary('pdf_summary'),
  voiceTranscript('voice_transcript');

  final String value;
  const MessageContentType(this.value);

  static MessageContentType fromValue(String value) {
    return MessageContentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageContentType.text,
    );
  }
}

/// Message delivery status — used for UI state indicators.
enum MessageStatus {
  sending('sending'),
  delivered('delivered'),
  failed('failed'),
  partial('partial');

  final String value;
  const MessageStatus(this.value);

  static MessageStatus fromValue(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageStatus.delivered,
    );
  }
}

/// Sync state of a local Hive record relative to its Firestore counterpart.
///
/// Transitions:
///   pendingCreate → synced           (after first successful Firestore write)
///   pendingUpdate → synced           (after title/metadata write succeeds)
///   pendingDelete → [hard deleted]   (after remote delete succeeds)
///   synced        → pendingUpdate    (when user edits locally)
///   any           → syncFailed       (after max retry attempts exhausted for non-retryable error)
///   syncFailed    → pending*         (reset when connectivity restored, for retryable errors)
enum SyncStatus {
  /// Created locally, not yet written to Firestore.
  pendingCreate('pending_create'),

  /// Update queued locally, Firestore write pending.
  pendingUpdate('pending_update'),

  /// Marked for deletion locally; remote delete queued in outbox.
  pendingDelete('pending_delete'),

  /// Currently being written to Firestore by the sync worker.
  syncing('syncing'),

  /// Successfully written to Firestore and confirmed.
  synced('synced'),

  /// All retry attempts exhausted (non-retryable error only).
  /// Retryable failures reset back to pendingCreate/pendingUpdate.
  syncFailed('sync_failed'),

  /// Remote and local states are in conflict — requires manual resolution.
  conflict('conflict');

  final String value;
  const SyncStatus(this.value);

  static SyncStatus fromValue(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SyncStatus.pendingCreate,
    );
  }
}

/// AI request failure classification — drives fallback behavior.
///
/// The orchestrator uses this to decide: retry same model, skip to next, or hard fail.
enum AiFailureType {
  /// Network timeout, no connection — retry same model (max 2x)
  transient('transient'),

  /// 429 Too Many Requests — skip this model, try next
  rateLimit('rate_limit'),

  /// 401, 400, misconfiguration — do not retry, report to user
  hardError('hard_error'),

  /// Model does not support this capability — not a failure, a routing decision
  capabilityGap('capability_gap'),

  /// All models failed — emit via EffectBus
  exhausted('exhausted');

  final String value;
  const AiFailureType(this.value);
}

/// App theme mode options.
enum ThemeType {
  light('light'),
  dark('dark'),
  system('system');

  final String value;
  const ThemeType(this.value);

  static ThemeType fromValue(String value) {
    return ThemeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ThemeType.light,
    );
  }
}

/// Image background preference for image generation.
enum ImageGenerateBackground {
  auto('auto', 'Auto'),
  opaque('opaque', 'Opaque'),
  transparent('transparent', 'Transparent');

  final String apiValue;
  final String displayName;
  const ImageGenerateBackground(this.apiValue, this.displayName);

  static ImageGenerateBackground fromString(String name) {
    return ImageGenerateBackground.values.firstWhere(
      (e) => e.apiValue == name,
      orElse: () => ImageGenerateBackground.auto,
    );
  }
}

/// Feature identifiers used in analytics events.
///
/// Logged as the 'feature' parameter in 'feature_used' analytics events.
enum AppFeature {
  textChat('text_chat'),
  imageGeneration('image_gen'),
  imageReading('image_read'),
  pdfReader('pdf_reader'),
  voiceInput('voice_input'),
  voiceOutput('voice_output'),
  conversationHistory('history'),
  apiKeyManagement('api_keys');

  final String analyticsId;
  const AppFeature(this.analyticsId);
}

/// API key validation status — shown in the key management UI.
enum ApiKeyStatus {
  /// Key exists and was last validated successfully
  valid,

  /// Key exists but validation failed (expired, revoked, or wrong)
  invalid,

  /// No key has been added for this provider
  notAdded,

  /// Validation is currently in progress
  validating,
}

/// Voice recording state — drives the voice input button UI.
enum VoiceRecordingState {
  /// Idle — waiting for user to tap
  idle,

  /// Actively recording user speech
  recording,

  /// Processing the recorded audio (STT in progress)
  processing,

  /// Error occurred during recording or processing
  error,

  /// User is currently listening for voice input
  listening,

  /// Device is not available for voice input
  unavailable,

  /// TTS is currently playing
  playing
}

/// Determines how [ChatScreen] is opened — used by the router
/// to distinguish a normal text-first entry from a voice-first entry
/// triggered by the Home screen microphone button.
enum ChatStartMode {
  /// Standard flow — user opens chat and types a prompt manually.
  normal,

  /// Voice flow — chat opens with STT already listening so the user
  /// can speak directly without tapping the in-app mic button.
  voice,
}

/// Social authentication provider used to sign in.
///
/// Stored in Firestore user document and used in analytics.
/// Determines which sign-in flow is triggered in AuthRepositoryImpl.
enum SocialAuthProvider {
  google('google', 'Google'),
  apple('apple', 'Apple');

  /// Internal ID stored in Firestore and sent to analytics
  final String id;

  /// Human-readable display name
  final String displayName;

  const SocialAuthProvider(this.id, this.displayName);

  static SocialAuthProvider fromId(String id) {
    return SocialAuthProvider.values.firstWhere(
      (e) => e.id == id,
      orElse: () => SocialAuthProvider.google,
    );
  }
}

/// Authentication state — drives navigation from SplashScreen.
///
/// SplashScreen observes this enum via AuthProvider.
/// Never navigate manually — always react to state changes.
enum AuthState {
  /// App just launched — auth check not yet complete
  initial,

  /// Auth check in progress — sign-in API call running
  authenticating,

  /// User is fully authenticated — navigate to correct screen
  authenticated,

  /// No active session — navigate to LoginScreen
  unauthenticated,
}

/// AI model image generate quality
enum ImageQuality {
  /// Cost cheapest, Speed fastest
  low('Low'),

  /// Cost balanced, Speed normal
  medium('Medium'),

  /// Cost Expensive, Speed slower
  high('High');

  final String value;

  const ImageQuality(this.value);

  static ImageQuality fromValue(String value) {
    final lower = value.toLowerCase();
    return ImageQuality.values.firstWhere(
      (e) => e.value.toLowerCase() == lower || e.name.toLowerCase() == lower,
      orElse: () => ImageQuality.low,
    );
  }
}

/// Desired image size for generation requests.
enum AiImageSize {
  /// 1024×1024 — default square format
  square(
      width: 1024,
      height: 1024,
      apiValue: '1024x1024',
      name: 'Square (1024x1024)'),

  /// 1024×1536 — portrait
  portrait(
      width: 1024,
      height: 1536,
      apiValue: '1024x1536',
      name: 'Portrait (1024x1536)'),

  /// 1536×1024 — landscape / widescreen
  landscape(
      width: 1536,
      height: 1024,
      apiValue: '1536x1024',
      name: 'Landscape (1536x1024)');

  const AiImageSize(
      {required this.width,
      required this.height,
      required this.apiValue,
      required this.name});

  final int width;
  final int height;
  final String apiValue;
  final String name;

  double get aspectRatio => width / height;

  static AiImageSize fromValue(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('landscape') ||
        lower.contains('16:9') ||
        lower.contains('1536x1024')) {
      return AiImageSize.landscape;
    }
    if (lower.contains('portrait') ||
        lower.contains('9:16') ||
        lower.contains('1024x1536')) {
      return AiImageSize.portrait;
    }
    if (lower.contains('square') ||
        lower.contains('1:1') ||
        lower.contains('1024x1024')) {
      return AiImageSize.square;
    }
    return AiImageSize.values.firstWhere(
      (size) => size.name == value || size.apiValue == value,
      orElse: () => AiImageSize.square,
    );
  }
}

/// Vision detail level for OpenAI image analysis requests.
///
/// Controls the resolution the model uses when analysing each image:
///   auto → model picks low or high based on input size (cheapest + smartest)
///   low  → always use low-res 512×512 tile (faster, cheaper, less accurate)
///   high → use high-res tiles (slower, more expensive, better for fine detail)
///
/// Maps directly to the `detail` field in OpenAI's image_url content block.
enum VisionDetailLevel {
  /// Let the model decide — best default for general use
  auto('auto', 'Auto'),

  /// Force low-res 512×512 analysis — fastest and cheapest
  low('low', 'Low'),

  /// Force high-res tiling — best for fine details, text in images
  high('high', 'High');

  /// API value sent to OpenAI in the `detail` field
  final String apiValue;

  /// Human-readable label for the UI
  final String displayName;

  const VisionDetailLevel(this.apiValue, this.displayName);

  static VisionDetailLevel fromValue(String value) {
    return VisionDetailLevel.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => VisionDetailLevel.auto,
    );
  }
}

/// Represents the user's preferred AI response length (max output tokens).
///
/// Each tier maps to provider-appropriate token bounds tailored for each model:
/// - OpenAI (GPT-6 Luna): supports up to 16,384 output tokens
/// - Gemini (Gemini 3.5 Flash-Lite): supports up to 16,384 output tokens
/// - Claude (Claude Haiku 4.5): supports up to 8,192 output tokens (Anthropic API ceiling)
enum ResponseLength {
  short(
    openAiMaxTokens: 500,
    geminiMaxTokens: 1000,
    claudeMaxTokens: 500,
    displayName: 'Short',
    description: 'Good for quick and simple answers.',
  ),
  balanced(
    openAiMaxTokens: 2048,
    geminiMaxTokens: 4000,
    claudeMaxTokens: 2048,
    displayName: 'Balanced',
    description: 'Best for standard conversations and general-purpose chat.',
  ),
  detailed(
    openAiMaxTokens: 8192,
    geminiMaxTokens: 8192,
    claudeMaxTokens: 4096,
    displayName: 'Detailed',
    description:
        'Best for long-form content, analyzing documents or generating code.',
  ),
  maximum(
    openAiMaxTokens: 16384,
    geminiMaxTokens: 16384,
    claudeMaxTokens: 8192,
    displayName: 'Maximum',
    description:
        'Ideal for extensive research articles or generating large code files.',
  );

  final int openAiMaxTokens;
  final int geminiMaxTokens;
  final int claudeMaxTokens;
  final String displayName;
  final String description;

  const ResponseLength({
    required this.openAiMaxTokens,
    required this.geminiMaxTokens,
    required this.claudeMaxTokens,
    required this.displayName,
    required this.description,
  });

  /// Default token limit (defaults to OpenAI token bound for backward compatibility).
  int get maxTokens => openAiMaxTokens;

  /// Returns the token limit for a specific provider.
  int tokensFor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return openAiMaxTokens;
      case AiProviderId.gemini:
        return geminiMaxTokens;
      case AiProviderId.claude:
        return claudeMaxTokens;
    }
  }

  static ResponseLength fromValue(int value) {
    return ResponseLength.values.firstWhere(
      (e) => e.maxTokens == value,
      orElse: () => ResponseLength.balanced,
    );
  }

  static ResponseLength fromName(String name) {
    return ResponseLength.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ResponseLength.balanced,
    );
  }
}

/// Extension providing safe access to provider token ceilings on nullable [ResponseLength].
extension ResponseLengthNullableExtension on ResponseLength? {
  int get openAiMaxTokens => (this ?? ResponseLength.balanced).openAiMaxTokens;
  int get geminiMaxTokens => (this ?? ResponseLength.balanced).geminiMaxTokens;
  int get claudeMaxTokens => (this ?? ResponseLength.balanced).claudeMaxTokens;
}

// =============================================================================
// AI PREFERENCE CAPABILITY ENUMS
// =============================================================================

/// Identifies a single configurable preference control in the AI preferences UI.
///
/// The [AiModelCapabilityProfile] for each provider holds a [Set] of these values
/// that are visible/supported. The [ProfileAiPreferencesPanel] renders controls
/// conditionally based on this set, so unsupported options are never shown to the
/// user for a given provider.
///
/// [ProviderRegistry.sanitizePreferences] also uses this to strip controls that
/// are not supported from the effective request preferences before [AiRequest] is built.
enum AiPreferenceControl {
  /// Preferred AI provider selection.
  preferredProvider,

  /// Max output token bound (short / balanced / detailed / maximum).
  responseLength,

  /// Generated image pixel dimensions — currently OpenAI-only (e.g. 1024x1024).
  imageSize,

  /// Generated image quality tier — currently OpenAI-only (low / medium / high).
  imageQuality,

  /// Generated image background style — currently OpenAI-only (auto / opaque / transparent).
  imageBackground,

  /// Number of images to generate per request — currently OpenAI-only.
  imageCount,

  /// Max number of vision images the user can attach per message.
  visionImageCount,

  /// Max number of PDF documents the user can attach per message.
  visionPdfCount,

  /// Resolution level hint for vision image analysis — currently OpenAI-only.
  visionDetailLevel,

  /// Gemini-specific: controls aspect_ratio in response_format (e.g. 1:1, 16:9).
  /// Only exposed for Gemini image generation — OpenAI uses pixel-based [imageSize] instead.
  geminiAspectRatio,

  /// Gemini-specific: controls image_size tier in response_format (1K / 2K / 4K).
  /// Only exposed for Gemini image generation.
  geminiImageSize,

  /// Gemini-specific: controls reasoning thinking level (low / medium / high).
  /// Exposed for Gemini 3.8 Flash text generation.
  geminiThinkingLevel,
}

// =============================================================================
// GEMINI THINKING CONFIG ENUMS
// =============================================================================

/// Thinking level for Gemini 3.8 models (reasoning budget and depth).
///
/// Sent as `thinkingLevel` within `thinkingConfig` in `generationConfig`.
///
/// Supported levels for gemini-3.8-flash:
///   - low: Fastest response with minimal reasoning tokens (low cost/latency).
///   - medium: Balanced reasoning (Google's default setting).
///   - high: Deep reasoning for complex math, coding, and multi-step logic.
/// Note: `minimal` is explicitly NOT supported by gemini-3.8-flash (returns 400).
enum GeminiThinkingLevel {
  /// Low reasoning depth — fast response, minimal thinking tokens
  low('low', 'Low', 'Fastest response with minimal reasoning tokens'),

  /// Medium reasoning depth — balanced quality and speed (Default)
  medium('medium', 'Medium', 'Balanced reasoning for everyday tasks (Default)'),

  /// High reasoning depth — deep reasoning for complex problems
  high('high', 'High', 'Deep reasoning for complex math, coding & logic');

  /// Value sent to the Gemini API in `generationConfig.thinkingConfig.thinkingLevel`.
  final String apiValue;

  /// Human-readable display name shown in the UI.
  final String displayName;

  /// Brief explanation of the thinking level behavior.
  final String description;

  const GeminiThinkingLevel(this.apiValue, this.displayName, this.description);

  /// Safe deserialization from storage string or API value.
  static GeminiThinkingLevel fromString(String? value) {
    if (value == null || value.isEmpty) return GeminiThinkingLevel.medium;
    final lower = value.toLowerCase();
    return GeminiThinkingLevel.values.firstWhere(
      (e) => e.apiValue == lower || e.name == lower,
      orElse: () => GeminiThinkingLevel.medium,
    );
  }
}

// =============================================================================
// GEMINI IMAGE GENERATION ENUMS
// =============================================================================

/// Image resolution tier for Gemini image generation requests.
///
/// Sent as the `image_size` field inside `response_format` in the Gemini
/// Interactions API. Gemini uses named tiers (1K / 2K / 4K) rather than
/// exact pixel dimensions.
///
/// Available tiers per model:
///   gemini-3.1-flash-image: 512px (0.5K), 1K, 2K, 4K
///   gemini-3.1-pro-image:   1K, 2K, 4K
///
/// The app exposes 1K, 2K, and 4K as user-selectable options. 0.5K (512px)
/// is omitted because it is not a practical default for AI-generated content.
enum GeminiImageSize {
  /// 1K resolution — e.g. 1024×1024 for 1:1, scales with ratio.
  oneK('1K', '1K', 'Standard quality, best for general use (e.g. 1024x1024)'),

  /// 2K resolution — e.g. 2048×2048 for 1:1, higher quality.
  twoK('2K', '2K', 'High quality, ideal for detailed images (e.g. 2048x2048)'),

  /// 4K resolution — e.g. 4096×4096 for 1:1, highest quality, costs more tokens.
  fourK('4K', '4K', 'Ultra high quality, uses more tokens (e.g. 4096x4096)');

  /// Value sent to the Gemini API in the `image_size` field.
  final String apiValue;

  /// Human-readable label for the UI.
  final String displayName;

  /// Description of the size tier for the UI.
  final String description;

  const GeminiImageSize(this.apiValue, this.displayName, this.description);

  static GeminiImageSize fromValue(String value) {
    return GeminiImageSize.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => GeminiImageSize.oneK,
    );
  }
}

/// Aspect ratio for Gemini image generation requests.
///
/// Sent as the `aspect_ratio` field inside `response_format` in the Gemini
/// Interactions API. The app exposes the most common ratios that cover
/// standard mobile/social/web use cases.
enum GeminiAspectRatio {
  /// 9:16 portrait — best for mobile and vertical content.
  portrait('9:16', 'Portrait (9:16)'),

  /// 1:1 square — universal default, suitable for all social platforms.
  square('1:1', 'Square (1:1)'),

  /// 16:9 landscape — best for wide banners and widescreen content.
  landscape('16:9', 'Landscape (16:9)');

  /// Value sent to the Gemini API in the `aspect_ratio` field.
  final String apiValue;

  /// Human-readable label for the UI.
  final String displayName;

  const GeminiAspectRatio(this.apiValue, this.displayName);

  static GeminiAspectRatio fromValue(String value) {
    return GeminiAspectRatio.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => GeminiAspectRatio.square,
    );
  }
}

// =============================================================================
// IMAGE DOWNLOAD ENUMS
// =============================================================================

/// UI state for a single image download operation.
enum ImageDownloadState {
  /// No active download for this image key.
  idle,

  /// A download is in progress — button shows a loading indicator.
  loading,

  /// Save completed successfully — button briefly shows a check icon.
  success,

  /// Save failed — button returns to idle and shows an error message.
  failed,
}

/// Typed result returned by [DeviceImageSaveService.saveImageBytes].
enum DeviceImageSaveResult {
  /// Image was written to the device gallery/Photos successfully.
  success,

  /// The user denied Photos/storage permission when the save was attempted.
  permissionDenied,

  /// A network or download step failed (remote URL could not be fetched).
  networkFailure,

  /// The image bytes are empty or cannot be decoded as a known image type.
  invalidImage,

  /// The device has no storage space available.
  noSpace,

  /// Any other platform error (MediaStore failure, Photos library error, etc.).
  unknown,
}
