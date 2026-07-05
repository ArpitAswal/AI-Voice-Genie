import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

/// Concrete implementation of ChatRepository.
///
/// Firestore structure:
///   AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}          ← conversation metadata
///   AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}/messages/UserRef-{id}  ← user message
///   AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}/messages/AIRef-{id}    ← AI response
///
/// Each message is stored as its own document (via MessageModel.toFirestore)
/// containing a `role`, `content`, `timestamp`, etc. Document IDs are prefixed
/// with `UserRef-` or `AIRef-` to make their type clear.
///
/// When reading, each document is deserialized individually with
/// MessageModel.fromFirestore into a single MessageModel (user or assistant).
///
/// Hive cache:
///   Key: 'messages_{conversationId}' → JSON-encoded List<MessageModel>
///   Uses individual message format for fast UI rendering.
class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final StorageService _storage;

  ChatRepositoryImpl({
    FirebaseFirestore? firestore,
    StorageService? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService();

  // ── Message Operations ────────────────────────────────────────────────────

  @override
  Future<void> saveMessagePair({
    required String uid,
    required String conversationId,
    required MessageModel userMessage,
    required MessageModel aiMessage,
    bool isFirstMessage = false,
    ConversationModel? conversationModel,
  }) async {
    try {
      final batch = _firestore.batch();
      final firestoreAiMessage = _sanitizeMessageForFirestore(aiMessage);

      // Determine the effective last message and its timestamp based on AI vs User content
      final hasAiContent = firestoreAiMessage.content.trim().isNotEmpty;
      final effectiveLastMessage =
          hasAiContent ? firestoreAiMessage.content : userMessage.content;
      final effectiveLastMessageAt =
          hasAiContent ? firestoreAiMessage.timestamp : userMessage.timestamp;

      // If first message: write the conversation document in the same batch
      if (isFirstMessage && conversationModel != null) {
        final convRef = _firestore.doc(
          FirebaseCollections.conversationDoc(uid, conversationId),
        );

        // Update the model locally (fields are final, so use copyWith)
        final updatedModel = conversationModel.copyWith(
          lastMessage: effectiveLastMessage,
          lastMessageAt: effectiveLastMessageAt,
          lastProvider: firestoreAiMessage.modelUsed,
        );

        batch.set(convRef, {
          ...updatedModel.toFirestore(),
          FirebaseCollections.fieldConversationCreatedAt:
              FieldValue.serverTimestamp(),
          FirebaseCollections.fieldConversationLastMessageAt:
              effectiveLastMessageAt,
        });
      } else {
        // Subsequent messages: update lastMessage preview, timestamp, and provider
        final convRef = _firestore.doc(
          FirebaseCollections.conversationDoc(uid, conversationId),
        );
        batch.update(convRef, {
          FirebaseCollections.fieldConversationLastMessage:
              effectiveLastMessage,
          FirebaseCollections.fieldConversationLastMessageAt:
              effectiveLastMessageAt,
          FirebaseCollections.fieldConversationLastProvider:
              firestoreAiMessage.modelUsed?.id,
        });
      }

      // Always: write user message + AI message together
      final userRef = _firestore.doc(
        FirebaseCollections.messageDoc(
            uid, conversationId, "UserRef-${userMessage.id}"),
      );
      final aiRef = _firestore.doc(
        FirebaseCollections.messageDoc(
            uid, conversationId, "AIRef-${aiMessage.id}"),
      );

      batch.set(userRef, userMessage.toFirestore());
      batch.set(aiRef, firestoreAiMessage.toFirestore());

      await batch.commit();

      debugPrint(
        '✅ Saved message pair to conversation $conversationId',
      );
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.saveFailed,
        technicalMessage: 'saveMessagePair failed: ${e.code}',
      );
    }
  }

  @override
  Future<List<MessageModel>> getMessages({
    required String uid,
    required String conversationId,
  }) async {
    try {
      // Fetch all message documents ordered oldest→newest (ascending timestamp).
      // Each doc is a single message (UserRef-{id} or AIRef-{id}) stored via
      // toFirestore() — containing role, content, timestamp, etc.
      final snapshot = await _firestore
          .collection(
            FirebaseCollections.messagesCollection(uid, conversationId),
          )
          .orderBy(FirebaseCollections.fieldMessageTimestamp)
          .get();

      final freshMessages = snapshot.docs
          .map(
            (doc) => MessageModel.fromFirestore(
              doc.id,
              doc.data(),
            ),
          )
          .toList();

      final cachedMessages = await getCachedMessages(conversationId);
      if (cachedMessages.isEmpty) {
        return _sortChronologically(freshMessages);
      }

      final cachedById = {
        for (final message in cachedMessages) message.id: message,
      };
      final freshIds = freshMessages.map((message) => message.id).toSet();

      final mergedMessages = freshMessages.map((message) {
        final cached = cachedById[message.id];
        if (cached == null) return message;

        return message.copyWith(
          content:
              message.content.isNotEmpty ? message.content : cached.content,
          contentType: message.contentType,
          imageUrl: message.imageUrl ?? cached.imageUrl,
          pdfName: message.pdfName ?? cached.pdfName,
          validProviders: message.validProviders.isNotEmpty
              ? message.validProviders
              : cached.validProviders,
        );
      }).toList();

      final missingCachedMessages = cachedMessages
          .where((message) => !freshIds.contains(message.id))
          .toList();

      return _sortChronologically([
        ...mergedMessages,
        ...missingCachedMessages,
      ]);
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getMessages failed: ${e.code}',
      );
    }
  }

  @override
  Future<ConversationModel?> getConversation(
    String uid,
    String conversationId,
  ) async {
    try {
      final doc = await _firestore
          .doc(FirebaseCollections.conversationDoc(uid, conversationId))
          .get();

      if (!doc.exists) return null;

      return ConversationModel.fromFirestore(doc.id, doc.data() ?? {});
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getConversation failed: ${e.code}',
      );
    }
  }

  @override
  Future<List<ConversationModel>> getConversations(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.conversationsCollection(uid))
          .orderBy(FirebaseCollections.fieldConversationLastMessageAt,
              descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getConversations failed: ${e.code}',
      );
    }
  }

  @override
  Future<void> deleteConversation({
    required String uid,
    required String conversationId,
  }) async {
    try {
      // ── Step 1: Delete all message documents ─────────────────────────────
      // Firestore does NOT cascade-delete sub-collections automatically.
      // We must fetch all message doc refs and delete them explicitly.
      final messagesRef = _firestore.collection(
        FirebaseCollections.messagesCollection(uid, conversationId),
      );

      // Fetch in pages of 500 (Firestore batch write limit)
      const batchLimit = 500;
      QuerySnapshot snapshot;
      do {
        snapshot = await messagesRef.limit(batchLimit).get();
        if (snapshot.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (snapshot.docs.length == batchLimit);

      // ── Step 2: Delete the conversation document itself ───────────────────
      await _firestore
          .doc(FirebaseCollections.conversationDoc(uid, conversationId))
          .delete();

      // ── Step 3: Remove from Hive cache ────────────────────────────────────
      await _storage.removeConversationCache('messages_$conversationId');

      debugPrint('🗑️ Deleted conversation $conversationId');
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.deleteFailed,
        technicalMessage: 'deleteConversation failed: ${e.code}',
      );
    }
  }

  @override
  Future<void> deleteAllConversations(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.conversationsCollection(uid))
          .get();

      // Firestore client SDKs do not support deleting an entire collection at once.
      // We must delete documents individually. We use Future.wait to run them concurrently for speed.
      await Future.wait(
        snapshot.docs
            .map((doc) => deleteConversation(uid: uid, conversationId: doc.id)),
      );

      await clearCache();

      debugPrint('🗑️ Deleted all conversations for user $uid');
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.deleteFailed,
        technicalMessage: 'deleteAllConversations failed: ${e.code}',
      );
    }
  }

  // ── Hive Cache Operations ─────────────────────────────────────────────────

  @override
  Future<void> cacheMessages({
    required String conversationId,
    required List<MessageModel> messages,
  }) async {
    try {
      // Serialize messages to JSON for Hive storage
      // Uses toCacheMap() instead of toFirestore() to avoid FieldValue
      // serialization errors (FieldValue.serverTimestamp() is a Firestore
      // sentinel that cannot be JSON-encoded).
      final sortedMessages = _sortChronologically(messages);
      final encoded = jsonEncode(
        sortedMessages.map((m) => m.toCacheMap()).toList(),
      );
      await _storage.setConversationCache(
        'messages_$conversationId',
        encoded,
      );
    } catch (e) {
      debugPrint('⚠️ cacheMessages error: $e');
      // Cache failure is non-fatal — Firestore is the source of truth
    }
  }

  @override
  Future<List<MessageModel>> getCachedMessages(
    String conversationId,
  ) async {
    try {
      final encoded = _storage.getConversationCache<String>(
        'messages_$conversationId',
      );
      if (encoded == null || encoded.isEmpty) return [];

      final list = jsonDecode(encoded) as List<dynamic>;
      final messages = list
          .map(
            (item) => MessageModel.fromCacheMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      return _sortChronologically(messages);
    } catch (e) {
      debugPrint('⚠️ getCachedMessages error: $e');
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    await _storage.clearConversationCache();
  }

  List<MessageModel> _sortChronologically(List<MessageModel> messages) {
    final sorted = List<MessageModel>.from(messages);
    sorted.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) return timeCompare;

      if (a.role != b.role) {
        if (a.role == MessageRole.user) return -1;
        if (b.role == MessageRole.user) return 1;
      }

      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  MessageModel _sanitizeMessageForFirestore(MessageModel message) {
    if (message.contentType != MessageContentType.imageUrl) {
      return message;
    }

    // Firestore documents have a strict 1 MiB size limit, so generated image
    // payloads are cached locally in Hive and only lightweight metadata is
    // persisted remotely.
    return message.copyWith(
      imageUrl: null,
    );
  }
}
