/// Firestore collection and field name constants for AI Voice Genie.
///
/// Every Firestore path must reference constants from here.
/// Prevents typos in collection names across the codebase.
///
/// Schema:
///   AI_Voice_Genie/                             ← root collection
///     AI_Conversations/                          ← namespace document
///       {uid}/                                   ← user's conversations (collection)
///         {conversationId}/                      ← conversation metadata (document)
///           messages/                            ← messages subcollection
///             {messageId}                        ← prompt + response pair (document)
///     Users/
///       User_Model/
///         {uid}                                  ← user profile (document)
///     Users_API_Keys/
///       {uid}/
///         {providerId}                           ← API key (document)
class FirebaseCollections {
  // ── Root Collection ───────────────────────────────────────────────────────
  // MUST be the app name — defined once here, never hardcoded elsewhere
  static const String root = 'AIVoiceGenie';

  // ── Subcollection/Document Names ───────────────────────────────────────────────────
  static const String users = 'AllUsers';
  static const String userModel = 'UserModel';
  static const String conversations = 'Conversations';
  static const String messages = 'ModelMessages';
  static const String apiKeys = 'UsersAPIKeys';

  // ── Firestore Path Builders ───────────────────────────────────────────────
  // Use these everywhere instead of manually constructing paths.
  //
  // Firestore requires strictly alternating collection/document segments:
  //   collection / document / collection / document / ...
  //
  // Schema:
  //   AI_Voice_Genie (collection) → Users (doc) → User_Model (collection) → {uid} (doc)
  //   AI_Voice_Genie (collection) → Users_API_Keys (doc) → {uid} (collection) → {providerId} (doc)
  //   AI_Voice_Genie (collection) → AI_Conversations (doc) → {uid} (collection) → {conversationId} (doc)
  //     → messages (collection) → {messageId} (doc)

  /// Path: AIVoiceGenie/AllUsers/{uid}
  static String userDoc(String uid) => '$root/$users/$uid/$userModel';

  /// Path: AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}
  static String apiKeyDoc(String uid, String providerId) =>
      '$root/$apiKeys/$uid/$providerId';

  /// Collection path for all conversations of a user:
  /// AI_Voice_Genie/AI_Conversations/{uid}
  static String conversationsCollection(String uid) =>
      '$root/$conversations/$uid';

  /// Path: AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}
  static String conversationDoc(String uid, String conversationId) =>
      '$root/$conversations/$uid/$conversationId';

  /// Collection path for messages within a conversation:
  /// AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}/messages
  static String messagesCollection(String uid, String conversationId) =>
      '$root/$conversations/$uid/$conversationId/$messages';

  /// Path: AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}/messages/{message/response Id}
  static String messageDoc(
          String uid, String conversationId, String messageId) =>
      '$root/$conversations/$uid/$conversationId/$messages/$messageId';

  // ── User Document Field Names ─────────────────────────────────────────────
  static const String fieldDisplayName = 'displayName';
  static const String fieldEmail = 'email';
  static const String fieldPhotoUrl = 'photoUrl';
  // Value: 'google' | 'apple'
  static const String fieldAuthProvider = 'authProvider';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldLastLoginAt = 'lastLoginAt';
  static const String fieldLastUpdatedAt = 'lastUpdatedAt';
  static const String fieldOnboardingDone = 'onboardingDone';
  static const String fieldKeySetupDone = 'keySetupDone';
  static const String fieldDateOfBirth = 'dateOfBirth';
  static const String fieldAge = 'age';
  static const String fieldPreferredAiModel = 'preferredAiModel';
  static const String fieldPreferredProvider = 'preferredProvider';
  static const String fieldDailyQuotaUsed = 'dailyQuotaUsed';
  static const String fieldDailyQuotaLimit = 'dailyQuotaLimit';
  static const String fieldNewUser = 'isNewUser';

