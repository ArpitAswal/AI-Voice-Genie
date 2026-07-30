import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/services/storage_service.dart';
import '../domain/chat_outbox_task.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../domain/local_conversation_record.dart';
import '../domain/local_message_record.dart';
import '../domain/message_model.dart';
import 'chat_outbox_store.dart';
import 'chat_sync_service.dart';
import 'local_chat_store.dart';

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
          lastProvider: aiMessage.modelRequest,
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
              aiMessage.modelRequest?.id,
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
            imageUrls: message.imageUrls ?? cached.imageUrls,
            pdfInfo: message.pdfInfo ?? cached.pdfInfo);
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
      // 1. Fetch fresh data from Firestore
      final snapshot = await _firestore
          .collection(FirebaseCollections.conversationsCollection(uid))
          .orderBy(FirebaseCollections.fieldConversationLastMessageAt,
              descending: true)
          .get(const GetOptions(source: Source.server));

      // 2. Merge into Hive cache (respecting local pending/deleted states)
      for (final doc in snapshot.docs) {
        final remoteConv = ConversationModel.fromFirestore(doc.id, doc.data());
        final localKey = '${uid}_${remoteConv.id}';
        final rawLocal = LocalChatStore.instance.conversationsBox.get(localKey);

        if (rawLocal != null) {
          try {
            final localRecord =
                LocalConversationRecord.fromMap(rawLocal as Map);
            // Skip overwrite if local has pending writes or was deleted
            if (localRecord.syncStatus == SyncStatus.pendingCreate ||
                localRecord.syncStatus == SyncStatus.pendingUpdate ||
                localRecord.syncStatus == SyncStatus.pendingDelete ||
                localRecord.isDeleted) {
              continue;
            }
          } catch (_) {}
        }

        await LocalChatStore.instance.saveConversation(
          LocalConversationRecord(
            uid: uid,
            conversationId: remoteConv.id,
            title: remoteConv.title,
            lastMessage: remoteConv.lastMessage,
            lastMessageAt: remoteConv.lastMessageAt,
            createdAt: remoteConv.createdAt,
            capability: remoteConv.capability,
            lastProvider: remoteConv.lastProvider,
            syncStatus: SyncStatus.synced,
            localUpdatedAt: DateTime.now(),
          ),
        );
      }

      // 3. Return the latest from Hive (which applies local filters)
      final localRecords = LocalChatStore.instance.getConversations(uid);
      return localRecords.map(_toConversationModel).toList();
    } on FirebaseException catch (_) {
      // On failure, fallback to returning what we have in the Hive cache.
      // Even if empty, it's a valid local state (e.g. they just deleted all).
      final localRecords = LocalChatStore.instance.getConversations(uid);
      return localRecords.map(_toConversationModel).toList();
    }
  }

  @override
  Future<void> updateConversationTitle({
    required String uid,
    required String conversationId,
    required String newTitle,
  }) async {
    try {
      await _firestore
          .doc(FirebaseCollections.conversationDoc(uid, conversationId))
          .update({
        FirebaseCollections.fieldConversationTitle: newTitle,
      });
    } on FirebaseException catch (e) {
      throw ChatException(
        ChatErrorCodes.saveFailed,
        technicalMessage: 'updateConversationTitle failed: ${e.code}',
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

      // Fetch in pages of 500 (Firestore batch write limit).
      // We loop until there are no documents left in this subcollection.
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
      final cachedList = sortedMessages.map((m) => m.toCacheMap()).toList();
      final encoded = await Isolate.run(() => jsonEncode(cachedList));
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

  // ── Offline-First Stream Methods ───────────────────────────────────────

  @override
  Stream<List<ConversationModel>> watchConversations(String uid) {
    // Delegate to LocalChatStore, then map LocalConversationRecord -> ConversationModel
    // so the rest of the app can continue using ConversationModel without change.
    return LocalChatStore.instance
        .watchConversations(uid)
        .map((records) => records.map(_toConversationModel).toList());
  }

  @override
  Stream<List<MessageModel>> watchMessages({
    required String uid,
    required String conversationId,
  }) {
    // Delegate to LocalChatStore and map LocalMessageRecord -> MessageModel
    return LocalChatStore.instance
        .watchMessages(uid, conversationId)
        .map((records) => records.map((r) => r.toMessageModel()).toList());
  }

  // ── Offline-First Mutation Commands ───────────────────────────────────

  @override
  Future<void> createOrAppendMessagePair({
    required String uid,
    required ConversationModel conversation,
    required MessageModel userMessage,
    required MessageModel aiMessage,
    required bool isFirstMessage,
  }) async {
    final conversationId = conversation.id;
    final now = DateTime.now();

    // ── Step 1: Write conversation metadata to Hive ───────────────────────────
    // This is the local-first write. The UI stream updates immediately.
    final hasAiContent = aiMessage.content.trim().isNotEmpty;
    final effectiveLastMessage =
        hasAiContent ? aiMessage.content : userMessage.content;
    final effectiveLastMessageAt =
        hasAiContent ? aiMessage.timestamp : userMessage.timestamp;

    final existingRecord =
        LocalChatStore.instance.getConversation(uid, conversationId);
    final isNewConversation = existingRecord == null;

    final convRecord = LocalConversationRecord(
      uid: uid,
      conversationId: conversationId,
      title: conversation.title,
      lastMessage: effectiveLastMessage,
      lastMessageAt: effectiveLastMessageAt,
      createdAt: existingRecord?.createdAt ?? DateTime.now(),
      capability: conversation.capability,
      lastProvider: aiMessage.modelRequest,
      localUpdatedAt: now,
      // New conversations start as pendingCreate; subsequent messages are pendingUpdate
      syncStatus: isNewConversation
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate,
    );
    await LocalChatStore.instance.saveConversation(convRecord);

    // ── Step 2: Write both messages individually to Hive ─────────────────────
    await LocalChatStore.instance.saveMessage(
      LocalMessageRecord.fromMessageModel(
        userMessage,
        uid: uid,
        conversationId: conversationId,
        syncStatus: SyncStatus.pendingCreate,
      ),
    );
    await LocalChatStore.instance.saveMessage(
      LocalMessageRecord.fromMessageModel(
        aiMessage,
        uid: uid,
        conversationId: conversationId,
        syncStatus: SyncStatus.pendingCreate,
      ),
    );

    // ── Step 3: Enqueue outbox task for background Firestore sync ─────────────
    // Build the full Firestore payload now so the sync worker has everything
    // it needs even if the conversation object is no longer in memory.
    final updatedConv = conversation.copyWith(
      lastMessage: effectiveLastMessage,
      lastMessageAt: effectiveLastMessageAt,
      lastProvider: aiMessage.modelRequest,
    );

    // Deterministic idempotency key prevents duplicate Firestore writes on retry
    final idempotencyKey =
        'upsertMessagePair:$uid:$conversationId:${userMessage.id}';

    await ChatOutboxStore.instance.enqueue(
      ChatOutboxTask(
        uid: uid,
        type: OutboxTaskType.upsertMessagePair,
        conversationId: conversationId,
        messageIds: [userMessage.id, aiMessage.id],
        payload: {
          'conversation': updatedConv.toFirestore(),
          'userMessage': userMessage.toSyncPayload(),
          'aiMessage': aiMessage.toSyncPayload(),
          'userMessageId': userMessage.id,
          'aiMessageId': aiMessage.id,
          'isFirstMessage': isFirstMessage,
        },
        idempotencyKey: idempotencyKey,
      ),
    );

    ChatSyncService.instance.processOutbox();

    debugPrint(
        '📬 ChatRepositoryImpl: queued upsertMessagePair for $conversationId');
  }

  @override
  Future<void> deleteConversationLocalFirst({
    required String uid,
    required String conversationId,
  }) async {
    // ── Step 1: Mark locally as deleted — hides the conversation from UI instantly ─
    await LocalChatStore.instance.softDeleteConversation(uid, conversationId);

    // ── Step 2: Enqueue outbox task for Firestore delete ────────────────────────
    // Idempotency key ensures retrying the same delete is safe (deleting a
    // missing Firestore doc does not throw; it is a no-op).
    await ChatOutboxStore.instance.enqueue(
      ChatOutboxTask(
        uid: uid,
        type: OutboxTaskType.deleteConversation,
        conversationId: conversationId,
        idempotencyKey: 'deleteConversation:$uid:$conversationId',
      ),
    );

    ChatSyncService.instance.processOutbox();

    debugPrint(
        '🗑️ ChatRepositoryImpl: soft-deleted $conversationId locally, queued remote delete');
  }

  @override
  Future<void> deleteAllConversationsLocalFirst(String uid) async {
    // Capture the cutoff before any local writes to prevent race conditions
    final cutoff = DateTime.now();

    // ── Step 1: Soft-delete all local conversations for this user instantly ─────
    await LocalChatStore.instance.softDeleteAllConversations(uid);

    // ── Step 2: Enqueue a single delete-all outbox task ──────────────────────────
    // One task processes all conversations sequentially in the sync worker,
    // avoiding unbounded Future.wait() that can hit rate limits.
    await ChatOutboxStore.instance.enqueue(
      ChatOutboxTask(
        uid: uid,
        type: OutboxTaskType.deleteAllConversations,
        conversationId: '',
        payload: {'deleteAllCutoff': cutoff.toIso8601String()},
        idempotencyKey:
            'deleteAllConversations:$uid:${cutoff.millisecondsSinceEpoch}',
      ),
    );

    ChatSyncService.instance.processOutbox();

    debugPrint(
        '🗑️ ChatRepositoryImpl: soft-deleted all conversations for uid=$uid, queued remote delete-all');
  }

  // ── Conversion Helpers ───────────────────────────────────────────────────────

  /// Convert a [LocalConversationRecord] to a [ConversationModel] for UI consumption.
  ConversationModel _toConversationModel(LocalConversationRecord r) {
    return ConversationModel(
      id: r.conversationId,
      title: r.title,
      lastMessage: r.lastMessage,
      lastMessageAt: r.lastMessageAt,
      createdAt: r.createdAt,
      capability: r.capability,
      lastProvider: r.lastProvider,
      // Expose sync status so the UI can show a warning badge on syncFailed
      syncStatus: r.syncStatus,
    );
  }
}
