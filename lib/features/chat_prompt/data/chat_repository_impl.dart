import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firebase_collections.dart';
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

      // Determine the effective last message and its timestamp based on AI vs User content
      final hasAiContent = aiMessage.content.trim().isNotEmpty;
      final effectiveLastMessage =
          hasAiContent ? aiMessage.content : userMessage.content;
      final effectiveLastMessageAt =
          hasAiContent ? aiMessage.timestamp : userMessage.timestamp;

      // If first message: write the conversation document in the same batch
      if (isFirstMessage && conversationModel != null) {
        final convRef = _firestore.doc(
          FirebaseCollections.conversationDoc(uid, conversationId),
        );

        // Update the model locally (fields are final, so use copyWith)
        final updatedModel = conversationModel.copyWith(
          lastMessage: effectiveLastMessage,
          lastMessageAt: effectiveLastMessageAt,
          lastProvider: aiMessage.modelUsed,
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
              aiMessage.modelUsed?.id,
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
      batch.set(aiRef, aiMessage.toFirestore());

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
          .orderBy(FirebaseCollections.fieldMessageTimestamp, descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => MessageModel.fromFirestore(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getMessages failed: ${e.code}',
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
      final encoded = jsonEncode(
        messages.map((m) => m.toCacheMap()).toList(),
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
      return list
          .map(
            (item) => MessageModel.fromCacheMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('⚠️ getCachedMessages error: $e');
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    await _storage.clearConversationCache();
  }
}
