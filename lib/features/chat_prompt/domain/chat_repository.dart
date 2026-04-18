import 'conversation_model.dart';
import 'message_model.dart';

/// Abstract repository for chat persistence operations.
///
/// All Firestore + Hive operations for conversations and messages
/// are defined here. ChatProvider only depends on this interface.
///
/// Implementation: ChatRepositoryImpl
abstract class ChatRepository {

  // ── Message Operations ────────────────────────────────────────────────────

  /// Save a prompt + response pair as a single Firestore document.
  ///
  /// The [userMessage.id] is used as the Firestore document ID.
  /// Both the prompt and AI response are stored in one document.
  Future<void> saveMessagePair({
    required String uid,
    required String conversationId,
    required MessageModel userMessage,
    required MessageModel aiMessage,
    bool isFirstMessage = false,
    ConversationModel? conversationModel, // only required when isFirstMessage = true
  });

  /// Load all messages for a conversation in chronological order (oldest first).
  Future<List<MessageModel>> getMessages({
    required String uid,
    required String conversationId,
  });

  /// Get all conversations for a specific user ordered by last updated.
  Future<List<ConversationModel>> getConversations(String uid);

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
