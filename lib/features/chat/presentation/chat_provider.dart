import 'dart:async';
import 'dart:math' as math;

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
import '../domain/local_message_record.dart';
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
  static ChatProvider? _instance;
  static ChatProvider? get instance => _instance;

  final ChatRepository _repository;
  final AiOrchestrator _orchestrator;
  final AiPreferencesService _preferences;

  ChatProvider({
    ChatRepository? repository,
    AiOrchestrator? orchestrator,
    AiPreferencesService? preferences,
  })  : _repository = repository ?? ChatRepositoryImpl(),
        _orchestrator = orchestrator ?? AiOrchestrator.instance,
        _preferences = preferences ?? AiPreferencesService.instance {
    _instance = this;
  }

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
  /// never re-animates on ListView scroll recycling and resets [_isGenerating] to false.
  void markMessageAnimated(String messageId) {
    _animatedMessageIds.add(messageId);
    if (_isGenerating) {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// True only while waiting for the AI network response before any assistant bubble is visible.
  bool get isWaitingForAiResponse =>
      _isGenerating &&
      (_messages.isEmpty || _messages.last.role == MessageRole.user);

  @visibleForTesting
  void addMessageForTesting(MessageModel msg) {
    _messages.add(msg);
    _isGenerating = true;
  }

  int _activeGenerationId = 0;
  int _currentRevealedLength = 0;

  /// Updates the current character reveal offset during typewriter streaming animation.
  void updateRevealedLength(int count) {
    _currentRevealedLength = count;
  }

  /// Safely sanitizes and closes unclosed markdown blocks (such as code fences
  /// or unclosed bold tags) when a message reveal is stopped mid-way.
  static String repairMarkdown(String text) {
    var trimmed = text.trimRight();
    if (trimmed.isEmpty) return trimmed;

    // 1. Check for unclosed code block fences (```)
    final codeBlockMatches = RegExp(r'```').allMatches(trimmed).length;
    if (codeBlockMatches.isOdd) {
      final lastBlockIndex = trimmed.lastIndexOf('```');
      final afterBlock = trimmed.substring(lastBlockIndex + 3);
      if (!afterBlock.contains('\n')) {
        // The language identifier was only partially typed (e.g., "```pyth") with no newline.
        // Strip the incomplete code fence header rather than leaving a broken block.
        trimmed = trimmed.substring(0, lastBlockIndex).trimRight();
      } else {
        // Code has started rendering; close the block so syntax formatting renders completely.
        trimmed = '$trimmed\n```';
      }
    }

    // 2. Check for unclosed bold markers (**)
    final boldMatches = RegExp(r'\*\*').allMatches(trimmed).length;
    if (boldMatches.isOdd) {
      trimmed = '$trimmed**';
    }

    return trimmed;
  }

  /// Stops any in-flight AI response generation or typewriter animation immediately.
  /// Freezes text at the exact character revealed so far and preserves the response
  /// as a partial response with finishReason = 'user-cancellation' and status = MessageStatus.partial.
  void stopGenerating() {
    if (!_isGenerating) return;
    _activeGenerationId++;
    _isGenerating = false;

    // If an AI message is actively in the messages list and still animating:
    if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
      final lastMsg = _messages.last;
      if (lastMsg.status != MessageStatus.failed) {
        String effectiveText = lastMsg.lastPrompt;
        if (_currentRevealedLength > 0 &&
            _currentRevealedLength < lastMsg.lastPrompt.length) {
          final slice = lastMsg.lastPrompt.substring(0, _currentRevealedLength);
          final repaired = repairMarkdown(slice);
          if (repaired.trim().isNotEmpty) {
            effectiveText = repaired;
          }
        }

        final stoppedMsg = lastMsg.copyWith(
          prompt: effectiveText,
          status: MessageStatus.partial,
          finishReason: AppConstants.finishReasonUserCancellation,
        );
        _messages[_messages.length - 1] = stoppedMsg;
        _animatedMessageIds.add(stoppedMsg.messageId);
        if (_activeConversation != null) {
          try {
            final uid = _resolveUid();
            unawaited(LocalChatStore.instance.saveMessage(
              LocalMessageRecord.fromMessageModel(
                stoppedMsg,
                uid: uid,
                conversationId: _activeConversation!.id,
                syncStatus: SyncStatus.pendingCreate,
              ),
            ));
            final existingConv = LocalChatStore.instance
                .getConversation(uid, _activeConversation!.id);
            if (existingConv != null) {
              final subtitle = stoppedMsg.lastPrompt.trim().isNotEmpty
                  ? stoppedMsg.lastPrompt
                  : (existingConv.lastMessage.trim().isNotEmpty
                      ? existingConv.lastMessage
                      : stoppedMsg.lastPrompt);
              unawaited(LocalChatStore.instance.saveConversation(
                existingConv.copyWith(
                  lastMessage: subtitle,
                  localUpdatedAt: DateTime.now(),
                ),
              ));
            }
          } catch (e) {
            debugPrint('⚠️ Error saving stopped message to LocalChatStore: $e');
          }
          unawaited(_repository.cacheMessages(
            conversationId: _activeConversation!.id,
            messages: _messages,
          ));
        }
      }
    }

    _currentRevealedLength = 0;
    _animatedMessageIds.addAll(_messages.map((m) => m.messageId));
    notifyListeners();
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

    // Guard: If this conversation is currently generating on screen, do not wipe in-flight messages or reset state
    if (_activeConversation?.id == conversationId && _isGenerating) {
      debugPrint(
          '🛡️ ChatProvider.loadConversation skipped: $conversationId is actively generating');
      return;
    }

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
      if (record == null) {
        // If the conversation was just initiated in memory and is currently persisting in background,
        // ignore the transient null state so we don't trigger empty UI rebuilds.
        if (_activeConversation?.id == conversationId) {
          return;
        }
        notifyListeners();
      } else if (record.isDeleted) {
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
          // Guard: Do not wipe in-memory messages with an empty list if there are currently messages in memory.
          // This transient empty state occurs while background media persistence is writing the initial records to Hive.
          if (messages.isEmpty && _messages.isNotEmpty) {
            return;
          }

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
    // Mark any existing in-memory messages as animated so they never replay
    // their typewriter effect if re-opened from history.
    _animatedMessageIds.addAll(_messages.map((m) => m.messageId));
    _messages.clear();
    _isGenerating = false;
    _currentRevealedLength = 0;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _conversationSubscription?.cancel();
    _conversationSubscription = null;
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
    _activeGenerationId++;
    final int currentGenId = _activeGenerationId;

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
          title:
              '', // Kept empty initially to display Shimmer loading skeleton in AppBar
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

      // Step 6: Dispatch AI title synthesis asynchronously in the background.
      // This is non-blocking and completely unawaited so the primary AI response
      // is rendered the exact moment the model finishes, without waiting for title generation.
      if (isNewConversation && effectivePrompt.isNotEmpty) {
        unawaited(_generateAndApplySmartTitle(
          conversationId: targetConversationId,
          prompt: effectivePrompt,
          attachments: attachments,
          provider: selectedProvider,
          uid: resolvedUid,
        ));
      }

      // Step 7: Dispatch request to AI layer directly.
      final AiResponse aiResponse = await _orchestrator.execute(
        request: aiRequest,
        selectedProvider: selectedProvider,
      );

      final bool wasAborted = _activeGenerationId != currentGenId;

      if (wasAborted) {
        debugPrint(
            '🛑 Generation $currentGenId was aborted by user; preserving response as user-cancellation.');
        aiMessage = MessageModel.fromAiResponse(
          aiResponse,
          status: MessageStatus.partial,
          finishReason: AppConstants.finishReasonUserCancellation,
          imageSize: isImageGen ? userMessage.imageSize : null,
          generateImageRequest:
              isImageGen ? userMessage.generateImageRequest : null,
          imageQuality: isImageGen ? userMessage.imageQuality : null,
          imageBackground: isImageGen ? userMessage.imageBackground : null,
          pdfInfo: pdfInfo,
        );
        _animatedMessageIds.add(aiMessage.messageId);
      } else {
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
      }
    } catch (e) {
      if (_activeGenerationId != currentGenId) {
        debugPrint(
            '🛑 Generation $currentGenId was aborted by user; ignoring error.');
        return;
      }
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
      if (aiMessage != null && userMessage != null) {
        final String effectiveAiLastMessage = aiMessage.lastPrompt
                .trim()
                .isNotEmpty
            ? aiMessage.lastPrompt.trim()
            : (aiMessage.imageUrls != null && aiMessage.imageUrls!.isNotEmpty
                ? 'Image'
                : (aiMessage.pdfInfo != null && aiMessage.pdfInfo!.isNotEmpty
                    ? 'PDF Document'
                    : userMessage.lastPrompt));

        final String currentOrFallbackTitle =
            (_activeConversation?.title.isNotEmpty == true)
                ? _activeConversation!.title
                : deriveFallbackTitle(effectivePrompt, attachments);

        final conversationToPersist = (_activeConversation ??
                ConversationModel(
                  id: targetConversationId,
                  title: currentOrFallbackTitle,
                  lastMessage: effectiveAiLastMessage,
                  capability: requestCapability,
                  lastProvider: selectedProvider,
                ))
            .copyWith(
          title: currentOrFallbackTitle,
          lastMessage: effectiveAiLastMessage,
        );

        if (_activeConversation != null &&
            _activeConversation!.id == targetConversationId) {
          _activeConversation = conversationToPersist;
          _messages.add(aiMessage);

          final bool wasAborted = _activeGenerationId != currentGenId;
          final bool isPureImageGen = aiMessage.requestCapability ==
                  AiCapability.imageGeneration &&
              (aiMessage.imageUrls != null && aiMessage.imageUrls!.isNotEmpty);
          final bool shouldSkipAnimation = wasAborted ||
              aiMessage.finishReason == 'Fail' ||
              isPureImageGen ||
              aiMessage.lastPrompt.trim().isEmpty;

          if (shouldSkipAnimation) {
            _animatedMessageIds.add(aiMessage.messageId);
            _isGenerating = false;
          } else {
            // Keep _isGenerating = true while TypewriterText reveals the tokens
            _isGenerating = true;
          }
          notifyListeners();
        } else {
          _animatedMessageIds.add(aiMessage.messageId);
          _isGenerating = false;
        }

        try {
          final existingConv = LocalChatStore.instance
              .getConversation(resolvedUid, targetConversationId);
          if (existingConv != null) {
            unawaited(LocalChatStore.instance.saveConversation(
              existingConv.copyWith(
                lastMessage: effectiveAiLastMessage,
                title: currentOrFallbackTitle,
                localUpdatedAt: DateTime.now(),
              ),
            ));
          }
          _markConversationHistoryDirty();
        } catch (e) {
          debugPrint('⚠️ Error updating immediate lastMessage in Hive: $e');
        }

        // Only extract and persist generated media attachments if the AI response succeeded without error
        final bool isAiSuccess = aiMessage.finishReason != 'Fail';

        unawaited(_persistMessagePairInBackground(
          uid: resolvedUid,
          conversation: conversationToPersist,
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
      //      and remote Firestore cross-device synchronization only if still active.
      if (isNewConversation &&
          _activeConversation?.id == targetConversationId) {
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
      final String effectiveAiSnippet = aiMessage.lastPrompt.trim().isNotEmpty
          ? aiMessage.lastPrompt.trim()
          : (aiMessage.imageUrls != null && aiMessage.imageUrls!.isNotEmpty
              ? 'Image'
              : (aiMessage.pdfInfo != null && aiMessage.pdfInfo!.isNotEmpty
                  ? 'PDF Document'
                  : conversation.lastMessage));

      var conversationToPersist = conversation.copyWith(
        lastMessage: effectiveAiSnippet,
      );
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

      // Adopt the freshest synthesized smart title from memory if available
      // (synthesized while media uploads were processing), ensuring we persist the highest-quality title.
      if (_activeConversation?.id == conversationId &&
          _activeConversation!.title.trim().isNotEmpty) {
        conversationToPersist = conversationToPersist.copyWith(
          title: _activeConversation!.title.trim(),
        );
      }

      // If the user cancelled/stopped the response while background tasks were running,
      // preserve the stopped/truncated version instead of the full text!
      final inMemoryMsg = _messages.firstWhere(
        (m) => m.messageId == aiMessageToPersist.messageId,
        orElse: () => aiMessageToPersist,
      );
      if (inMemoryMsg.finishReason ==
          AppConstants.finishReasonUserCancellation) {
        aiMessageToPersist = inMemoryMsg;
        conversationToPersist = conversationToPersist.copyWith(
          lastMessage: inMemoryMsg.lastPrompt.trim().isNotEmpty
              ? inMemoryMsg.lastPrompt.trim()
              : conversationToPersist.lastMessage,
        );
      }

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
      debugPrint('⚠️ ChatProvider.deleteConversation error: $e');
      return false;
    }
  }

  /// Deletes multiple conversations sequentially using the local-first pattern.
  /// Local cache (Hive) is updated for each, and remote Firestore deletions
  /// are enqueued in the sync outbox. UI listeners are notified once at the end.
  Future<void> deleteMultipleConversations({
    String? uid,
    required List<String> conversationIds,
  }) async {
    final resolvedUid = _resolveUid(uid);
    try {
      for (final conversationId in conversationIds) {
        await _repository.deleteConversationLocalFirst(
          uid: resolvedUid,
          conversationId: conversationId,
        );

        unawaited(
          CloudStorageService.instance.deleteConversationAttachments(
            uid: resolvedUid,
            conversationId: conversationId,
          ),
        );

        if (_activeConversation?.id == conversationId) {
          clearConversation();
        }
      }

      _markConversationHistoryDirty();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ ChatProvider.deleteMultipleConversations error: $e');
      rethrow;
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

  /// Asynchronously synthesizes an AI title for a newly created conversation in the background
  /// without delaying or blocking the primary AI response rendering.
  Future<void> _generateAndApplySmartTitle({
    required String conversationId,
    required String prompt,
    required List<ChatAttachment> attachments,
    required AiProviderId provider,
    required String uid,
  }) async {
    String? cleanTitle;
    try {
      final smartTitle = await _orchestrator.generateConversationTitle(
        prompt: prompt,
        provider: provider,
      );
      if (smartTitle != null && smartTitle.trim().isNotEmpty) {
        cleanTitle = smartTitle.trim();
      }
    } catch (e) {
      debugPrint('⚠️ Background title generation failed (non-fatal): $e');
    }

    // If AI synthesis returned null or failed, gracefully fall back to local heuristic title
    cleanTitle ??= deriveFallbackTitle(prompt, attachments);

    // Update in-memory active conversation to stop the AppBar Shimmer and render the title
    if (_activeConversation?.id == conversationId) {
      _activeConversation = _activeConversation!.copyWith(title: cleanTitle);
      notifyListeners();
    }

    // Persist the resolved title to Hive and Firestore.
    // If the conversation was just created and media uploads are currently in progress,
    // the local record in Hive may take a few seconds to commit. We retry briefly to ensure
    // the synthesized smart title is permanently committed to Hive and synced across devices.
    try {
      for (int retry = 0; retry < 24; retry++) {
        final existingRecord =
            LocalChatStore.instance.getConversation(uid, conversationId);
        if (existingRecord != null) {
          if (existingRecord.title != cleanTitle) {
            await _repository.updateConversationTitle(
              uid: uid,
              conversationId: conversationId,
              newTitle: cleanTitle,
            );
            _markConversationHistoryDirty();
          }
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('⚠️ Background title persistence failed: $e');
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

  /// Completely resets all chat state on user sign-out or account deletion.
  void resetSession() {
    clearConversation();
    _visibleConversations = [];
    _animatedMessageIds.clear();
    _searchQuery = null;
    _conversationCursor = null;
    _messageCursor = null;
    _hasMoreConversations = true;
    _hasMoreMessages = true;
    _conversationHistoryVersion = 0;
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

    // 1. Strip bracketed / parenthetical system options & UI hints (e.g. [Optional: ...])
    String cleaned = trimmed
        .replaceAll(
          RegExp(r'\[.*?\]|\(.*?\)', dotAll: true),
          ' ',
        )
        .trim();

    // 2. Strip conversational greetings, polite requests, commands, and compound meta-verbs iteratively
    final prefixPattern = RegExp(
      r'^(hey\s+gemini|hey\s+chatgpt|hey\s+claude|hey\s+\w+|hello|hi|please|kindly|can\s+you|could\s+you|'
      r'help\s+me\s+to|help\s+me|i\s+want\s+to|i\s+need\s+to|'
      r'generate\s+(an?|the)?|create\s+(an?|the)?|make\s+(an?|the)?|write\s+(an?|the)?|build\s+(an?|the)?|'
      r'summarize\s+(an?|the)?|analyze\s+(an?|the)?|explain\s+(an?|the)?|describe\s+(an?|the)?|'
      r'tell\s+me\s+(about\s+)?|give\s+me\s+(a\s+)?|show\s+me\s+(a\s+)?|'
      r'analyze\s+(this|the|an?)\s+(image|photo|picture|doc|document|pdf|file)?\s*(and|to)?\s*(describe|explain|tell\s+me)?\s*(to\s+me|me)?|'
      r'describe\s+(this|the|an?)\s+(image|photo|picture|doc|document|pdf|file)?\s*(and|to)?\s*(explain|tell\s+me)?\s*(to\s+me|me)?|'
      r'small|short|detailed|new|content|document|file|pdf|image|images|picture|photo|summary|of|the|an?|about|regarding|'
      r'this\s+(image|photo|picture|doc|document|pdf|file)\s*(and|to)?\s*(describe|explain|tell\s+me)?\s*(to\s+me|me)?|'
      r'which\s+has\s+(the\s+)?(data\s+of|info\s+about)?|about\s+how\s+much\s+it|this|that|these|those|me|and|to)\b[,.\s:]*',
      caseSensitive: false,
    );

    String previous;
    do {
      previous = cleaned;
      cleaned = cleaned.replaceFirst(prefixPattern, '').trim();
    } while (cleaned.isNotEmpty && cleaned != previous);

    if (cleaned.isEmpty) {
      if (attachments != null && attachments.isNotEmpty) {
        if (attachments.any((a) => a.isPdf)) return 'PDF Document';
        if (attachments.any((a) => a.isImage)) return 'Image Conversation';
      }
      cleaned = trimmed;
    }

    // 4. Take the first 5 words
    final rawWords = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(5)
        .toList();
    if (rawWords.isEmpty) return 'Conversation';

    // Strip trailing periods/commas from individual words while preserving question marks
    final words = rawWords
        .map((w) => w.replaceAll(RegExp(r'[.,;:]+$'), ''))
        .where((w) => w.isNotEmpty)
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

    // 2. Hindi image generation intent
    final hindiMatch = RegExp(
      r'(\b(तस्वीर|चित्र|फोटो|इमेज)\b.{0,40}\b(बनाएं|बनाओ|दिखाएं|दिखाओ|क्रिएट|जनरेट)\b)|(\b(बनाएं|बनाओ|दिखाएं|दिखाओ|क्रिएट|जनरेट)\b.{0,40}\b(तस्वीर|चित्र|फोटो|इमेज)\b)',
    ).hasMatch(lower);
    if (hindiMatch) return true;

    // 3. Strong match: Verb + nearby image noun + optional "of", "for", or "with"
    final strongMatch = RegExp(
      r'\b(create|generate|draw|make|design|render|paint|need|want|show me)\b.{0,80}\b(image|picture|photo|art|illustration|poster|logo|wallpaper|graphic|artwork|painting|sketch|portrait|landscape)\b',
    ).hasMatch(lower);

    if (strongMatch) return true;

    // 4. Command at the very beginning of the prompt
    final commandAtStart = RegExp(
      r'^(can you|could you|please|i want to|i need to)?\s*(create|generate|draw|make|design|render|paint)\b.{0,80}\b(image|picture|photo|art|illustration|poster|logo|wallpaper|graphic|artwork|painting|sketch|portrait|landscape)\b',
    ).hasMatch(lower);

    if (commandAtStart) return true;

    // 5. Strict visual verbs that strongly imply image generation even without nouns
    final visualVerbAtStart = RegExp(
      r'^(can you|could you|please)?\s*(draw|paint|sketch)\b',
    ).hasMatch(lower);

    if (visualVerbAtStart) return true;

    // 6. Starts directly with describing the image
    final nounAtStart = RegExp(
      r'^(a|an|the|some)?\s*(image|picture|photo|illustration|poster|logo|artwork)\s+(of|for)\b',
    ).hasMatch(lower);

    if (nounAtStart) return true;

    // 7. Visual rendering and artistic style keywords (e.g. "... 8k photographic style", "... digital art style", "... photorealistic render")
    final styleDirective = RegExp(
      r'\b(photographic style|photo style|8k|4k|hyperrealistic|photorealistic|digital art|oil painting|watercolor painting|3d render|cinematic render|anime style|vector art|octane render)\b',
    ).hasMatch(lower);

    return styleDirective;
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
      // Refresh visible window from Hive when something changes locally.
      // Ensure the visible window is never truncated below AppConstants.conversationPageSize
      // when new items arrive from local changes or remote cross-device sync.
      final currentLimit = math.max(
        _visibleConversations.length + 1,
        AppConstants.conversationPageSize,
      );

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

  Future<void> deleteAllConversations(String uid) async {
    clearConversation();
    _markConversationHistoryDirty();
    await _repository.deleteAllConversationsLocalFirst(uid);
    notifyListeners();
  }

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
