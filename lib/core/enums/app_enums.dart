/// AI provider identifiers used throughout the orchestration system.
///
/// These match the provider IDs stored in Firestore and fired in analytics.
enum AiProviderId {
  openAi(
    'openai',
    'ChatGPT',
    '• GPT Image Gen \n• GPT-4o Text/Vision/PDF',
  ),
  gemini(
    'gemini',
    'Gemini',
    '• Gemini Image Gen \n• Gemini 2.5 Flash Text/Vision/PDF',
  ),
  claude('claude', 'Claude', '• Claude Sonnet Text/Vision/PDF');

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
  textGeneration('text_generation', 'Text Chat'),

  /// Generate an image from a text description
  imageGeneration('image_generation', 'Image Generation'),

  /// Analyze and describe an uploaded image
  imageUnderstanding('image_understanding', 'Image Reading'),

  /// Extract text from a PDF and answer questions about it
  pdfParsing('pdf_parsing', 'PDF Reading'),

  /// Convert speech audio to text
  speechToText('speech_to_text', 'Voice Input'),

  /// Convert text to spoken audio
  textToSpeech('text_to_speech', 'Voice Output');

  final String id;
  final String displayName;

  const AiCapability(this.id, this.displayName);
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
      orElse: () => ThemeType.system,
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

/// Conversation type — determines which feature screen opened it.
enum ConversationCapability {
  textChat('text_generate'),
  imageGeneration('image_generate'),
  imageReading('image_read'),
  pdfReader('pdf_reader');

  final String value;
  const ConversationCapability(this.value);

  static ConversationCapability fromValue(String value) {
    return ConversationCapability.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConversationCapability.textChat,
    );
  }
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