  // ── API Key Document Field Names ──────────────────────────────────────────
  static const String fieldApiKey = 'apiKey';
  static const String fieldProviderId = 'aiProviderId';
  static const String fieldProviderModelFeatures = 'aiProviderModelFeatures';
  static const String fieldKeyAddedAt = 'keyAddedAt';
  static const String fieldKeyIsValid = 'isValid';
  static const String fieldKeyLastValidated = 'lastValidated';

  // ── Conversation Document Field Names ─────────────────────────────────────
  static const String fieldConversationID = 'conversationID';
  static const String fieldConversationTitle = 'title';
  static const String fieldConversationCreatedAt = 'createdAt';
  static const String fieldConversationUpdatedAt = 'updatedAt';
  static const String fieldConversationMessageCount = 'messageCount';
  static const String fieldConversationLastMessage = 'lastMessage';
  static const String fieldConversationLastMessageAt = 'lastMessageAt';
  // Value: 'text' | 'image_gen' | 'image_read' | 'pdf_reader'
  static const String fieldConversationCapability = 'capability';
  static const String fieldConversationLastProvider = 'lastProvider';

  // ── Message Pair Document Field Names ─────────────────────────────────────
  // Each message document stores a prompt + response pair together.
  //
  // Document layout:
  //   { prompt, response, modelUsed, tokenCount, contentType,
  //     status, timestamp, imageUrl?, pdfName? }
  static const String fieldPrompt = 'prompt';
  static const String fieldResponse = 'response';
  static const String fieldModelUsed = 'modelUsed';
  static const String fieldTokenCount = 'tokenCount';
  // Value: 'text' | 'image_url' | 'pdf_summary' | 'voice_transcript'
  static const String fieldContentType = 'contentType';
  // Value: 'delivered' | 'failed'
  static const String fieldStatus = 'status';
  static const String fieldTimestamp = 'timestamp';
  static const String fieldImageUrl = 'imageUrl';
  static const String fieldPdfName = 'pdfName';
  static const String fieldPdfInfo = 'pdfInfo';
  static const String fieldValidProviders = 'validProviders';
  static const String fieldImageSize = 'imageSize';
  static const String fieldImageCount = 'imageCount';
  static const String fieldImageQuality = 'imageQuality';

  // ── Legacy Message Field Names (used by Hive cache serialization) ─────────
  static const String fieldMessageID = 'messageID';
  static const String fieldMessageRole = 'role';
  static const String fieldMessageContent = 'content';
  static const String fieldMessageContentType = 'contentType';
  static const String fieldMessageTimestamp = 'timestamp';
  static const String fieldMessageModelUsed = 'modelUsed';
  static const String fieldMessageTokenCount = 'tokenCount';
  static const String fieldMessageStatus = 'status';
  static const String fieldMessageImageUrl = 'imageUrl';
  static const String fieldMessageLocalImageKey = 'localImageKey';
  static const String fieldMessagePdfName = 'pdfName';
  static const String fieldMessagePdfPaths = 'pdfPaths';
  static const String fieldMessagePdfInfo = 'pdfInfo';
  static const String fieldMessageValidProviders = 'validProviders';

  // ── Analytics Event Names ─────────────────────────────────────────────────
  static const String eventAuthenticationButtonTapped =
      'authentication_button_tapped';
  static const String eventUserSignedIn = 'user_signed_in';
  static const String eventUserRegistered = 'user_registered';
  static const String eventUserSignedOut = 'user_signed_out';
  static const String eventAiRequestInitiated = 'ai_request_initiated';
  static const String eventAiRequestSuccess = 'ai_request_success';
  static const String eventAiRequestFailed = 'ai_request_failed';
  static const String eventAiFallbackTriggered = 'ai_fallback_triggered';
  static const String eventAiCapabilityGap = 'ai_capability_gap';
  static const String eventFeatureUsed = 'feature_used';
  static const String eventModelAdded = 'ai_model_added';
  static const String eventModelRemoved = 'ai_model_removed';
  static const String eventModelSwitched = 'model_switched';
  static const String eventConversationStarted = 'conversation_started';
  static const String eventVoiceInputUsed = 'voice_input_used';
  static const String eventVoiceOutputUsed = 'voice_output_used';

