import 'package:ai_voice_genie/core/extensions/string_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../ai_layer/models/ai_request.dart';
import '../../../ai_layer/orchestrator/ai_orchestrator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/error/ai_exception.dart';
import '../../../core/error/effect_bus.dart';
import '../../../core/services/analytics_service.dart';
import '../data/chat_repository_impl.dart';
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
///   validProviders: apiKeyProvider.validProviders,
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
  bool _hasMoreMessages = true;
  String? _errorMessage;

  ConversationModel? get activeConversation => _activeConversation;
  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get hasMoreMessages => _hasMoreMessages;
  String? get errorMessage => _errorMessage;
  bool get hasActiveConversation => _activeConversation != null;

  // ── Load Conversation ──────────────────────────────────────────────────────

  /// Load an existing conversation by ID.
  ///
  /// Strategy:
  ///   1. Load from Hive cache instantly (fast path)
  ///   2. Fetch from Firestore in background (fresh data)
  ///   3. Merge — Firestore result replaces cache
  Future<void> loadConversation({
    required String uid,
    required String conversationId,
  }) async {
    _isLoadingMessages = true;
    _errorMessage = null;
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

      // Load conversation metadata
      // _activeConversation = await _repository.getConversation(
      //   uid: uid,
      //   conversationId: conversationId,
      // );

      // Fresh path: load from Firestore
      final fresh = await _repository.getMessages(
        uid: uid,
        conversationId: conversationId,
        limit: AppConstants.initialMessageLoadCount,
      );

      _messages
        ..clear()
        ..addAll(fresh);

      _hasMoreMessages = fresh.length >= AppConstants.initialMessageLoadCount;

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

  /// Load older messages when user scrolls to the top.
  Future<void> loadMoreMessages({
    required String uid,
    required String conversationId,
  }) async {
    if (!_hasMoreMessages || _isLoadingMessages) return;

    _isLoadingMessages = true;
    notifyListeners();

    try {
      final older = await _repository.getMessages(
        uid: uid,
        conversationId: conversationId,
        limit: AppConstants.messagePageSize,
      );

      // Prepend older messages to the beginning of the list
      _messages.insertAll(0, older);
      _hasMoreMessages = older.length >= AppConstants.messagePageSize;
    } catch (e) {
      debugPrint('⚠️ ChatProvider.loadMoreMessages error: $e');
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
  /// [validProviders]   — providers with valid keys (from ApiKeyProvider)
  /// [capability]       — defaults to textGeneration (chat). Override for image/PDF.
  ///
  /// Returns true on success, false on failure.
  Future<bool> sendMessage({
    required String uid,
    required String prompt,
    required List<AiProviderId> validProviders,
    ConversationCapability capability = ConversationCapability.textChat,
  }) async {
    if (prompt.trim().isEmpty) return false;

    _errorMessage = null;

    // ── Step 1: Optimistic user message ──────────────────────────────────────
    final userMessage = MessageModel.userMessage(
      prompt.trim(),
      validProviders: validProviders,
    );
    _messages.add(userMessage);
    _isGenerating = true;
    notifyListeners();

    // ── Step 2: Create conversation if this is the first message ──────────────
    final isNewConversation = _activeConversation == null;
    ConversationModel? newConversation;
    if (isNewConversation) {
      try {
        await _analytics.logConversationStarted(
          capability: capability,
          provider: validProviders.isNotEmpty
              ? validProviders.first
              : AiProviderId.openAi,
        );

        // Build the conversation model in memory — written to Firestore
        // together with the first message pair in one batch (Step 6)
        final conversationId = const Uuid().v4();
        final title = prompt.trim().generateConversationTitle();
        newConversation = ConversationModel(
          id: conversationId,
          title: title,
          lastMessage: prompt.trim(),
          capability: capability,
          lastProvider: validProviders.isNotEmpty
              ? validProviders.first
              : AiProviderId.openAi,
        );
        _activeConversation = newConversation;
      } catch (e) {
        // Conversation creation failed — roll back and show error
        // _messages.remove(userMessage);
        _isGenerating = false;
        _errorMessage = 'something_went_wrong';
        notifyListeners();
        return false;
      }
    }

    // ── Step 3: Build context-aware history ───────────────────────────────────
    final history = _buildTruncatedHistory();

    // ── Step 4: Execute via orchestrator ─────────────────────────────────────
    try {
      final aiResponse = await _orchestrator.execute(
        request: AiRequest(
          capability: AiCapability.textGeneration,
          uid: uid,
          prompt: prompt.trim(),
          conversationHistory: history,
        ),
        userKeyedProviders: validProviders,
      );

      // ── Step 5: Add AI response to list ──────────────────────────────────
      final aiMessage = MessageModel.aiResponse(
        content: aiResponse.text ?? '',
        modelUsed: aiResponse.modelUsed,
        tokenCount: aiResponse.tokenCount,
      );

      // Replace optimistic user message with confirmed version
      final optimisticIndex =
          _messages.indexWhere((m) => m.id == userMessage.id);
      if (optimisticIndex != -1) {
        _messages[optimisticIndex] = userMessage.copyWith(
          status: MessageStatus.delivered,
          isOptimistic: false,
        );
      }

      _messages.add(aiMessage);

      // ── Step 6: Persist to Firestore (non-blocking side effect) ──────────
      final conversationId = _activeConversation!.id;
      await EffectBus.instance.safeEffect(() async {
        await _repository.saveMessagePair(
          uid: uid,
          conversationId: conversationId,
          userMessage: userMessage,
          aiMessage: aiMessage,
          isFirstMessage: isNewConversation,
          conversationModel: isNewConversation ? _activeConversation : null,
        );
      });

      // ── Step 7: Update Hive cache ─────────────────────────────────────────
      await EffectBus.instance.safeEffect(() async {
        await _repository.cacheMessages(
          conversationId: conversationId,
          messages: _messages,
        );
      });

      // ── Step 8: Analytics ─────────────────────────────────────────────────
      await _analytics.logFeatureUsed(AppFeature.textChat);

      _isGenerating = false;
      notifyListeners();
      return true;
    } on AiExhaustedException catch (e) {
      // All providers failed — EffectBus already emitted by orchestrator
      _rollbackOptimisticMessage(userMessage.id);
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } on AiException catch (e) {
      _rollbackOptimisticMessage(userMessage.id);
      _errorMessage = e.message;
      _isGenerating = false;
      notifyListeners();
      return false;
    } catch (e) {
      _rollbackOptimisticMessage(userMessage.id);
      _errorMessage = 'something_went_wrong';
      _isGenerating = false;
      notifyListeners();
      return false;
    }
  }

  // ── Delete Conversation ────────────────────────────────────────────────────

  Future<bool> deleteConversation(String uid) async {
    final conversationId = _activeConversation?.id;
    if (conversationId == null) return false;

    try {
      // await _repository.deleteConversation(
      //   uid: uid,
      //   conversationId: conversationId,
      // );
      clearConversation();
      return true;
    } on ChatException {
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
    _hasMoreMessages = true;
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
      totalChars -= removed['content']?.length ?? 0;
    }

    return historyMessages;
  }

  /// Remove an optimistic message on failure — prevents ghost messages.
  void _rollbackOptimisticMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId && m.isOptimistic);
  }
}
