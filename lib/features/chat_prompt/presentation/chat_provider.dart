import 'dart:async';

import 'package:ai_voice_genie/core/extensions/string_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/models/ai_response.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/error/effect_bus.dart';
import '../../../core/services/analytics_service.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_attachment.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

/// State manager for the chat feature.
///
/// Manages:
///   - Active conversation state (messages, metadata)
///   - Sending prompts via AiOrchestrator
///   - Loading + paginating messages
///   - Hive cache sync
///   - Optimistic UI (user message shown immediately before AI responds)
///
/// Usage:
/// ```dart
/// // Start or resume a conversation
/// await chatProvider.loadConversation(uid, conversationId);
///
/// // Send a message
/// await chatProvider.sendMessage(
///   uid: uid,
///   prompt: 'Hello!',
///   selectedProvider: selectedProvider,
/// );
/// ```
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;
  final AiOrchestrator _orchestrator;
  final AnalyticsService _analytics;

  ChatProvider({
    ChatRepository? repository,
    AiOrchestrator? orchestrator,
    AnalyticsService? analytics,
  })  : _repository = repository ?? ChatRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _analytics = analytics ?? AnalyticsService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  ConversationModel? _activeConversation;
  final List<MessageModel> _messages = [];
  bool _isGenerating = false;
  bool _isLoadingMessages = false;
  String? _errorMessage;

  ConversationModel? get activeConversation => _activeConversation;
  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get errorMessage => _errorMessage;
  bool get hasActiveConversation => _activeConversation != null;

  // ── Load Conversation ──────────────────────────────────────────────────────

  /// Load an existing conversation by ID.
  ///
  /// Strategy:
  ///   1. Load from Hive cache instantly (fast path)
  ///   2. Fetch ALL messages from Firestore in background (fresh data)
  ///   3. Firestore result replaces cache — no pagination needed.
  Future<void> loadConversation({
    required String uid,
    required String conversationId,
  }) async {
    _isLoadingMessages = true;
    _errorMessage = null;
    _activeConversation = null;
    notifyListeners();

    try {
      // Fast path: load from Hive cache instantly
      final cached = await _repository.getCachedMessages(conversationId);
      if (cached.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(cached);
        _isLoadingMessages = false;
        notifyListeners();
      }

      // Fresh path: load ALL messages and conversation details from Firestore
      final results = await Future.wait([
        _repository.getMessages(
          uid: uid,
          conversationId: conversationId,
        ),
        _repository.getConversation(uid, conversationId),
      ]);

      final freshMessages = results[0] as List<MessageModel>;
      final conversationModel = results[1] as ConversationModel?;

      if (conversationModel != null) {
        _activeConversation = conversationModel;
      }

      _messages
        ..clear()
        ..addAll(freshMessages);

      // Update cache with fresh data
      await _repository.cacheMessages(
        conversationId: conversationId,
        messages: _messages,
      );
    } catch (e) {
      debugPrint('⚠️ ChatProvider.loadConversation error: $e');
      _errorMessage = 'something_went_wrong';
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  // ── Send Message ───────────────────────────────────────────────────────────

  /// Send a user prompt and receive an AI response.
  ///
  /// [uid]              — current user's Firebase UID
  /// [prompt]           — the user's message text
  /// [selectedProvider] — provider selected for this single request
  /// [capability]       — defaults to textGeneration (chat). Override for image/PDF.
  ///
  /// Returns true on success, false on failure.
  Future<void> sendMessage({
    required String uid,
    required String prompt,
    required AiProviderId? selectedProvider,
    ConversationCapability capability = ConversationCapability.textChat,
    ChatAttachment? attachment,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && attachment == null) return;

    _errorMessage = null;
    final requestCapability = _resolveRequestCapability(
      prompt: trimmedPrompt,
      attachment: attachment,
    );
    final conversationCapability = _resolveConversationCapability(
      requestCapability: requestCapability,
      fallback: capability,
    );
    final effectivePrompt = _effectivePrompt(
      prompt: trimmedPrompt,
      attachment: attachment,
    );
    final selectedProviders =
        selectedProvider == null ? const <AiProviderId>[] : [selectedProvider];

    // ── Step 1: Optimistic user message ──────────────────────────────────────
    final userMessage = MessageModel.userMessage(
      trimmedPrompt,
      validProviders: selectedProviders,
      contentType: _userContentTypeFor(attachment),
      imageUrl: attachment?.isImage == true ? attachment!.path : null,
      pdfName: attachment?.isPdf == true ? attachment!.name : null,
    );
    _messages.add(userMessage);
    _isGenerating = true;
    notifyListeners();

    // ── Step 2: Create conversation if this is the first message ──────────────
    final isNewConversation = _activeConversation == null;
    ConversationModel? newConversation;
    if (isNewConversation) {
      try {
        // Build the conversation model in memory — written to Firestore
        // together with the first message pair in one batch (Step 6)
        final conversationId = const Uuid().v4();
        newConversation = ConversationModel(
          id: conversationId,
          title: '', // Empty initially to show shimmer
          lastMessage: _conversationPreview(effectivePrompt, attachment),
          capability: conversationCapability,
          lastProvider: selectedProvider,
        );
        _activeConversation = newConversation;
        unawaited(_analytics.logConversationStarted(
          capability: conversationCapability,
          provider: selectedProvider ?? AiProviderId.openAi,
        ));
      } catch (e) {
        // Conversation creation failed — roll back and show error
        _isGenerating = false;
        _errorMessage = 'something_went_wrong';
        notifyListeners();
      }
    }

    // ── Step 3: Build context-aware history ───────────────────────────────────
    final history = _buildTruncatedHistory();

    MessageModel? aiMessage;

    // ── Step 4: Execute via orchestrator ─────────────────────────────────────
    try {
      // Replace optimistic user message with confirmed version
      final optimisticIndex =
          _messages.indexWhere((m) => m.id == userMessage.id);
      if (optimisticIndex != -1) {
        _messages[optimisticIndex] = userMessage.copyWith(
          status: MessageStatus.delivered,
          isOptimistic: false,
        );
      }

      if (isNewConversation) {
        final actualTitle = effectivePrompt.generateConversationTitle();
        _activeConversation = _activeConversation!.copyWith(title: actualTitle);
      }

      final aiResponse = await _orchestrator.execute(
        request: AiRequest(
          capability: requestCapability,
          uid: uid,
          prompt: effectivePrompt,
          conversationHistory: history,
          imageBytes: attachment?.isImage == true ? attachment!.bytes : null,
          imageMimeType:
              attachment?.isImage == true ? attachment!.mimeType : null,
          pdfText: attachment?.isPdf == true ? attachment!.extractedText : null,
          pdfFileName: attachment?.isPdf == true ? attachment!.name : null,
        ),
        selectedProvider: selectedProvider,
      );

      // ── Step 5: Add AI response to list ──────────────────────────────────
      aiMessage = _buildAiMessage(aiResponse, attachment: attachment);

      _messages.add(aiMessage);
      notifyListeners();

      // Step 6 to 8 follow in finally, because whether the response is success or fail it has to store.
    } on AiExhaustedException catch (e) {
      // All providers failed — EffectBus already emitted by orchestrator
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
      );
      _messages.add(aiMessage);
      notifyListeners();
    } on AiException catch (e) {
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
      );
      _messages.add(aiMessage);
      notifyListeners();
    } catch (e) {
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
      );
      _messages.add(aiMessage);
      notifyListeners();
    } finally {
      final messageToPersist = aiMessage;
      final conversationToPersist = _activeConversation;

      if (messageToPersist != null && conversationToPersist != null) {
        // ── Step 6: Persist to Firestore (non-blocking side effect) ──────────
        final conversationId = conversationToPersist.id;
        await EffectBus.instance.safeEffect(() async {
          await _repository.saveMessagePair(
            uid: uid,
            conversationId: conversationId,
            userMessage: userMessage.copyWith(
              status: MessageStatus.delivered,
            ),
            aiMessage: messageToPersist,
            isFirstMessage: isNewConversation,
            conversationModel: isNewConversation ? conversationToPersist : null,
          );
        });

        // ── Step 7: Update Hive cache ───────────────────────────────────────
        await EffectBus.instance.safeEffect(() async {
          await _repository.cacheMessages(
            conversationId: conversationId,
            messages: _messages,
          );
        });
      }

      _isGenerating = false;
      notifyListeners();
    }
  }

  // ── Delete Conversation ────────────────────────────────────────────────────

  /// Permanently delete a conversation from Firestore and the local Hive cache.
  ///
  /// Accepts an explicit [conversationId] so this works correctly whether called
  /// from the active [ChatDetailScreen] (new chat flow) or directly from the
  /// [ConversationHistoryScreen] (where [_activeConversation] may differ).
  ///
  /// After deletion:
  ///   - If the deleted conversation was the currently active one, local state
  ///     is cleared so the UI returns to a clean "new chat" state.
  ///   - Otherwise, only Firestore + cache are cleaned up; in-memory state for
  ///     the active conversation is left untouched.
  ///
  /// Returns true on success, false on failure.
  Future<bool> deleteConversation({
    required String uid,
    required String conversationId,
  }) async {
    try {
      await _repository.deleteConversation(
        uid: uid,
        conversationId: conversationId,
      );

      // Clear in-memory state only when we deleted the currently active convo
      if (_activeConversation?.id == conversationId) {
        clearConversation();
      }

      return true;
    } on ChatException {
      return false;
    } catch (e) {
      debugPrint('⚠️ ChatProvider.deleteConversation error: $e');
      return false;
    }
  }

  // ── Clear State ────────────────────────────────────────────────────────────

  /// Reset all state — called when starting a new conversation.
  void clearConversation() {
    _activeConversation = null;
    _messages.clear();
    _isGenerating = false;
    _isLoadingMessages = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Consume and clear the error message after it has been shown.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Build conversation history array for AI context, truncated to fit
  /// within 70% of the selected provider's context window.
  List<Map<String, String>> _buildTruncatedHistory() {
    // Exclude the last (optimistic) user message — it's sent as the prompt
    final historyMessages = _messages
        .where((m) => !m.isOptimistic)
        .map((m) => m.toHistoryEntry())
        .toList();

    if (historyMessages.isEmpty) return [];

    // Estimate total token count
    int totalChars = historyMessages.fold<int>(
      0,
      (sum, msg) => sum + (msg['content']?.length ?? 0),
    );

    // Apply safety margin — use 70% of the smallest provider's limit
    const safetyMargin = AppConstants.contextSafetyMargin;
    const charsPerToken = AppConstants.charsPerToken;
    final maxTokens =
        (AppConstants.openAiContextTokenLimit * safetyMargin).floor();
    final maxChars = maxTokens * charsPerToken;

    // Truncate oldest messages until within limit
    while (totalChars > maxChars && historyMessages.isNotEmpty) {
      final removed = historyMessages.removeAt(0);
      final removedLen = removed['content']?.length ?? 0;
      totalChars -= removedLen;

      // Safety: if totalChars is still high but we removed something with 0 length,
      // the loop will eventually terminate due to historyMessages.isNotEmpty.
    }

    return historyMessages;
  }

  AiCapability _resolveRequestCapability({
    required String prompt,
    required ChatAttachment? attachment,
  }) {
    if (attachment?.isImage == true) return AiCapability.imageUnderstanding;
    if (attachment?.isPdf == true) return AiCapability.pdfParsing;
    if (_looksLikeImageGenerationPrompt(prompt)) {
      return AiCapability.imageGeneration;
    }
    return AiCapability.textGeneration;
  }

  ConversationCapability _resolveConversationCapability({
    required AiCapability requestCapability,
    required ConversationCapability fallback,
  }) {
    switch (requestCapability) {
      case AiCapability.imageGeneration:
        return ConversationCapability.imageGeneration;
      case AiCapability.imageUnderstanding:
        return ConversationCapability.imageReading;
      case AiCapability.pdfParsing:
        return ConversationCapability.pdfReader;
      case AiCapability.textGeneration:
      case AiCapability.speechToText:
      case AiCapability.textToSpeech:
        return fallback;
    }
  }

  MessageContentType _userContentTypeFor(ChatAttachment? attachment) {
    if (attachment?.isImage == true) return MessageContentType.imageUrl;
    if (attachment?.isPdf == true) return MessageContentType.pdfSummary;
    return MessageContentType.text;
  }

  String _effectivePrompt({
    required String prompt,
    required ChatAttachment? attachment,
  }) {
    if (prompt.isNotEmpty) return prompt;
    if (attachment?.isImage == true) return AppConstants.defaultImageQuestion;
    if (attachment?.isPdf == true) return AppConstants.defaultPdfQuestion;
    return prompt;
  }

  String _conversationPreview(String prompt, ChatAttachment? attachment) {
    if (attachment?.isImage == true) return 'Image: $prompt';
    if (attachment?.isPdf == true) return 'PDF: ${attachment!.name}';
    return prompt;
  }

  MessageModel _buildAiMessage(
    AiResponse response, {
    required ChatAttachment? attachment,
  }) {
    if (response.contentType == AiResponseContentType.imageUrl ||
        response.contentType == AiResponseContentType.imageBase64) {
      final imageUrl = response.imageUrl ??
          (response.imageBase64 == null
              ? null
              : 'data:image/png;base64,${response.imageBase64}');

      return MessageModel.aiResponse(
        content: response.text ?? '',
        modelUsed: response.modelUsed,
        contentType: MessageContentType.imageUrl,
        imageUrl: imageUrl,
        tokenCount: response.tokenCount,
      );
    }

    return MessageModel.aiResponse(
      content: response.text ?? '',
      modelUsed: response.modelUsed,
      contentType: attachment?.isPdf == true
          ? MessageContentType.pdfSummary
          : MessageContentType.text,
      tokenCount: response.tokenCount,
    );
  }

  MessageModel _buildFailedAiMessage({
    required String content,
    required Object error,
    required AiProviderId? selectedProvider,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      modelUsed: _providerForError(error, selectedProvider),
      status: MessageStatus.failed,
    );
  }

  AiProviderId? _providerForError(
    Object error,
    AiProviderId? selectedProvider,
  ) {
    if (error is AiExhaustedException && error.triedProviders.isNotEmpty) {
      return error.triedProviders.last;
    }
    if (error is AiException) return error.provider;
    return selectedProvider;
  }

  String _friendlyAiErrorMessage(Object error) {
    if (error is AiException) return error.message;
    return 'something_went_wrong';
  }

  bool _looksLikeImageGenerationPrompt(String prompt) {
    final lower = prompt.trim().toLowerCase();

    // 1. Explicit exclusions: Questions about capabilities, models, code, or pricing
    final askingAboutCapabilities = RegExp(
      r'\b(do you have|are there|what models|which models|free models|paid models|how to|how do|can you tell me|what is)\b',
    ).hasMatch(lower);

    if (askingAboutCapabilities) return false;

    // 2. Strong match: Verb + nearby image noun + "of", "for", or "with"
    final strongMatch = RegExp(
      r'\b(create|generate|draw|make|design|render|paint|need|want|show me)\b.{0,20}\b(image|picture|photo|art|illustration|poster|logo|wallpaper)\b\s+(of|for|with)\b',
    ).hasMatch(lower);

    if (strongMatch) return true;

    // 3. Command at the very beginning of the prompt
    final commandAtStart = RegExp(
      r'^(can you|could you|please|i want to|i need to)?\s*(create|generate|draw|make|design|render|paint)\b.{0,20}\b(image|picture|photo|art|illustration|poster|logo|wallpaper)\b',
    ).hasMatch(lower);

    if (commandAtStart) return true;

    // 4. Strict visual verbs that strongly imply image generation even without nouns
    final visualVerbAtStart = RegExp(
      r'^(can you|could you|please)?\s*(draw|paint|sketch)\b',
    ).hasMatch(lower);

    if (visualVerbAtStart) return true;

    // 5. Starts directly with describing the image
    final nounAtStart = RegExp(
      r'^(a|an|the|some)?\s*(image|picture|photo|illustration|poster|logo)\s+(of|for)\b',
    ).hasMatch(lower);

    return nounAtStart;
  }
}
