import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/message_model.dart';

/// Concrete implementation of ChatRepository.
///
/// Firestore structure:
///   AI_Voice_Genie/users/{uid}/conversations/{id}       ← conversation metadata
///   AI_Voice_Genie/users/{uid}/conversations/{id}/messages/{id}  ← messages
///
/// Hive cache:
///   Key: 'messages_{conversationId}' → JSON-encoded List<MessageModel>
///   Used for instant load on conversation re-open.
class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final StorageService _storage;

  ChatRepositoryImpl({
    FirebaseFirestore? firestore,
    StorageService? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService();

  // ── Conversation Operations ───────────────────────────────────────────────

  @override
  Future<ConversationModel> createConversation({
    required String uid,
    required String firstMessagePreview,
    required ConversationCapability capability,
    required AiProviderId firstProvider,
  }) async {
    try {
      final conversationId = const Uuid().v4();
      final docRef = _firestore.doc(
        FirebaseCollections.conversationDoc(uid, conversationId),
      );

      // Truncate preview to 80 chars for title
      final title = firstMessagePreview.length > 80
          ? '${firstMessagePreview.substring(0, 80)}...'
          : firstMessagePreview;

      final model = ConversationModel(
        id: conversationId,
        title: title,
        lastMessage: firstMessagePreview,
        messageCount: 0,
        capability: capability,
        lastProvider: firstProvider,
      );

      await docRef.set({
        ...model.toFirestore(),
        FirebaseCollections.fieldConversationCreatedAt:
            FieldValue.serverTimestamp(),
        FirebaseCollections.fieldConversationLastMessageAt:
            FieldValue.serverTimestamp(),
        FirebaseCollections.fieldConversationUpdatedAt:
            FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Conversation created: $conversationId');
      return model;
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.saveFailed,
        technicalMessage: 'createConversation failed: ${e.code}',
      );
    }
  }

  @override
  Future<void> updateConversationMetadata({
    required String uid,
    required String conversationId,
    required String lastMessage,
    required AiProviderId lastProvider,
    required int newMessageCount,
  }) async {
    try {
      await _firestore
          .doc(FirebaseCollections.conversationDoc(uid, conversationId))
          .update({
        FirebaseCollections.fieldConversationLastMessage:
            lastMessage.length > 100
                ? '${lastMessage.substring(0, 100)}...'
                : lastMessage,
        FirebaseCollections.fieldConversationLastProvider: lastProvider.id,
        FirebaseCollections.fieldConversationMessageCount: newMessageCount,
        FirebaseCollections.fieldConversationLastMessageAt:
            FieldValue.serverTimestamp(),
        FirebaseCollections.fieldConversationUpdatedAt:
            FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('⚠️ updateConversationMetadata failed: ${e.code}');
      // Non-fatal — metadata update failure does not affect the user experience
    }
  }

  @override
  Future<ConversationModel?> getConversation({
    required String uid,
    required String conversationId,
  }) async {
    try {
      final doc = await _firestore
          .doc(FirebaseCollections.conversationDoc(uid, conversationId))
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return ConversationModel.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('⚠️ getConversation error: $e');
      return null;
    }
  }

  @override
  Future<void> deleteConversation({
    required String uid,
    required String conversationId,
  }) async {
    try {
      // Delete all messages in the subcollection first
      final messagesRef = _firestore
          .collection(FirebaseCollections.conversationDoc(uid, conversationId))
          .doc(FirebaseCollections.messages);

      // Firestore does not auto-delete subcollections — batch delete messages
      final messagesSnap = await _firestore
          .collection(
            '${FirebaseCollections.conversationDoc(uid, conversationId)}'
            '/${FirebaseCollections.messages}',
          )
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation document itself
      batch.delete(
        _firestore.doc(
          FirebaseCollections.conversationDoc(uid, conversationId),
        ),
      );

      await batch.commit();

      // Clear Hive cache for this conversation
      await _storage.setConversationCache(
        '${StorageKeys.lastOpenConversationId}_$conversationId',
        null,
      );

      debugPrint('🗑️ Conversation deleted: $conversationId');
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.deleteFailed,
        technicalMessage: 'deleteConversation failed: ${e.code}',
      );
    }
  }

  @override
  Future<List<ConversationModel>> getConversations({
    required String uid,
    int limit = 15,
    DocumentSnapshot? afterDocument,
  }) async {
    try {
      // Build paginated query — newest first
      Query query = _firestore
          .collection(
            '${FirebaseCollections.root}/${FirebaseCollections.users}'
            '/$uid/${FirebaseCollections.conversations}',
          )
          .orderBy(
            FirebaseCollections.fieldConversationLastMessageAt,
            descending: true,
          )
          .limit(limit);

      // Apply cursor for pagination
      if (afterDocument != null) {
        query = query.startAfterDocument(afterDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ConversationModel.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getConversations failed: ${e.code}',
      );
    }
  }

  // ── Message Operations ────────────────────────────────────────────────────

  @override
  Future<void> saveMessages({
    required String uid,
    required String conversationId,
    required List<MessageModel> messages,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final message in messages) {
        final docRef = _firestore.doc(
          FirebaseCollections.messageDoc(uid, conversationId, message.id),
        );
        batch.set(docRef, message.toFirestore());
      }

      await batch.commit();
      debugPrint(
        '✅ Saved ${messages.length} messages to conversation $conversationId',
      );
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.saveFailed,
        technicalMessage: 'saveMessages failed: ${e.code}',
      );
    }
  }

  @override
  Future<List<MessageModel>> getMessages({
    required String uid,
    required String conversationId,
    int limit = 30,
    DocumentSnapshot? beforeDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(
            '${FirebaseCollections.conversationDoc(uid, conversationId)}'
            '/${FirebaseCollections.messages}',
          )
          .orderBy(FirebaseCollections.fieldMessageTimestamp, descending: true)
          .limit(limit);

      if (beforeDocument != null) {
        query = query.startAfterDocument(beforeDocument);
      }

      final snapshot = await query.get();

      // Reverse to chronological order (oldest first for display)
      final messages = snapshot.docs
          .map(
            (doc) => MessageModel.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList()
          .reversed
          .toList();

      return messages;
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.loadFailed,
        technicalMessage: 'getMessages failed: ${e.code}',
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
      final encoded = jsonEncode(
        messages.map((m) => m.toFirestore()..['id'] = m.id).toList(),
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
            (item) => MessageModel.fromFirestore(
              item['id'] as String? ?? '',
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
