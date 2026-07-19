import 'dart:async';
import 'dart:convert';

import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:ai_voice_genie/core/extensions/string_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/models/ai_response.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/services/ai_preferences_service.dart';
import '../../../core/services/cloudinary_service.dart';
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
  final AiPreferencesService _preferences;
  final EffectBus _effectBus;

  ChatProvider(
      {ChatRepository? repository,
      AiOrchestrator? orchestrator,
      AiPreferencesService? preferences,
      EffectBus? effectBus})
      : _repository = repository ?? ChatRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _preferences = preferences ?? AiPreferencesService.instance,
        _effectBus = effectBus ?? EffectBus.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  ConversationModel? _activeConversation;
  final List<MessageModel> _messages = [];
  bool _isGenerating = false;
  bool _isLoadingMessages = false;
  String? _errorMessage;
  int _conversationHistoryVersion = 0;

  ConversationModel? get activeConversation => _activeConversation;
  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get errorMessage => _errorMessage;
  bool get hasActiveConversation => _activeConversation != null;
  int get conversationHistoryVersion => _conversationHistoryVersion;

  AiImageSize get preferredImageSize => _preferences.preferredImageSize;
  ImageQuality get preferredImageQuality => _preferences.preferredImageQuality;
  int get preferredImageCount => _preferences.preferredImageCount;
  ResponseLength get preferredResponseLength =>
      _preferences.preferredResponseLength;

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
    required AiProviderId selectedProvider,
    List<ChatAttachment> attachments = const [],
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && attachments.isEmpty) return;

    _errorMessage = null;
    final requestCapability = _resolveRequestCapability(
      prompt: trimmedPrompt,
      attachments: attachments,
    );

    // ── Step 1: Optimistic user message ──────────────────────────────────────
    // We add the user message to the UI instantly so the app feels responsive.
    // If the request later fails, this optimistic message will be marked as failed.
    final userMessage = MessageModel.userMessage(
      trimmedPrompt,
      selectedProvider,
      contentType: requestCapability,
      imagePaths: attachments.isNotEmpty && attachments.first.isImage == true
          ? attachments.map((e) => e.path!).toList()
          : null,
      pdfInfo: attachments.isNotEmpty && attachments.first.isPdf == true
          ? attachments
              .map(
                (attachment) => PdfAttachmentInfo(
                  path: attachment.path ?? '',
                  name: attachment.name,
                  fileSizeBytes: attachment.fileSizeBytes ??
                      attachment.bytes.lengthInBytes,
                ),
              )
              .toList()
          : null,
      imageSize: (requestCapability == AiCapability.imageGeneration)
          ? preferredImageSize
          : null,
      imageQuality: (requestCapability == AiCapability.imageGeneration)
          ? preferredImageQuality
          : null,
      imageCount: (requestCapability == AiCapability.imageGeneration)
          ? preferredImageCount
          : null,
    );

    _messages.add(userMessage);
    _isGenerating = true; // Shows the typing indicator in the UI
    notifyListeners();

    // Replace optimistic user message with confirmed version so it persists correctly
    final optimisticIndex = _messages.indexWhere((m) => m.id == userMessage.id);

    // ── Step 2: Create conversation if this is the first message ──────────────
    final isNewConversation = _activeConversation == null;
    ConversationModel? newConversation;
    if (isNewConversation) {
        // Build the conversation model in memory — written to Firestore
        // together with the first message pair in one batch (Step 6)
        final conversationId = const Uuid().v4();
        String actualTitle = trimmedPrompt.generateConversationTitle();

        newConversation = ConversationModel(
          id: conversationId,
          title: actualTitle,
          lastMessage: _conversationPreview(trimmedPrompt, attachments),
          capability: requestCapability,
          lastProvider: selectedProvider,
        );
        _activeConversation = newConversation;
    }

    // ── Step 3: Build context-aware history ───────────────────────────────────
    final history = _buildTruncatedHistory(selectedProvider);

    MessageModel? aiMessage;

    // ── Step 4: Execute via orchestrator ─────────────────────────────────────
    try {
      if (optimisticIndex != -1) {
        _messages[optimisticIndex] = userMessage.copyWith(
          status: MessageStatus.delivered,
          isOptimistic: false,
        );
        notifyListeners();
      }

      final aiResponse = await _orchestrator.execute(
        request: AiRequest(
          capability: requestCapability,
          uid: uid,
          prompt: trimmedPrompt,
          conversationHistory: history,
          responseLength: preferredResponseLength,
          imageSize: (requestCapability == AiCapability.imageGeneration)
              ? preferredImageSize
              : null,
          imageQuality: (requestCapability == AiCapability.imageGeneration)
              ? preferredImageQuality
              : null,
          imageCount: (requestCapability == AiCapability.imageGeneration)
              ? preferredImageCount
              : null,
          imageBytes:
              attachments.isNotEmpty && attachments.first.isImage == true
                  ? attachments.map((e) => e.bytes).toList()
                  : null,
          imageMimeType:
              attachments.isNotEmpty ? attachments.first.mimeType : null,
          pdfBytes: attachments.isNotEmpty && attachments.first.isPdf == true
              ? attachments.map((e) => (e.bytes)).toList()
              : null,
          pdfNames: attachments.isNotEmpty && attachments.first.isPdf == true
              ? attachments.map((e) => e.name).toList()
              : null,
        ),
        selectedProvider: selectedProvider,
      );

      // ── Upload Base64 to Cloudinary ─────────────────────────────────────────
      List<String> uploadedUrls = [];
      if (aiResponse.contentType == AiResponseContentType.imageBase64 &&
          aiResponse.generatedImages != null &&
          aiResponse.generatedImages!.isNotEmpty) {
        final futures = aiResponse.generatedImages!
            .where((img) => img.b64Json != null && img.b64Json!.isNotEmpty)
            .map((img) =>
                CloudinaryService.instance.uploadBase64Image(img.b64Json!));

        // Testing with local images
        // List<String> imageUrls = [
        //   "https://res.cloudinary.com/lukl51sa/image/upload/v1783437057/m2qihiu06fwq4qegqes1.png",
        //   // "https://res.cloudinary.com/lukl51sa/image/upload/v1783437057/m2qihiu06fwq4qegqes1.png",
        //   // "https://res.cloudinary.com/lukl51sa/image/upload/v1783437057/m2qihiu06fwq4qegqes1.png",
        // ];
        // final futures = imageUrls.map((img) => Future.value(img));

        final results = await Future.wait(futures);
        uploadedUrls = results.whereType<String>().toList();
      }

      // ── Step 5: Build AI response message ──────────────────────────────────
      aiMessage = _buildAiMessage(aiResponse,
          attachments: attachments, uploadedUrls: uploadedUrls);

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
    } on AiException catch (e) {
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
      );
    } catch (e) {
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
      );
    } finally {
      final messageToPersist = aiMessage;
      final conversationToPersist = _activeConversation;

      if (messageToPersist != null && conversationToPersist != null) {
        // ── Step 6: Persist to Firestore ──────────────────────────
        final conversationId = conversationToPersist.id;

        // ── Compress Images for Persistence ────────────────────────
        List<String>? persistImagePaths = userMessage.imageUrls;
        if (persistImagePaths != null && persistImagePaths.isNotEmpty) {
          persistImagePaths = await _compressImagesToBase64(persistImagePaths);
        }

        final userMessageToPersist = userMessage.copyWith(
          status: MessageStatus.delivered,
          imageUrls: persistImagePaths,
        );

        // Update in memory so cache also has base64
        if (optimisticIndex != -1) {
          _messages[optimisticIndex] = userMessageToPersist;
        }

        // Isolated Firestore save — a Firestore failure must NOT prevent
        // _isGenerating = false and notifyListeners() from running below.
        // Without this guard, a Firestore exception inside finally would
        // propagate outward, skipping the cleanup code and freezing the UI.
        try {
          await _repository.saveMessagePair(
            uid: uid,
            conversationId: conversationId,
            userMessage: userMessageToPersist,
            aiMessage: messageToPersist,
            isFirstMessage: isNewConversation,
            conversationModel: isNewConversation ? conversationToPersist : null,
          );
        } catch (e) {
          // Log but do not rethrow — we still need to update UI state below.
          debugPrint('⚠️ ChatProvider.saveMessagePair failed: $e');
        }

        // ── Step 7: Update UI with AI response ──────────────────────────────
        _messages.add(messageToPersist);

        // ── Step 8: Update Hive cache ───────────────────────────────────────
        _effectBus.safeEffect(() async {
          await _repository.cacheMessages(
            conversationId: conversationId,
            messages: _messages,
          );
        });

        _markConversationHistoryDirty();
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

      _markConversationHistoryDirty();
      notifyListeners();

      return true;
    } on ChatException {
      return false;
    } catch (e) {
      debugPrint('⚠️ ChatProvider.deleteConversation error: $e');
      return false;
    }
  }

  Future<void> updateConversationTitle(String newTitle, String uid) async {
    if (_activeConversation == null) return;
    try {
      await _repository.updateConversationTitle(
        uid: uid,
        conversationId: _activeConversation!.id,
        newTitle: newTitle,
      );
      _activeConversation = _activeConversation!.copyWith(title: newTitle);
      _markConversationHistoryDirty();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ ChatProvider.updateConversationTitle error: $e');
      rethrow; // Rethrow to let the UI catch and show error toast
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

  /// Builds a truncated conversation history to send as context for the AI prompt.
  ///
  /// AI APIs are stateless, meaning they have no memory of past messages unless
  /// we include the history in every request. However, including too much history
  /// increases token usage and can exceed the model's memory limit (context window),
  /// causing the API request to fail.
  ///
  /// This method acts as a circuit breaker by:
  /// 1. Calculating a safe character limit based on the [selectedProvider]'s token limit.
  /// 2. Ensuring the history only fills up a safe percentage (e.g., 70%) of the
  ///    AI's context window, leaving the rest for the current prompt and the AI's response.
  /// 3. Iteratively forgetting (removing) the oldest messages if the history exceeds
  ///    this calculated safety limit.
  List<Map<String, String>> _buildTruncatedHistory(
      AiProviderId selectedProvider) {
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

    // Apply safety margin — use 70% of the specific provider's limit
    const safetyMargin = AppConstants.contextSafetyMargin;
    const charsPerToken = AppConstants.charsPerToken;

    int providerTokenLimit;
    switch (selectedProvider) {
      case AiProviderId.openAi:
        providerTokenLimit = AppConstants.openAiContextTokenLimit;
        break;
      case AiProviderId.gemini:
        providerTokenLimit = AppConstants.geminiContextTokenLimit;
        break;
      case AiProviderId.claude:
        providerTokenLimit = AppConstants.claudeContextTokenLimit;
        break;
    }

    final maxTokens = (providerTokenLimit * safetyMargin).floor();
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
    List<ChatAttachment> attachments = const [],
  }) {
    if (attachments.isNotEmpty && attachments.first.isImage == true) {
      return AiCapability.imageUnderstanding;
    }
    if (attachments.isNotEmpty && attachments.first.isPdf == true) {
      return AiCapability.pdfParsing;
    }
    if (_looksLikeImageGenerationPrompt(prompt)) {
      return AiCapability.imageGeneration;
    }
    return AiCapability.textGeneration;
  }

  String _conversationPreview(
    String prompt,
    List<ChatAttachment> attachments,
  ) {
    if (attachments.isNotEmpty && attachments.first.isImage == true) {
      return 'Image: $prompt';
    }
    if (attachments.isNotEmpty && attachments.first.isPdf == true) {
      return 'PDF: $prompt';
    }
    return 'Text: $prompt';
  }

  MessageModel _buildAiMessage(
    AiResponse response, {
    List<ChatAttachment> attachments = const [],
    List<String> uploadedUrls = const [],
  }) {
    if (response.contentType == AiResponseContentType.imageBase64) {
      return MessageModel.aiResponse(
        content: response.text ?? '',
        modelUsed: response.modelUsed,
        contentType: AiCapability.imageGeneration,
        imageUrls: uploadedUrls.isNotEmpty ? uploadedUrls : null,
        tokenCount: response.tokenCount,
        imageSize: preferredImageSize,
        imageQuality: preferredImageQuality,
        imageCount: preferredImageCount,
      );
    } else if (response.contentType == AiResponseContentType.analysis) {
      // Determine the specific analysis type from the attachment context
      // (PDF vs image), since the orchestrator returns a generic 'analysis'
      // content type for both.
      final analysisCapability =
          attachments.isNotEmpty && attachments.first.isPdf == true
              ? AiCapability.pdfParsing
              : attachments.isNotEmpty && attachments.first.isImage == true
                  ? AiCapability.imageUnderstanding
                  : AiCapability.textGeneration;
      return MessageModel.aiResponse(
        content: response.text ?? '',
        modelUsed: response.modelUsed,
        contentType: analysisCapability,
        tokenCount: response.tokenCount,
      );
    }

    // Default: plain text generation response
    return MessageModel.aiResponse(
      content: response.text ?? '',
      modelUsed: response.modelUsed,
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
      modelRequest: _providerForError(error, selectedProvider),
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

    // 2. Strong match: Verb + nearby image noun + optional "of", "for", or "with"
    final strongMatch = RegExp(
      r'\b(create|generate|draw|make|design|render|paint|need|want|show me)\b.{0,80}\b(image|picture|photo|art|illustration|poster|logo|wallpaper)\b',
    ).hasMatch(lower);

    if (strongMatch) return true;

    // 3. Command at the very beginning of the prompt
    final commandAtStart = RegExp(
      r'^(can you|could you|please|i want to|i need to)?\s*(create|generate|draw|make|design|render|paint)\b.{0,80}\b(image|picture|photo|art|illustration|poster|logo|wallpaper)\b',
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

  void _markConversationHistoryDirty() {
    _conversationHistoryVersion++;
  }

  Future<List<String>> _compressImagesToBase64(List<String> paths) async {
    final List<String> result = [];
    for (final path in paths) {
      if (path.startsWith('data:image') || path.startsWith('http')) {
        result.add(path); // Already processed or network url
        continue;
      }
      try {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
        );
        if (compressedBytes != null) {
          final base64String = base64Encode(compressedBytes);
          result.add('data:image/jpeg;base64,$base64String');
        } else {
          result.add(path); // Fallback to original if compression fails
        }
      } catch (e) {
        debugPrint('Error compressing image to thumbnail: $e');
        result.add(path); // Fallback
      }
    }
    return result;
  }
}
