import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_voice_genie/core/extensions/string_extension.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/storage_service.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/models/ai_response.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/services/ai_preferences_service.dart';
import '../../../core/services/cloud_storage_service.dart';
import '../../../core/services/pdf_document_service.dart';
import '../data/chat_repository_impl.dart';
import '../data/chat_sync_service.dart';
import '../data/local_chat_store.dart';
import '../domain/chat_attachment.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/conversation_page_cursor.dart';
import '../domain/message_model.dart';
import '../domain/message_page_cursor.dart';

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

  ChatProvider({
    ChatRepository? repository,
    AiOrchestrator? orchestrator,
    AiPreferencesService? preferences,
  })  : _repository = repository ?? ChatRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _preferences = preferences ?? AiPreferencesService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  ConversationModel? _activeConversation;
  final List<MessageModel> _messages = [];
  bool _isGenerating = false;
  bool _isLoadingMessages = false;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  MessagePageCursor? _messageCursor;
  String? _errorMessage;
  int _conversationHistoryVersion = 0;

  List<ConversationModel> _visibleConversations = [];
  bool _isLoadingMoreConversations = false;
  bool _hasMoreConversations = true;
  ConversationPageCursor? _conversationCursor;
  String? _searchQuery;

  /// Active subscription to the Hive messages stream for the current conversation.
  /// Cancelled whenever a new conversation is loaded or the provider is disposed.
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<dynamic>? _conversationSubscription;

  ConversationModel? get activeConversation => _activeConversation;
  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingMessages => _isLoadingMessages;

  /// IDs of AI messages that have already run their typewriter animation.
  final Set<String> _animatedMessageIds = {};

  /// Whether a given AI message should run the typewriter animation.
  /// Returns true ONLY if it hasn't animated yet.
  bool shouldAnimateMessage(String messageId) {
    return !_animatedMessageIds.contains(messageId);
  }

  /// Marks an AI message as having completed its typewriter animation so it
  /// never re-animates on ListView scroll recycling.
  void markMessageAnimated(String messageId) {
    _animatedMessageIds.add(messageId);
  }

  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreMessages => _hasMoreMessages;
  String? get errorMessage => _errorMessage;
  int get conversationHistoryVersion => _conversationHistoryVersion;

  List<ConversationModel> get visibleConversations =>
      List.unmodifiable(_visibleConversations);
  bool get isLoadingMoreConversations => _isLoadingMoreConversations;
  bool get hasMoreConversations => _hasMoreConversations;
  String? get searchQuery => _searchQuery;

  /// Resolves the current user's UID.
  ///
  /// Uses [explicitUid] if provided, otherwise looks up from local storage
  /// or the FirebaseAuth session.
  String _resolveUid([String? explicitUid]) {
    if (explicitUid != null && explicitUid.isNotEmpty) {
      return explicitUid;
    }
    final storedUid = StorageService().getUserData<String>(StorageKeys.userId);
    if (storedUid != null && storedUid.isNotEmpty) {
      return storedUid;
    }
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      return authUid;
    }
    throw StateError(
      'User ID could not be resolved. User must be authenticated to chat.',
    );
  }

  // ── Load Conversation ──────────────────────────────────────────────────────

  /// Load an existing conversation by ID.
  ///
  Future<void> loadConversation({
    String? uid,
    required String conversationId,
  }) async {
    final resolvedUid = _resolveUid(uid);
    _isLoadingMessages = true;
    _isGenerating = false;
    _errorMessage = null;
    _activeConversation = null;
    _messages.clear(); // Synchronously clear old messages immediately
    _animatedMessageIds.clear();
    _hasMoreMessages = true;
    _messageCursor = null;
    notifyListeners();

    // Cancel any existing message stream before subscribing to a new conversation
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _conversationSubscription?.cancel();
    _conversationSubscription = null;

    try {
      // 1. Fetch conversation metadata from Local Hive
      final localConv =
          LocalChatStore.instance.getConversation(resolvedUid, conversationId);
      if (localConv != null) {
        _activeConversation = localConv.toConversationModel();
      }

      // 2. Fetch latest page of messages
      final page = await _repository.getLatestMessagePage(
        uid: resolvedUid,
        conversationId: conversationId,
        limit: AppConstants.initialMessageLoadCount,
      );
      _messages.addAll(page.items);
      _animatedMessageIds.addAll(page.items.map((m) => m.messageId));
      _hasMoreMessages = page.hasMore;
      _messageCursor = page.nextCursor as MessagePageCursor?;

      debugPrint("🔄 ChatProvider.loadConversation loaded initial page");
    } catch (e) {
      debugPrint('⚠️ ChatProvider.loadConversation error: $e');
      _errorMessage = 'something_went_wrong';
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }

    _subscribeToMessages(resolvedUid, conversationId);
    _subscribeToConversation(resolvedUid, conversationId);
  }

  void _subscribeToConversation(String uid, String conversationId) {
    _conversationSubscription?.cancel();

    _conversationSubscription = LocalChatStore.instance
        .watchConversation(uid, conversationId)
        .listen((record) {
      if (record == null || record.isDeleted) {
        // Conversation was hard-deleted or soft-deleted remotely.
        // We set _activeConversation to a deleted state, or we just rely on UI checking
        // Actually, if we just call notifyListeners(), ChatDetailScreen will see the update
        // and its getConversation check will trigger the pop!
        notifyListeners();
      } else {
        _activeConversation = record.toConversationModel();
        notifyListeners();
      }
    });
  }

  void _subscribeToMessages(String uid, String conversationId) {
    _messagesSubscription?.cancel();

    var stream = _repository.watchVisibleMessages(
      uid: uid,
      conversationId: conversationId,
      limit: _messages.length < AppConstants.initialMessageLoadCount
          ? AppConstants.initialMessageLoadCount
          : _messages.length,
    );

    _messagesSubscription = stream.listen(
      (messages) {
        if (!_isGenerating) {
          final currentIds = _messages.map((m) => m.messageId).toList();
          final newIds = messages.map((m) => m.messageId).toList();
          final bool listChanged = !listEquals(currentIds, newIds);

          if (listChanged) {
            _messages
              ..clear()
              ..addAll(messages);
            _animatedMessageIds.addAll(messages.map((m) => m.messageId));
            notifyListeners();
          }
        }
      },
      onError: (e) => debugPrint('⚠️ ChatProvider.watchMessages error: $e'),
    );

    ChatSyncService.instance.watchOpenConversation(
      uid,
      conversationId,
      limit: _messages.length < (AppConstants.initialMessageLoadCount * 2)
          ? (AppConstants.initialMessageLoadCount * 2)
          : _messages.length + AppConstants.initialMessageLoadCount, // buffer
    );
  }

  Future<void> loadOlderMessages([String? uid]) async {
    if (_activeConversation == null ||
        _isLoadingMoreMessages ||
        !_hasMoreMessages ||
        _messageCursor == null) {
      return;
    }

    final resolvedUid = _resolveUid(uid);

    _isLoadingMoreMessages = true;
    notifyListeners();

    try {
      // Artificial delay so UI can show the loading spinner for local reads
      await Future.delayed(const Duration(milliseconds: 600));

      final page = await _repository.getOlderMessagePage(
        uid: resolvedUid,
        conversationId: _activeConversation!.id,
        before: _messageCursor!,
        limit: AppConstants.messagePageSize,
      );

      // Prepend older messages
      _messages.insertAll(0, page.items);
      _animatedMessageIds.addAll(page.items.map((m) => m.messageId));
      _hasMoreMessages = page.hasMore;
      _messageCursor = page.nextCursor as MessagePageCursor?;

      // Recreate subscription with new limit so real-time updates don't truncate older messages
      _subscribeToMessages(resolvedUid, _activeConversation!.id);
    } catch (e) {
      debugPrint('⚠️ loadOlderMessages error: $e');
    } finally {
      _isLoadingMoreMessages = false;
      notifyListeners();
    }
  }

  /// Closes the currently active conversation and stops listening to real-time message updates.
  void closeActiveConversation() {
    if (_activeConversation != null) {
      ChatSyncService.instance
          .stopWatchingConversation(_activeConversation!.id);
      _activeConversation = null;
    }
    _animatedMessageIds.clear();
    _messagesSubscription?.cancel();
  }

  // ── Send Message ───────────────────────────────────────────────────────────

  /// Starts a new conversation synchronously, clears previous in-memory conversation state,
  /// and kicks off AI message processing in the background without pre-generating a conversation ID.
  void startNewConversation({
    String? uid,
    required String prompt,
    required AiProviderId selectedProvider,
    List<ChatAttachment> attachments = const [],
  }) {
    clearConversation();
    unawaited(sendMessage(
      uid: uid,
      prompt: prompt,
      selectedProvider: selectedProvider,
      attachments: attachments,
    ));
  }

  /// Send a user prompt and receive an AI response.
  ///
  /// [uid]              — current user's Firebase UID (optional, resolved automatically if omitted)
  /// [prompt]           — the user's message text
  /// [selectedProvider] — provider selected for this single request
  /// [attachments]      — optional media and PDF documents
  /// [conversationId]   — optional target conversation ID (defaults to active conversation ID, or generates one if absent)
  Future<void> sendMessage({
    String? uid,
    required String prompt,
    required AiProviderId selectedProvider,
    String? conversationId,
    List<ChatAttachment> attachments = const [],
  }) async {
    MessageModel? userMessage;
    MessageModel? aiMessage;
    Uint8List? generatedPdfBytes;
    String? generatedPdfFileName;
    List<PdfAttachmentInfo> pdfInfo = [];

    // Step 1: Concurrency Guard.
    // Drop any duplicate or re-entrant invocations immediately while generation is already in flight.
    if (_isGenerating) return;

    final String trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && attachments.isEmpty) return;

    _errorMessage = null;

    // Step 2: Session resolution & text normalization.
    // Resolve user ID and strip polite conversational conversational greetings (e.g., "Hey Genie", "Hello AI")
    // to prevent models from producing redundant conversational echo.
    final String resolvedUid = _resolveUid(uid);
    final String cleanPrompt = trimmedPrompt.stripGreetings();
    final String effectivePrompt =
        cleanPrompt.isNotEmpty ? cleanPrompt : trimmedPrompt;

    // Step 3: Capability detection.
    // Determines whether this request is text generation, vision understanding, PDF parsing,
    // PDF document generation, or image synthesis based on attachments and semantic regex heuristics.
    final AiCapability requestCapability = _resolveRequestCapability(
      prompt: effectivePrompt,
      attachments: attachments,
    );

    final bool isImageGen = requestCapability == AiCapability.imageGeneration;
    final bool isImageUnderstanding =
        requestCapability == AiCapability.imageUnderstanding;
    final bool isOpenAi = selectedProvider == AiProviderId.openAi;
    final bool isGemini = selectedProvider == AiProviderId.gemini;

    // Step 4: Conversation target scoping.
    // Use target conversationId, fallback to active conversation, or create a fresh UUID.
    final String targetConversationId =
        conversationId ?? _activeConversation?.id ?? const Uuid().v4();

    final bool isNewConversation = _activeConversation == null ||
        _activeConversation!.id != targetConversationId;

    try {
      // ── Optimistic user message ──────────────────────────────────────
      // We add the user message to the UI instantly so the app feels responsive.
      // If the request later fails, this optimistic message will be marked as failed.
      userMessage = MessageModel.userMessage(
        lastPrompt: trimmedPrompt,
        provider: selectedProvider,
        requestCapability: requestCapability,
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
        imageSize: (isImageGen && isOpenAi)
            ? _preferences.preferredImageSize(selectedProvider)
            : (isImageGen && isGemini
                ? _geminiRatioToImageSize(
                    _preferences.preferredGeminiAspectRatio(selectedProvider))
                : null),
        imageQuality: (isImageGen && isOpenAi)
            ? _preferences.preferredImageQuality(selectedProvider)
            : null,
        imageBackground: (isImageGen && isOpenAi)
            ? _preferences.preferredImageBackground(selectedProvider)
            : null,
        generateImageRequest: (isImageGen && isOpenAi)
            ? _preferences.preferredImageCount(selectedProvider)
            : (isImageGen && isGemini ? 1 : null),
        visionDetailLevel: (isImageUnderstanding && isOpenAi)
            ? _preferences.preferredVisionDetailLevel(selectedProvider)
            : null,
        responseLength: (requestCapability != AiCapability.imageGeneration)
            ? _preferences.preferredResponseLength(selectedProvider)
            : null,
        thinkingLevel:
            (isGemini && (requestCapability != AiCapability.imageGeneration))
                ? _preferences.preferredGeminiThinkingLevel(selectedProvider)
                : null,
        maxOutputTokens: (requestCapability != AiCapability.imageGeneration)
            ? _preferences
                .preferredResponseLength(selectedProvider)
                .tokensFor(selectedProvider)
            : null,
      );

      _messages.add(userMessage);
      _isGenerating = true; // Shows the typing indicator in the UI
      notifyListeners();

      // ── Resolve or create active conversation synchronously ───────────
      List<Map<String, String>>? historyContext;
      if (isNewConversation) {
        _activeConversation = ConversationModel(
          id: targetConversationId,
          title: '',
          lastMessage: trimmedPrompt.isNotEmpty
              ? trimmedPrompt
              : (attachments.isNotEmpty
                  ? (attachments.first.isImage ? 'Image' : 'PDF Document')
                  : ''),
          capability: requestCapability,
          lastProvider: selectedProvider,
        );
      } else if (requestCapability != AiCapability.imageGeneration) {
        historyContext = _buildTruncatedHistory(selectedProvider);
      }

      // ── Prompt Synthesis for Image Generation (Option A) ─────────────
      // When the user follows up in an ongoing image conversation, synthesize
      // prior visual turns and the user's latest request into a single cohesive visual prompt.
      // The user's typed prompt (trimmedPrompt) remains saved in the database/UI on userMessage,
      // while promptForAiRequest is enriched exclusively for the image generator.
      String promptForAiRequest = effectivePrompt;
      if (isImageGen && !isNewConversation) {
        final priorTurns = _messages
            .where(
                (m) => !m.isOptimistic && m.messageId != userMessage!.messageId)
            .toList();

        if (priorTurns.isNotEmpty) {
          final recentPrior = priorTurns.length > 4
              ? priorTurns.sublist(priorTurns.length - 4)
              : priorTurns;
          final synthesisHistory =
              recentPrior.map((m) => m.toHistoryEntry()).toList();

          try {
            final synthesized = await _orchestrator.synthesizeImagePrompt(
              currentPrompt: effectivePrompt,
              conversationHistory: synthesisHistory,
              provider: selectedProvider,
            );
            if (synthesized != null && synthesized.trim().isNotEmpty) {
              promptForAiRequest = synthesized.trim();
              debugPrint('🎨 Image prompt synthesized: "$promptForAiRequest"');
            }
          } catch (e) {
            // Fail silently without surfacing any error message or interrupting generation
            debugPrint(
                '⚠️ Image prompt synthesis skipped (silent fallback): $e');
          }
        }
      }

      // ── Execute via orchestrator ─────────────────────────────────────

      final aiRequest = AiRequest(
        requestId: userMessage.messageId,
        capability: requestCapability,
        prompt: promptForAiRequest,
        conversationHistory: historyContext ?? const [],
        responseLength: userMessage.responseLength,
        thinkingLevel: userMessage.thinkingLevel,
        geminiAspectRatio: (isGemini && isImageGen)
            ? _preferences.preferredGeminiAspectRatio(selectedProvider)
            : null,
        imageSize: (isOpenAi && isImageGen)
            ? _preferences.preferredImageSize(selectedProvider)
            : null,
        imageQuality: (isOpenAi && isImageGen)
            ? _preferences.preferredImageQuality(selectedProvider)
            : null,
        imageBackground: (isOpenAi && isImageGen)
            ? _preferences.preferredImageBackground(selectedProvider)
            : null,
        imageCount: (isOpenAi && isImageGen)
            ? _preferences.preferredImageCount(selectedProvider)
            : (isGemini && isImageGen ? 1 : null),
        visionDetailLevel: (isOpenAi && isImageUnderstanding)
            ? _preferences.preferredVisionDetailLevel(selectedProvider)
            : null,
        imageBytes: attachments.isNotEmpty && attachments.first.isImage == true
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
      );

      // User request is dispatched to the server/LLM: mark as delivered immediately
      userMessage = userMessage.copyWith(
        status: MessageStatus.delivered,
        isOptimistic: false,
      );
      final dispatchedUserId = userMessage.messageId;
      final userIdx =
          _messages.indexWhere((m) => m.messageId == dispatchedUserId);
      if (userIdx != -1) {
        _messages[userIdx] = userMessage;
      }
      notifyListeners();

      // Step 6: Dispatch request to AI layer in parallel with smart title synthesis.
      // Uses Dart 3 Record (.wait) to execute both Futures concurrently on the event loop
      // without adding latency or blocking the UI thread.
      final Future<String?> titleFuture =
          isNewConversation && effectivePrompt.isNotEmpty
              ? _orchestrator
                  .generateConversationTitle(
                  prompt: effectivePrompt,
                  provider: selectedProvider,
                )
                  .catchError((e) {
                  debugPrint('⚠️ Title generation skipped (non-fatal): $e');
                  return null;
                })
              : Future<String?>.value(null);

      final Future<AiResponse> responseFuture = _orchestrator.execute(
        request: aiRequest,
        selectedProvider: selectedProvider,
      );

      final (String? smartTitle, AiResponse aiResponse) = await (
        titleFuture,
        responseFuture,
      ).wait;

      // Update active conversation title: prefer smartTitle, otherwise use clean local fallback title
      if (isNewConversation && _activeConversation != null) {
        final finalTitle = (smartTitle != null && smartTitle.trim().isNotEmpty)
            ? smartTitle.trim()
            : deriveFallbackTitle(effectivePrompt, attachments);
        _activeConversation = _activeConversation!.copyWith(title: finalTitle);
      }

      // Step 7: Post-render background compilation for specialized media (PDF documents).
      // If the response is a generated PDF document, compile the Markdown to binary PDF locally
      // and update the existing bubble so the PDF card is interactive.
      if (aiResponse.capability == AiCapability.pdfGeneration &&
          aiResponse.text != null &&
          aiResponse.text!.isNotEmpty) {
        final docTitle = PdfDocumentService.extractDocumentTitle(
          effectivePrompt,
          aiResponse.text!,
        );

        try {
          final pdfBytes =
              await PdfDocumentService.instance.compileMarkdownToPdf(
            title: docTitle,
            markdownContent: aiResponse.text!,
          );
          generatedPdfBytes = pdfBytes;

          final cleanFileName = PdfDocumentService.formatFileName(docTitle);
          generatedPdfFileName = cleanFileName;

          final localPath = await PdfDocumentService.instance.savePdfToDevice(
            bytes: pdfBytes,
            fileName: cleanFileName,
          );

          pdfInfo = [
            PdfAttachmentInfo(
              path: localPath ?? '',
              name: cleanFileName,
              fileSizeBytes: pdfBytes.lengthInBytes,
            ),
          ];
        } catch (e) {
          debugPrint('⚠️ ChatProvider: Error compiling PDF locally: $e');
        }
      }

      // Step 8: Build AI response message.
      // Automatically leverages Base64 image data from aiResponse so image generation
      // renders instantly without waiting for cloud uploads or disk writes.
      aiMessage = MessageModel.fromAiResponse(
        aiResponse,
        imageSize: isImageGen ? userMessage.imageSize : null,
        generateImageRequest:
            isImageGen ? userMessage.generateImageRequest : null,
        imageQuality: isImageGen ? userMessage.imageQuality : null,
        imageBackground: isImageGen ? userMessage.imageBackground : null,
        pdfInfo: pdfInfo,
      );
    } catch (e) {
      // Step 9: Error handling.
      // Capture failure message and create a failed AI message bubble so the user sees the error state.
      final friendlyMessage = _friendlyAiErrorMessage(e);
      _errorMessage = friendlyMessage;
      if (isNewConversation &&
          _activeConversation != null &&
          _activeConversation!.title.isEmpty) {
        final fallback = deriveFallbackTitle(effectivePrompt, attachments);
        _activeConversation = _activeConversation!.copyWith(title: fallback);
      }
      aiMessage = _buildFailedAiMessage(
        content: friendlyMessage,
        error: e,
        selectedProvider: selectedProvider,
        capability: requestCapability,
        imageSize: isImageGen ? userMessage?.imageSize : null,
        generateImageRequest:
            isImageGen ? userMessage?.generateImageRequest : null,
      );
    } finally {
      // Step 10: Finalization & Background Persistence.
      if (_activeConversation != null &&
          aiMessage != null &&
          userMessage != null) {
        if (_activeConversation!.title.isEmpty) {
          final fallback = deriveFallbackTitle(effectivePrompt, attachments);
          _activeConversation = _activeConversation!.copyWith(title: fallback);
        }
        _messages.add(aiMessage);
        _isGenerating = false;
        notifyListeners();

        // Only extract and persist generated media attachments if the AI response succeeded without error
        final bool isAiSuccess = aiMessage.finishReason != 'Fail';

        unawaited(_persistMessagePairInBackground(
          uid: resolvedUid,
          conversation: _activeConversation!,
          userMessage: userMessage,
          aiMessage: aiMessage,
          attachments: attachments,
          isNewConversation: isNewConversation,
          rawGeneratedImages: isAiSuccess ? aiMessage.imageUrls : null,
          generatedPdfBytes: isAiSuccess ? generatedPdfBytes : null,
          generatedPdfFileName: isAiSuccess ? generatedPdfFileName : null,
        ));
      } else {
        _isGenerating = false;
        notifyListeners();
      }

      // 10d. For new conversations, establish reactive listeners for local Hive storage
      //      and remote Firestore cross-device synchronization now that generation is complete.
      if (isNewConversation) {
        _subscribeToMessages(resolvedUid, targetConversationId);
        _subscribeToConversation(resolvedUid, targetConversationId);
      }
    }
  }

  /// Persists the message pair to local storage (Hive) and enqueues cloud sync (Firestore Outbox)
  /// completely in the background without delaying UI response rendering.
  ///
  /// Flow:
  /// 1. Concurrently uploads user-attached images & PDFs to Firebase Cloud Storage.
  /// 2. Concurrently uploads AI-generated images & compiled PDFs to Firebase Cloud Storage.
  /// 3. Updates message domain models with resolved public Cloud Storage download URLs.
  /// 4. Commits message pair to local Hive database and enqueues background Firestore Outbox sync.
  /// 5. Marks conversation list dirty so history screens refresh their preview snippets.
  Future<void> _persistMessagePairInBackground({
    required String uid,
    required ConversationModel conversation,
    required MessageModel userMessage,
    required MessageModel aiMessage,
    required List<ChatAttachment> attachments,
    required bool isNewConversation,
    List<String>? rawGeneratedImages,
    Uint8List? generatedPdfBytes,
    String? generatedPdfFileName,
  }) async {
    try {
      final conversationId = conversation.id;
      var conversationToPersist = conversation;
      if (conversationToPersist.title.trim().isEmpty) {
        final fallback = deriveFallbackTitle(
          userMessage.lastPrompt,
          attachments,
        );
        conversationToPersist = conversationToPersist.copyWith(title: fallback);
      }

      // ── Step 1: Upload User Attachments to Cloud Storage ──────────────
      List<String>? persistImagePaths = userMessage.imageUrls;
      List<PdfAttachmentInfo>? persistPdfs = userMessage.pdfInfo;

      final imageAttachments = attachments.where((a) => a.isImage).toList();
      final pdfAttachments = attachments.where((a) => a.isPdf).toList();

      if (imageAttachments.isNotEmpty) {
        // Upload user images in parallel
        final uploadFutures = imageAttachments
            .map((att) => CloudStorageService.instance.uploadImage(
                  uid: uid,
                  conversationId: conversationId,
                  bytes: att.bytes,
                  fileName: att.name,
                  mimeType: att.mimeType,
                ));
        final uploadedUrls = await Future.wait(uploadFutures);

        persistImagePaths = [
          for (int i = 0; i < imageAttachments.length; i++)
            (i < uploadedUrls.length &&
                    uploadedUrls[i] != null &&
                    uploadedUrls[i]!.isNotEmpty)
                ? uploadedUrls[i]!
                : (imageAttachments[i].path ?? ''),
        ];
      }

      if (pdfAttachments.isNotEmpty) {
        // Upload user PDFs in parallel
        final pdfFutures = pdfAttachments.map((att) async {
          final cloudUrl = await CloudStorageService.instance.uploadPdf(
            uid: uid,
            conversationId: conversationId,
            bytes: att.bytes,
            fileName: att.name,
          );
          return PdfAttachmentInfo(
            path: att.path ?? '',
            name: att.name,
            fileSizeBytes: att.fileSizeBytes ?? att.bytes.lengthInBytes,
            url: cloudUrl,
          );
        });
        persistPdfs = await Future.wait(pdfFutures);
      }

      final userMessageToPersist = userMessage.copyWith(
        imageUrls: persistImagePaths,
        pdfInfo: persistPdfs,
      );

      // ── Step 2: Upload AI Generated Images & PDFs to Cloud Storage ────
      var aiMessageToPersist = aiMessage;

      if (rawGeneratedImages != null && rawGeneratedImages.isNotEmpty) {
        final validImages =
            rawGeneratedImages.where((img) => img.isNotEmpty).toList();

        if (validImages.isNotEmpty) {
          final futures = <Future<String?>>[];
          for (int i = 0; i < validImages.length; i++) {
            futures.add(
              CloudStorageService.instance.uploadGeneratedImageBase64(
                uid: uid,
                conversationId: conversationId,
                base64String: validImages[i],
                index: i,
              ),
            );
          }
          final results = await Future.wait(futures);
          final List<String> resolvedAiImages = [];
          for (int i = 0; i < validImages.length; i++) {
            final cloudUrl = (i < results.length) ? results[i] : null;
            if (cloudUrl != null && cloudUrl.isNotEmpty) {
              resolvedAiImages.add(cloudUrl);
            } else {
              // Graceful fallback to data-URI if cloud upload fails
              final raw = validImages[i];
              final mime = raw.startsWith('/9j/') ? 'image/jpeg' : 'image/png';
              resolvedAiImages.add(raw.startsWith('data:image')
                  ? raw
                  : 'data:$mime;base64,$raw');
            }
          }
          aiMessageToPersist =
              aiMessageToPersist.copyWith(imageUrls: resolvedAiImages);
        }
      }

      if (generatedPdfBytes != null &&
          generatedPdfFileName != null &&
          aiMessageToPersist.pdfInfo?.isNotEmpty == true) {
        try {
          final cloudUrl =
              await CloudStorageService.instance.uploadGeneratedPdfBytes(
            uid: uid,
            conversationId: conversationId,
            bytes: generatedPdfBytes,
            fileName: generatedPdfFileName,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            final updatedPdfs = aiMessageToPersist.pdfInfo!
                .map((p) => p.copyWith(url: cloudUrl))
                .toList();
            aiMessageToPersist =
                aiMessageToPersist.copyWith(pdfInfo: updatedPdfs);
          }
        } catch (e) {
          debugPrint(
              '⚠️ ChatProvider: Error uploading generated PDF in background: $e');
        }
      }

      // ── Step 3: Local-first persistence & Outbox Enqueue ──────────────
      // Writes to Hive immediately and enqueues a background Firestore sync task via the outbox.
      // Note: In-memory _messages preserves local Base64 data-URIs and local PDF paths during the
      // active session so the user never experiences image reloading, shimmer flashes, or UI flicker.
      // Permanent Cloud Storage download URLs are committed to Hive & Firestore for subsequent sessions
      // and multi-device synchronization.
      await _repository.createOrAppendMessagePair(
        uid: uid,
        conversation: conversationToPersist,
        userMessage: userMessageToPersist,
        aiMessage: aiMessageToPersist,
        isFirstMessage: isNewConversation,
      );

      _markConversationHistoryDirty();
    } catch (e) {
      debugPrint(
          '⚠️ ChatProvider._persistMessagePairInBackground non-fatal error: $e');
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
    String? uid,
    required String conversationId,
  }) async {
    final resolvedUid = _resolveUid(uid);
    try {
      // Local-first delete: hides the conversation from the UI instantly.
      // The Firestore delete runs in the background via ChatSyncService.
      await _repository.deleteConversationLocalFirst(
        uid: resolvedUid,
        conversationId: conversationId,
      );

      // Clean up Cloud Storage attachments for this conversation in the background
      unawaited(
        CloudStorageService.instance.deleteConversationAttachments(
          uid: resolvedUid,
          conversationId: conversationId,
        ),
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
      debugPrint('\u26a0\ufe0f ChatProvider.deleteConversation error: $e');
      return false;
    }
  }

  Future<void> updateConversationTitle(String newTitle, [String? uid]) async {
    if (_activeConversation == null) return;
    final resolvedUid = _resolveUid(uid);
    try {
      await _repository.updateConversationTitle(
        uid: resolvedUid,
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
    // Cancel the Hive streams for the old conversation
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _conversationSubscription?.cancel();
    _conversationSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    super.dispose();
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
    // Exclude only in-progress optimistic messages.
    // We KEEP all completed messages (text, image gen, PDF gen, attachments, failed turns)
    // so the LLM has complete context of everything that transpired.
    final candidateMessages = _messages.where((m) => !m.isOptimistic).toList();

    if (candidateMessages.isEmpty) return [];

    // Take at most the last 3 conversation turns (up to 6 messages)
    const maxMessages = AppConstants.maxHistoryConversationTurns * 2;
    final recentMessages = candidateMessages.length > maxMessages
        ? candidateMessages.sublist(candidateMessages.length - maxMessages)
        : candidateMessages;

    // Convert to rich history entries (handles text, attachments, generated media, errors)
    final List<Map<String, String>> rawEntries =
        recentMessages.map((m) => m.toHistoryEntry()).toList();

    // Merge any consecutive same-role messages to guarantee strict alternation for Claude/Gemini
    final List<Map<String, String>> historyEntries = [];
    for (final entry in rawEntries) {
      if (historyEntries.isNotEmpty &&
          historyEntries.last['role'] == entry['role']) {
        final prevContent = historyEntries.last['content'] ?? '';
        final newContent = entry['content'] ?? '';
        historyEntries.last['content'] = '$prevContent\n\n$newContent';
      } else {
        historyEntries.add(Map<String, String>.from(entry));
      }
    }

    // Ensure the conversation history starts with a 'user' turn for API compatibility (e.g. Gemini / Claude)
    while (
        historyEntries.isNotEmpty && historyEntries.first['role'] != 'user') {
      historyEntries.removeAt(0);
    }

    if (historyEntries.isEmpty) return [];

    // Estimate total token count
    int totalChars = historyEntries.fold<int>(
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

    // Truncate oldest messages if they somehow exceed provider safety margin
    while (totalChars > maxChars && historyEntries.isNotEmpty) {
      final removed = historyEntries.removeAt(0);
      final removedLen = removed['content']?.length ?? 0;
      totalChars -= removedLen;
    }

    // Re-verify it still starts with 'user' after truncation
    while (
        historyEntries.isNotEmpty && historyEntries.first['role'] != 'user') {
      historyEntries.removeAt(0);
    }

    return historyEntries;
  }

  /// Resolves the intended [AiCapability] for an incoming prompt and attachment set.
  ///
  /// Decision Flow Priority:
  /// 1. Image attachment present -> [AiCapability.imageUnderstanding] (Vision OCR/Inspection)
  /// 2. PDF attachment present -> [AiCapability.pdfParsing] (Document analysis/extraction)
  /// 3. Prompt matches PDF creation intent -> [AiCapability.pdfGeneration] (Markdown styling & compilation)
  /// 4. Prompt matches visual creation intent -> [AiCapability.imageGeneration] (DALL-E / Imagen synthesis)
  /// 5. Default fallback -> [AiCapability.textGeneration] (Standard conversational response)
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
    if (_looksLikePdfGenerationPrompt(prompt)) {
      return AiCapability.pdfGeneration;
    }
    if (_looksLikeImageGenerationPrompt(prompt)) {
      return AiCapability.imageGeneration;
    }
    return AiCapability.textGeneration;
  }

  static AiImageSize _geminiRatioToImageSize(GeminiAspectRatio ratio) {
    switch (ratio) {
      case GeminiAspectRatio.square:
        return AiImageSize.square;
      case GeminiAspectRatio.landscape:
        return AiImageSize.landscape;
      case GeminiAspectRatio.portrait:
        return AiImageSize.portrait;
    }
  }

  MessageModel _buildFailedAiMessage({
    required String content,
    required Object error,
    required AiProviderId selectedProvider,
    required AiCapability capability,
    AiImageSize? imageSize,
    int? generateImageRequest,
  }) {
    final localizedMessage = AppLocalizations.lookupMessage(content);
    return MessageModel(
      lastPrompt: localizedMessage,
      modelRequest: selectedProvider,
      status: MessageStatus.failed,
      requestCapability: capability,
      imageSize: imageSize,
      generateImageRequest: generateImageRequest,
    );
  }

  String _friendlyAiErrorMessage(Object error) {
    if (error is AiException) return error.message;
    return 'something_went_wrong';
  }

  @visibleForTesting
  static String deriveFallbackTitle(
    String prompt, [
    List<ChatAttachment>? attachments,
  ]) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      if (attachments != null && attachments.isNotEmpty) {
        if (attachments.any((a) => a.isPdf)) return 'PDF Document';
        if (attachments.any((a) => a.isImage)) return 'Image Conversation';
      }
      return 'Conversation';
    }

    // Strip conversational greetings, polite requests, and commands iteratively
    String cleaned = trimmed;
    final prefixPattern = RegExp(
      r'^(hey\s+gemini|hey\s+chatgpt|hey\s+claude|hello|hi|please|kindly|can\s+you|could\s+you|help\s+me\s+to|i\s+want\s+to|i\s+need\s+to|generate\s+(an?|the)?|create\s+(an?|the)?|make\s+(an?|the)?|write\s+(an?|the)?|build\s+(an?|the)?|summarize\s+(an?|the)?|analyze\s+(an?|the)?|explain\s+(an?|the)?|small|short|detailed|new|content|document|file|pdf|image|images|picture|photo|summary|of|the|an?|about|regarding|which\s+has\s+(the\s+)?(data\s+of|info\s+about)?|about\s+how\s+much\s+it)\b[,.\s]*',
      caseSensitive: false,
    );

    String previous;
    do {
      previous = cleaned;
      cleaned = cleaned.replaceFirst(prefixPattern, '').trim();
    } while (cleaned.isNotEmpty && cleaned != previous);

    if (cleaned.isEmpty) {
      cleaned = trimmed;
    }

    // 4. Take the first 5 words
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(5)
        .toList();
    if (words.isEmpty) return 'Conversation';

    // 5. Apply Title Case
    final titleCased = words.map((w) {
      if (w.length <= 1) return w.toUpperCase();
      // Keep acronyms like "AI", "PDF", "API", "USA" intact
      if (w == w.toUpperCase() && w.length <= 4) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    return titleCased.length > 40
        ? '${titleCased.substring(0, 40).trim()}...'
        : titleCased;
  }

  bool _looksLikePdfGenerationPrompt(String prompt) {
    final lower = prompt.trim().toLowerCase();

    // 1. Explicit exclusions: Questions about existing files or asking how-to
    final askingAbout = RegExp(
      r'\b(how to|how do|how can|can you read|summarize this|explain this|what is in|analyze this|read this)\b',
    ).hasMatch(lower);
    if (askingAbout) return false;

    // 2. Strong match: Verb + "pdf" / "document" / "report" / "invoice" / "resume"
    final strongMatch = RegExp(
      r'\b(create|generate|make|build|export|produce|write|give me|download)\b.{0,60}\b(pdf|pdf file|pdf doc|pdf document|document as pdf|report as pdf)\b',
    ).hasMatch(lower);
    if (strongMatch) return true;

    // 3. Command starting with "pdf of", "generate pdf", "create pdf"
    final commandAtStart = RegExp(
      r'^(can you|could you|please|i want to|i need to)?\s*(generate|create|make|build|export|write)\s+(a\s+|the\s+)?(pdf|pdf document|pdf report|pdf invoice|pdf resume)\b',
    ).hasMatch(lower);
    if (commandAtStart) return true;

    return false;
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

  // ── Conversation History Pagination ──────────────────────────────────────

  StreamSubscription<dynamic>? _historySubscription;

  Future<void> loadInitialConversations(String uid, {String? query}) async {
    _searchQuery = query;
    _isLoadingMoreConversations = true;
    _conversationCursor = null;
    notifyListeners();

    try {
      final page = await _repository.getConversationPage(
        uid: uid,
        limit: AppConstants.conversationPageSize,
        searchQuery: query,
      );
      _visibleConversations = page.items;
      _hasMoreConversations = page.hasMore;
      _conversationCursor = page.nextCursor as ConversationPageCursor?;
    } catch (e) {
      debugPrint('⚠️ loadInitialConversations error: $e');
    } finally {
      _isLoadingMoreConversations = false;
      notifyListeners();
    }

    _subscribeToHistory(uid);
  }

  Future<void> loadMoreConversations(String uid) async {
    if (_isLoadingMoreConversations || !_hasMoreConversations) return;

    _isLoadingMoreConversations = true;
    notifyListeners();

    try {
      // Artificial delay to prevent instant runaway loads on fast scrolls
      await Future.delayed(const Duration(milliseconds: 600));

      final page = await _repository.getConversationPage(
        uid: uid,
        limit: AppConstants.conversationPageSize,
        cursor: _conversationCursor,
        searchQuery: _searchQuery,
      );
      _visibleConversations.addAll(page.items);
      _hasMoreConversations = page.hasMore;
      _conversationCursor = page.nextCursor as ConversationPageCursor?;
    } catch (e) {
      debugPrint('⚠️ loadMoreConversations error: $e');
    } finally {
      _isLoadingMoreConversations = false;
      notifyListeners();
    }

    _subscribeToHistory(uid);
  }

  void _subscribeToHistory(String uid) {
    _historySubscription?.cancel();
    _historySubscription =
        LocalChatStore.instance.conversationsBox.watch().listen((_) {
      // Refresh visible window from Hive when something changes locally
      final currentLimit = _visibleConversations.isEmpty
          ? AppConstants.conversationPageSize
          : _visibleConversations.length;

      var localRecords = LocalChatStore.instance.getConversations(uid);

      if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        localRecords = localRecords
            .where((c) => c.title.toLowerCase().contains(query))
            .toList();
      }

      final items = localRecords
          .take(currentLimit)
          .map((r) => r.toConversationModel())
          .toList();

      _visibleConversations = items;
      notifyListeners();
    });
  }

  // ── Conversation History Delegates ─────────────────────────────────────────
  // These methods expose repository calls through ChatProvider so that
  // presentation widgets never touch the repository or data stores directly.

  /// Soft-deletes all conversations locally (instant UI clear), then queues
  /// Firestore deletes in the background. Delegates to [_repository].
  Future<void> deleteAllConversations(String uid) =>
      _repository.deleteAllConversationsLocalFirst(uid);

  /// Returns true if the given conversation has been soft-deleted in the local Hive store.
  /// Used by [ChatDetailScreen] to detect remote deletions without accessing [LocalChatStore] directly.
  /// Note: Active in-memory conversations are currently in use and must never be considered deleted.
  bool isActiveConversationDeleted(String? uid, String conversationId) {
    if (uid == null) return false;
    // An active in-memory conversation is currently active and is never considered deleted.
    if (_activeConversation != null &&
        _activeConversation!.id == conversationId) {
      return false;
    }
    final conv = LocalChatStore.instance.getConversation(uid, conversationId);
    return conv != null && conv.isDeleted;
  }
}