  // ── Analytics Parameter Names ─────────────────────────────────────────────
  static const String paramAuthProvider = 'auth_provider';
  static const String paramModelAttempted = 'model_attempted';
  static const String paramModelUsed = 'model_used';
  static const String paramCapability = 'request_capability';
  static const String paramFailureType = 'failure_type';
  static const String paramFailureReason = 'failure_reason';
  static const String paramFromModel = 'from_model';
  static const String paramToModel = 'to_model';
  static const String paramReason = 'reason';
  static const String paramFeature = 'feature';
  static const String paramResponseTimeMs = 'response_time_ms';
  static const String paramTokenCount = 'token_count';
  static const String paramModelName = 'model_name';
  static const String paramModelFeatures = 'model_features';
  static const String paramUserId = 'user_id';
  static const String paramUserEmail = 'user_email';
  /// Shared request ID linking initiated/success/failure events to the usage event.
  static const String paramRequestId = 'request_id';

  // ── Usage Tracking Collection Names ───────────────────────────────────────
  static const String usageEvents = 'usageEvents';
  static const String usageSummaries = 'usageSummaries';
  static const String usageBudgets = 'usageBudgets';

  // ── Usage Tracking Path Builders ─────────────────────────────────────────

  /// AI_Voice_Genie/Users/User_Model/{uid}/usageEvents
  static String usageEventsCollection(String uid) =>
      '$root/$users/$uid/$userModel/$usageEvents';

  /// AI_Voice_Genie/Users/User_Model/{uid}/usageSummaries/{docId}
  static String usageSummaryDoc(String uid, String docId) =>
      '$root/$users/$uid/$userModel/$usageSummaries/$docId';

  /// AI_Voice_Genie/Users/User_Model/{uid}/usageSummaries
  static String usageSummariesCollection(String uid) =>
      '$root/$users/$uid/$userModel/$usageSummaries';

  /// AI_Voice_Genie/Users/User_Model/{uid}/usageBudgets/{providerId}
  static String usageBudgetDoc(String uid, String providerId) =>
      '$root/$users/$uid/$userModel/$usageBudgets/$providerId';

  /// AI_Voice_Genie/Users/User_Model/{uid}/usageBudgets
  static String usageBudgetsCollection(String uid) =>
      '$root/$users/$uid/$userModel/$usageBudgets';

  // ── Usage Event Field Names ──────────────────────────────────────────────
  static const String usageFieldId = 'id';
  static const String usageFieldProvider = 'provider';
  static const String usageFieldModel = 'model';
  static const String usageFieldCapability = 'capability';
  static const String usageFieldRequestId = 'requestId';
  static const String usageFieldConversationId = 'conversationId';
  static const String usageFieldMessageId = 'messageId';
  static const String usageFieldInputTokens = 'inputTokens';
  static const String usageFieldOutputTokens = 'outputTokens';
  static const String usageFieldTotalTokens = 'totalTokens';
  static const String usageFieldImageCount = 'imageCount';
  static const String usageFieldPdfCount = 'pdfCount';
  static const String usageFieldEstimatedCostUsd = 'estimatedCostUsd';
  static const String usageFieldCreatedAt = 'createdAt';
  static const String usageFieldUpdatedAt = 'updatedAt';
  static const String usageFieldMonthKey = 'monthKey';

  // ── Usage Summary Field Names (on top of shared usage fields above) ──────
  static const String summaryFieldRequestCount = 'requestCount';
  static const String summaryFieldEstimatedCostUsd = 'estimatedCostUsd';

  // ── Budget Field Names ───────────────────────────────────────────────────
  static const String budgetFieldMonthlyBudgetUsd = 'monthlyBudgetUsd';
  static const String budgetFieldEnabled = 'enabled';
}
