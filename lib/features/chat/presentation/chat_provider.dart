import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_voice_genie/core/extensions/string_extension.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/services/storage_service.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/models/ai_response.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../ai_layer/registry/provider_registry.dart';
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
  String? _lastGeneratedMessageId;
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

  /// ID of the most recently completed AI message — used by [MessageBubble]
  /// to trigger the typewriter animation on only the latest response.
  String? get lastGeneratedMessageId => _lastGeneratedMessageId;

  /// IDs of AI messages that have already run their typewriter animation.
  final Set<String> _animatedMessageIds = {};

  /// Whether a given AI message should run the typewriter animation.
  /// Returns true ONLY for the latest AI message and ONLY if it hasn't animated yet.
  bool shouldAnimateMessage(String messageId) {
    return _lastGeneratedMessageId == messageId &&
        !_animatedMessageIds.contains(messageId);
  }

  /// Marks an AI message as having completed its typewriter animation so it
  /// never re-animates on ListView scroll recycling.
  void markMessageAnimated(String messageId) {
    _animatedMessageIds.add(messageId);
    if (_lastGeneratedMessageId == messageId) {
      _lastGeneratedMessageId = null;
    }
  }

  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreMessages => _hasMoreMessages;
  String? get errorMessage => _errorMessage;
  bool get hasActiveConversation => _activeConversation != null;
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
    _lastGeneratedMessageId = null; // Prevent old messages from animating
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
          _messages
            ..clear()
            ..addAll(messages);
          notifyListeners();
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
    _lastGeneratedMessageId = null;
    _animatedMessageIds.clear();
    _messagesSubscription?.cancel();
  }

  // ── Send Message ───────────────────────────────────────────────────────────

  /// Starts a new conversation synchronously, returns the newly generated conversation ID
  /// immediately for routing, and kicks off AI message processing in the background.
  String startNewConversation({
    String? uid,
    required String prompt,
    required AiProviderId selectedProvider,
    List<ChatAttachment> attachments = const [],
  }) {
    clearConversation();
    final conversationId = const Uuid().v4();
    unawaited(sendMessage(
      uid: uid,
      prompt: prompt,
      selectedProvider: selectedProvider,
      attachments: attachments,
      newConversationId: conversationId,
    ));
    return conversationId;
  }

  /// Send a user prompt and receive an AI response.
  ///
  /// [uid]              — current user's Firebase UID (optional, resolved automatically if omitted)
  /// [prompt]           — the user's message text
  /// [selectedProvider] — provider selected for this single request
  /// [attachments]      — optional media and PDF documents
  /// [newConversationId]— optional pre-generated conversation ID when creating a new conversation
  Future<void> sendMessage({
    String? uid,
    required String prompt,
    required AiProviderId selectedProvider,
    List<ChatAttachment> attachments = const [],
    String? newConversationId,
  }) async {
    // Synchronous guard: drop any concurrent invocation immediately
    if (_isGenerating) return;

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && attachments.isEmpty) return;

    _errorMessage = null;

    // resolving the uid
    final resolvedUid = _resolveUid(uid);
    // cleaning greetings from prompt.
    final cleanPrompt = trimmedPrompt.stripGreetings();

    // Resolve the request capability based on the prompt
    final requestCapability = _resolveRequestCapability(
      prompt: trimmedPrompt,
      attachments: attachments,
    );

    final isImageGen = requestCapability == AiCapability.imageGeneration;
    final isImageUnderstanding =
        requestCapability == AiCapability.imageUnderstanding;
    final isOpenAi = selectedProvider == AiProviderId.openAi;
    final isGemini = selectedProvider == AiProviderId.gemini;

    // ── Optimistic user message ──────────────────────────────────────
    // We add the user message to the UI instantly so the app feels responsive.
    // If the request later fails, this optimistic message will be marked as failed.
    final userMessage = MessageModel.userMessage(
      lastPrompt: trimmedPrompt,
      validProvider: selectedProvider,
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
      imageSize: isImageGen
          ? (isGemini
              ? _geminiRatioToImageSize(
                  _preferences.preferredGeminiAspectRatio(selectedProvider))
              : (isOpenAi
                  ? _preferences.preferredImageSize(selectedProvider)
                  : null))
          : null,
      imageQuality: (isImageGen && isOpenAi)
          ? _preferences.preferredImageQuality(selectedProvider)
          : null,
      imageBackground: (isImageGen && isOpenAi)
          ? _preferences.preferredImageBackground(selectedProvider)
          : null,
      generateImageRequest: isImageGen
          ? (isGemini
              ? 1
              : (isOpenAi
                  ? _preferences.preferredImageCount(selectedProvider)
                  : null))
          : null,
      visionDetailLevel: (isImageUnderstanding && isOpenAi)
          ? _preferences.preferredVisionDetailLevel(selectedProvider)
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
      final conversationId = newConversationId ?? const Uuid().v4();

      // Initially set an empty title so the UI shows a shimmering placeholder
      // while we wait for the AI response to generate a combined title.
      String actualTitle = "";

      newConversation = ConversationModel(
        id: conversationId,
        title: actualTitle,
        lastMessage: _conversationPreview(cleanPrompt, attachments),
        capability: requestCapability,
        lastProvider: selectedProvider,
      );
      _activeConversation = newConversation;

      // Start watching the newly created conversation stream so future
      // updates (e.g. from other devices) arrive automatically.
      _subscribeToMessages(resolvedUid, conversationId);
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

      final effectivePrefs = ProviderRegistry.instance.sanitizePreferences(
        providerId: selectedProvider,
        capability: requestCapability,
        rawResponseLength:
            _preferences.preferredResponseLength(selectedProvider),
        rawImageSize: _preferences.preferredImageSize(selectedProvider),
        rawImageQuality: _preferences.preferredImageQuality(selectedProvider),
        rawImageBackground:
            _preferences.preferredImageBackground(selectedProvider),
        rawImageCount: _preferences.preferredImageCount(selectedProvider),
        rawVisionDetailLevel:
            _preferences.preferredVisionDetailLevel(selectedProvider),
        rawGeminiThinkingLevel:
            _preferences.preferredGeminiThinkingLevel(selectedProvider),
        rawGeminiAspectRatio:
            _preferences.preferredGeminiAspectRatio(selectedProvider),
      );

      final aiResponse = await _orchestrator.execute(
        request: AiRequest(
          capability: requestCapability,
          uid: resolvedUid,
          prompt: cleanPrompt.isNotEmpty ? cleanPrompt : trimmedPrompt,
          conversationHistory: history,
          visionDetailLevel:
              effectivePrefs.visionDetailLevel ?? VisionDetailLevel.auto,
          responseLength:
              effectivePrefs.responseLength ?? ResponseLength.balanced,
          thinkingLevel: effectivePrefs.geminiThinkingLevel ??
              _preferences.preferredGeminiThinkingLevel(selectedProvider),
          geminiAspectRatio: effectivePrefs.geminiAspectRatio ??
              _preferences.preferredGeminiAspectRatio(selectedProvider),
          imageSize: effectivePrefs.imageSize ?? AiImageSize.square,
          imageQuality: effectivePrefs.imageQuality ?? ImageQuality.low,
          imageCount: effectivePrefs.imageCount ?? 1,
          imageBackground:
              effectivePrefs.imageBackground ?? ImageGenerateBackground.auto,
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

      // ── Upload Base64 to Firebase Cloud Storage ───────────────────────────
      List<String> uploadedUrls = [];
      if (aiResponse.contentType == AiResponseContentType.imageBase64 &&
          aiResponse.generatedImages != null &&
          aiResponse.generatedImages!.isNotEmpty) {
        final conversationId = _activeConversation?.id ?? const Uuid().v4();
        final validImages = aiResponse.generatedImages!
            .where((img) => img.b64Json != null && img.b64Json!.isNotEmpty)
            .toList();

        final futures = <Future<String?>>[];
        for (int i = 0; i < validImages.length; i++) {
          futures.add(
            CloudStorageService.instance.uploadGeneratedImageBase64(
              uid: resolvedUid,
              conversationId: conversationId,
              base64String: validImages[i].b64Json!,
              index: i,
              mimeType: validImages[i].mimeType,
            ),
          );
        }

        final results = await Future.wait(futures);

        for (int i = 0; i < validImages.length; i++) {
          final cloudUrl = results[i];
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            uploadedUrls.add(cloudUrl);
          } else {
            // Fallback to data URI if upload failed so user can still see image
            final raw = validImages[i].b64Json!;
            final mime = validImages[i].mimeType ?? 'image/png';
            uploadedUrls.add(
                raw.startsWith('data:image') ? raw : 'data:$mime;base64,$raw');
          }
        }
      }

      // ── Compile & Upload AI-Generated PDF to Cloud Storage ────────────────
      List<PdfAttachmentInfo>? generatedPdfInfo;
      if (aiResponse.capability == AiCapability.pdfGeneration &&
          aiResponse.text != null &&
          aiResponse.text!.isNotEmpty) {
        final conversationId = _activeConversation?.id ?? const Uuid().v4();
        final docTitle = PdfDocumentService.extractDocumentTitle(
          cleanPrompt.isNotEmpty ? cleanPrompt : trimmedPrompt,
          aiResponse.text!,
        );

        try {
          final pdfBytes =
              await PdfDocumentService.instance.compileMarkdownToPdf(
            title: docTitle,
            markdownContent: aiResponse.text!,
          );

          final cleanFileName =
              '${docTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_')}.pdf';

          final cloudUrl =
              await CloudStorageService.instance.uploadGeneratedPdfBytes(
            uid: resolvedUid,
            conversationId: conversationId,
            bytes: pdfBytes,
            fileName: cleanFileName,
          );

          final localPath = await PdfDocumentService.instance.savePdfToDevice(
            bytes: pdfBytes,
            fileName: cleanFileName,
          );

          generatedPdfInfo = [
            PdfAttachmentInfo(
              path: localPath ?? '',
              name: cleanFileName,
              fileSizeBytes: pdfBytes.lengthInBytes,
              url: cloudUrl,
            ),
          ];
        } catch (e) {
          debugPrint('⚠️ ChatProvider: Error compiling or saving PDF: $e');
        }
      }

      // ── Step 5: Build AI response message ──────────────────────────────────
      aiMessage = _buildAiMessage(
        aiResponse,
        selectedProvider: selectedProvider,
        attachments: attachments,
        uploadedUrls: uploadedUrls,
        generatedPdfInfo: generatedPdfInfo,
      );

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
      var conversationToPersist = _activeConversation;

      if (messageToPersist != null && conversationToPersist != null) {
        // Refine conversation title on first message in memory
        if (isNewConversation) {
          final titleToSave = cleanPrompt.generateConversationTitle();
          conversationToPersist =
              conversationToPersist.copyWith(title: titleToSave);
          _activeConversation = conversationToPersist;
        }

        // 1. Deliver response message to memory state and update UI immediately
        _messages.add(messageToPersist);
        _lastGeneratedMessageId = messageToPersist.id;
        _isGenerating = false;
        notifyListeners();

        // 2. Perform storage uploads and local/remote persistence in background
        unawaited(_persistMessagePairInBackground(
          uid: resolvedUid,
          conversation: conversationToPersist,
          userMessage: userMessage,
          aiMessage: messageToPersist,
          attachments: attachments,
          isNewConversation: isNewConversation,
          optimisticIndex: optimisticIndex,
        ));
      } else {
        _isGenerating = false;
        notifyListeners();
      }
    }
  }

  /// Persists the message pair to local storage (Hive) and enqueues cloud sync (Firestore Outbox)
  /// completely in the background without delaying UI response rendering.
  Future<void> _persistMessagePairInBackground({
    required String uid,
    required ConversationModel conversation,
    required MessageModel userMessage,
    required MessageModel aiMessage,
    required List<ChatAttachment> attachments,
    required bool isNewConversation,
    required int optimisticIndex,
  }) async {
    try {
      final conversationId = conversation.id;

      // ── Upload Attachments to Cloud Storage ──────────────────────
      List<String>? persistImagePaths = userMessage.imageUrls;
      List<PdfAttachmentInfo>? persistPdfs = userMessage.pdfInfo;

      final imageAttachments = attachments.where((a) => a.isImage).toList();
      final pdfAttachments = attachments.where((a) => a.isPdf).toList();

      // 1. Upload Images in parallel to Firebase Storage
      if (imageAttachments.isNotEmpty) {
        final uploadFutures = imageAttachments
            .map((att) => CloudStorageService.instance.uploadImage(
                  uid: uid,
                  conversationId: conversationId,
                  bytes: att.bytes,
                  fileName: att.name,
                  mimeType: att.mimeType,
                ));
        final uploadedUrls = await Future.wait(uploadFutures);

        final List<String> resolvedImages = [];
        for (int i = 0; i < imageAttachments.length; i++) {
          final cloudUrl = (i < uploadedUrls.length) ? uploadedUrls[i] : null;
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            resolvedImages.add(cloudUrl);
          } else {
            // Fallback to micro-thumbnail if cloud upload was offline/failed
            final fallback = await _compressImagesToMicroThumbnails(
              [imageAttachments[i].path ?? ''],
              attachments: [imageAttachments[i]],
            );
            resolvedImages.add(fallback.first);
          }
        }
        persistImagePaths = resolvedImages;
      }

      // 2. Upload PDFs in parallel to Firebase Storage
      if (pdfAttachments.isNotEmpty) {
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
        status: MessageStatus.delivered,
        imageUrls: persistImagePaths,
        pdfInfo: persistPdfs,
      );

      // Update in memory so cache also has resolved URLs
      if (optimisticIndex != -1 && optimisticIndex < _messages.length) {
        _messages[optimisticIndex] = userMessageToPersist;
      }

      // Isolated local-first save — writes to Hive immediately and enqueues
      // a background Firestore sync task via the outbox.
      await _repository.createOrAppendMessagePair(
        uid: uid,
        conversation: conversation,
        userMessage: userMessageToPersist,
        aiMessage: aiMessage,
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
    if (_looksLikePdfGenerationPrompt(prompt)) {
      return AiCapability.pdfGeneration;
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
    if (_looksLikePdfGenerationPrompt(prompt)) {
      return 'Generated PDF: $prompt';
    }
    return 'Text: $prompt';
  }

  MessageModel _buildAiMessage(
    AiResponse response, {
    required AiProviderId selectedProvider,
    List<ChatAttachment> attachments = const [],
    List<String> uploadedUrls = const [],
    List<PdfAttachmentInfo>? generatedPdfInfo,
  }) {
    if (response.contentType == AiResponseContentType.imageBase64) {
      final isGemini = selectedProvider == AiProviderId.gemini ||
          response.modelUsed == AiProviderId.gemini;
      final isOpenAi = selectedProvider == AiProviderId.openAi ||
          response.modelUsed == AiProviderId.openAi;
      final generatedMime = (response.generatedImages != null &&
              response.generatedImages!.isNotEmpty)
          ? response.generatedImages!.first.mimeType
          : null;
      return MessageModel.aiResponse(
        content: response.text ?? '',
        modelUsed: response.modelUsed,
        contentType: AiCapability.imageGeneration,
        imageUrls: uploadedUrls.isNotEmpty ? uploadedUrls : null,
        tokenCount: response.tokenCount,
        imageSize: isGemini
            ? _geminiRatioToImageSize(
                _preferences.preferredGeminiAspectRatio(selectedProvider))
            : (isOpenAi
                ? _preferences.preferredImageSize(selectedProvider)
                : null),
        imageQuality: isOpenAi
            ? _preferences.preferredImageQuality(selectedProvider)
            : null,
        imageBackground: isOpenAi
            ? _preferences.preferredImageBackground(selectedProvider)
            : null,
        generateImageRequest: isGemini
            ? 1
            : (isOpenAi
                ? _preferences.preferredImageCount(selectedProvider)
                : null),
        mimeType: generatedMime,
      );
    } else if (response.capability == AiCapability.pdfGeneration ||
        generatedPdfInfo != null) {
      return MessageModel.aiResponse(
        content: generatedPdfInfo != null
            ? 'Here is the required PDF as you requested.'
            : (response.text ?? ''),
        modelUsed: response.modelUsed,
        contentType: AiCapability.pdfGeneration,
        pdfInfo: generatedPdfInfo,
        tokenCount: response.tokenCount,
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
    required AiProviderId? selectedProvider,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.assistant,
      lastPrompt: content,
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

  /// Compresses attached user images in parallel into lightweight Base64 micro-thumbnails
  /// (~15-25 KB each) for storage in Hive and Firestore.
  ///
  /// Micro-thumbnails keep the total message document size well below Firestore's 1 MB
  /// hard limit (even with 4 attachments ~70 KB total), eliminate network transfer bloat,
  /// and compress concurrently via [Future.wait].
  Future<List<String>> _compressImagesToMicroThumbnails(
    List<String> paths, {
    List<ChatAttachment>? attachments,
  }) async {
    if (paths.isEmpty) return const [];

    final Map<String, Uint8List> bytesByPath = {};
    if (attachments != null) {
      for (final a in attachments) {
        if (a.isImage && a.path != null && a.bytes.isNotEmpty) {
          bytesByPath[a.path!] = a.bytes;
        }
      }
    }

    final futures = paths.map((path) async {
      if (path.startsWith('data:image') || path.startsWith('http')) {
        return path;
      }

      Uint8List? fallbackBytes = bytesByPath[path];

      // 1. Attempt native compression directly from file path (micro-thumbnail: 480x480, quality: 60)
      try {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          path,
          minWidth: 480,
          minHeight: 480,
          quality: 60,
        );
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          return 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
        }
      } catch (e) {
        debugPrint(
            '⚠️ FlutterImageCompress.compressWithFile failed for $path: $e');
      }

      // 2. Fallback: Read file bytes if not provided in attachments
      if (fallbackBytes == null || fallbackBytes.isEmpty) {
        try {
          final file = File(path.replaceFirst('file://', ''));
          if (await file.exists()) {
            fallbackBytes = await file.readAsBytes();
          }
        } catch (_) {}
      }

      // 3. Attempt native compression using in-memory bytes
      if (fallbackBytes != null && fallbackBytes.isNotEmpty) {
        try {
          final compressedFromBytes =
              await FlutterImageCompress.compressWithList(
            fallbackBytes,
            minWidth: 480,
            minHeight: 480,
            quality: 60,
          );
          if (compressedFromBytes.isNotEmpty) {
            return 'data:image/jpeg;base64,${base64Encode(compressedFromBytes)}';
          }
        } catch (e) {
          debugPrint('⚠️ FlutterImageCompress.compressWithList failed: $e');
        }

        // 4. Safe fallback: If native compression failed, directly encode raw bytes
        // (if within reasonable size limit) to ensure cross-device sync receives valid image data
        if (fallbackBytes.lengthInBytes <= 256 * 1024) {
          return 'data:image/jpeg;base64,${base64Encode(fallbackBytes)}';
        }
      }

      return path;
    }).toList();

    return Future.wait(futures);
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

  /// Returns true if the given conversation has been soft-deleted or no longer
  /// exists in the local Hive store. Used by [ChatDetailScreen] to detect
  /// remote deletions without accessing [LocalChatStore] directly from UI code.
  bool isActiveConversationDeleted(String? uid, String conversationId) {
    if (uid == null) return false;
    final conv = LocalChatStore.instance.getConversation(uid, conversationId);
    return conv == null || conv.isDeleted;
  }
}
