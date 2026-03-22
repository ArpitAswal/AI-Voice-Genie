/// Firestore collection and field name constants for AI Voice Genie.
///
/// Every Firestore path must reference constants from here.
/// Prevents typos in collection names across the codebase.
class FirebaseCollections {
  // ── Top-Level Collections ─────────────────────────────────────────────────
  static const String users = 'AiVoiceGenieUsers';

  // ── User Subcollections ───────────────────────────────────────────────────
  // Path: users/{uid}/conversations/{conversationId}
  static const String conversations = 'conversations';

  // Path: users/{uid}/conversations/{conversationId}/messages/{messageId}
  static const String messages = 'messages';

  // Path: users/{uid}/apiKeys/{providerId}
  // Each document stores the API key + metadata for one AI provider
  static const String apiKeys = 'apiKeys';

  // ── User Document Field Names ─────────────────────────────────────────────
  static const String fieldDisplayName = 'displayName';
  static const String fieldEmail = 'email';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldPreferredProvider = 'preferredProvider';
  static const String fieldDailyQuotaUsed = 'dailyQuotaUsed';
  static const String fieldDailyQuotaLimit = 'dailyQuotaLimit';
  static const String fieldQuotaResetDate = 'quotaResetDate';

  // ── API Key Document Field Names ──────────────────────────────────────────
  static const String fieldApiKey = 'apiKey';
  static const String fieldProviderId = 'providerId';
  static const String fieldKeyAddedAt = 'keyAddedAt';
  static const String fieldKeyIsValid = 'isValid';
  static const String fieldKeyLastValidated = 'lastValidated';

  // ── Conversation Document Field Names ─────────────────────────────────────
  static const String fieldConversationTitle = 'title';
  static const String fieldConversationCreatedAt = 'createdAt';
  static const String fieldConversationUpdatedAt = 'updatedAt';
  static const String fieldConversationMessageCount = 'messageCount';
  static const String fieldConversationLastMessage = 'lastMessage';
  static const String fieldConversationLastMessageAt = 'lastMessageAt';
  // Capability type: 'text' | 'image_gen' | 'image_read' | 'pdf_reader'
  static const String fieldConversationCapability = 'capability';
  // Provider used for the last message in this conversation
  static const String fieldConversationLastProvider = 'lastProvider';

  // ── Message Document Field Names ──────────────────────────────────────────
  // Role: 'user' | 'assistant'
  static const String fieldMessageRole = 'role';
  static const String fieldMessageContent = 'content';
  // Content type: 'text' | 'image_url' | 'pdf_summary' | 'voice_transcript'
  static const String fieldMessageContentType = 'contentType';
  static const String fieldMessageTimestamp = 'timestamp';
  static const String fieldMessageModelUsed = 'modelUsed';
  // Estimated token count for context window management
  static const String fieldMessageTokenCount = 'tokenCount';
  // Status: 'sent' | 'delivered' | 'failed' | 'partial'
  static const String fieldMessageStatus = 'status';
  // Optional: image URL if the message contains a generated image
  static const String fieldMessageImageUrl = 'imageUrl';
  // Optional: name of the PDF file if this message references a PDF
  static const String fieldMessagePdfName = 'pdfName';

  // ── Analytics Event Names ──────────────────────────────────────────────────
  // Firebase Analytics event name constants (snake_case, max 40 chars)
  static const String eventAiRequestInitiated = 'ai_request_initiated';
  static const String eventAiRequestSuccess = 'ai_request_success';
  static const String eventAiRequestFailed = 'ai_request_failed';
  static const String eventAiFallbackTriggered = 'ai_fallback_triggered';
  static const String eventAiCapabilityGap = 'ai_capability_gap';
  static const String eventFeatureUsed = 'feature_used';
  static const String eventModelKeyAdded = 'model_key_added';
  static const String eventModelKeyRemoved = 'model_key_removed';
  static const String eventModelSwitched = 'model_switched';
  static const String eventUserSignedIn = 'user_signed_in';
  static const String eventUserRegistered = 'user_registered';
  static const String eventConversationStarted = 'conversation_started';
  static const String eventVoiceInputUsed = 'voice_input_used';
  static const String eventVoiceOutputUsed = 'voice_output_used';

  // ── Analytics Parameter Names ─────────────────────────────────────────────
  static const String paramModelAttempted = 'model_attempted';
  static const String paramModelUsed = 'model_used';
  static const String paramCapability = 'capability';
  static const String paramFailureType = 'failure_type';
  static const String paramFallbackTriggered = 'fallback_triggered';
  static const String paramFromModel = 'from_model';
  static const String paramToModel = 'to_model';
  static const String paramReason = 'reason';
  static const String paramFeature = 'feature';
  static const String paramResponseTimeMs = 'response_time_ms';
  static const String paramTokenCount = 'token_count';
}