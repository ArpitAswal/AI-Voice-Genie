import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/enums/app_enums.dart';
import 'conversation_model.dart';
import 'message_model.dart';

/// Abstract repository for chat persistence operations.
///
/// All Firestore + Hive operations for conversations and messages
/// are defined here. ChatProvider only depends on this interface.
///
/// Implementation: ChatRepositoryImpl
abstract class ChatRepository {
  // ── Conversation Operations ───────────────────────────────────────────────

  /// Create a new conversation document in Firestore.
  ///
  /// Called when the user sends their very first message.
  /// Returns the newly created ConversationModel with its Firestore ID.
  Future<ConversationModel> createConversation({
    required String uid,
    required String firstMessagePreview,
    required ConversationCapability capability,
    required AiProviderId firstProvider,
  });

  /// Update conversation metadata after a new message exchange.
  ///
  /// Updates: lastMessage, lastMessageAt, messageCount, lastProvider.
  Future<void> updateConversationMetadata({
    required String uid,
    required String conversationId,
    required String lastMessage,
    required AiProviderId lastProvider,
    required int newMessageCount,
  });

  /// Load a single conversation by ID.
  ///
  /// Checks Hive cache first, falls back to Firestore.
  Future<ConversationModel?> getConversation({
    required String uid,
    required String conversationId,
  });

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation({
    required String uid,
    required String conversationId,
  });

  /// Load a paginated list of conversations, newest first.
  ///
  /// [afterDocument] — Firestore cursor for pagination.
  Future<List<ConversationModel>> getConversations({
    required String uid,
    int limit = 15,
    DocumentSnapshot? afterDocument,
  });

  // ── Message Operations ────────────────────────────────────────────────────

  /// Save a list of messages (user + AI pair) to Firestore.
  ///
  /// Uses a batch write for atomicity — both messages written together.
  Future<void> saveMessages({
    required String uid,
    required String conversationId,
    required List<MessageModel> messages,
  });

  /// Load the most recent [limit] messages for a conversation.
  ///
  /// Returns messages in chronological order (oldest first).
  Future<List<MessageModel>> getMessages({
    required String uid,
    required String conversationId,
    int limit = 30,
    DocumentSnapshot? beforeDocument,
  });

  // ── Hive Cache Operations ─────────────────────────────────────────────────

  /// Cache messages for the active conversation in Hive.
  ///
  /// Overwrites any existing cache for this conversation.
  Future<void> cacheMessages({
    required String conversationId,
    required List<MessageModel> messages,
  });

  /// Load cached messages for a conversation from Hive.
  ///
  /// Returns empty list if no cache exists.
  Future<List<MessageModel>> getCachedMessages(String conversationId);

  /// Clear all cached messages (called on sign-out or conversation delete).
  Future<void> clearCache();
}

// =============================================================================
// CHAT EXCEPTION
// =============================================================================

class ChatException implements Exception {
  final String code;
  final String? technicalMessage;

  const ChatException(this.code, {this.technicalMessage});

  @override
  String toString() =>
      'ChatException(code: $code, technical: $technicalMessage)';
}

class ChatErrorCodes {
  static const String saveFailed = 'something_went_wrong';
  static const String loadFailed = 'something_went_wrong';
  static const String deleteFailed = 'something_went_wrong';
  static const String noInternet = 'no_internet_connection';
}
