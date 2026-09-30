import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firebase_collections.dart';

/// Firestore access layer for chat data.
///
/// Owns all Firestore paths, serialization, and remote operations.
/// Used exclusively by ChatSyncService — UI layers never call this directly.
/// All methods are idempotent where possible (e.g., batch.set with merge).
class RemoteChatStore {
  static final RemoteChatStore instance = RemoteChatStore._();
  RemoteChatStore._();

  FirebaseFirestore get _firestore => FirebaseCollections.firestore;

  // ── Write Operations ───────────────────────────────────────────────────────

  /// Write a conversation document + user message + AI message as a single batch.
  ///
  /// Uses `batch.set()` which is idempotent — re-running the same task
  /// (e.g., on retry) writes the same data and does not duplicate anything.
  Future<void> saveMessagePairBatch({
    required String uid,
    required String conversationId,
    required Map<String, dynamic> conversationData,
    required Map<String, dynamic> userMessageData,
    required Map<String, dynamic> aiMessageData,
    required String userMessageId,
    required String aiMessageId,
    required bool isFirstMessage,
  }) async {
    final batch = _firestore.batch();

    final convRef = _firestore.doc(
      FirebaseCollections.conversationDoc(uid, conversationId),
    );

    if (isFirstMessage) {
      // First message: create the conversation document with server timestamp
      batch.set(convRef, {
        ...conversationData,
        FirebaseCollections.fieldConversationCreatedAt:
            FieldValue.serverTimestamp(),
        FirebaseCollections.fieldConversationLastMessageAt: conversationData[
            FirebaseCollections.fieldConversationLastMessageAt],
      });
    } else {
      // Subsequent messages: update only the preview fields
      batch.update(convRef, {
        FirebaseCollections.fieldConversationLastMessage:
            conversationData[FirebaseCollections.fieldConversationLastMessage],
        FirebaseCollections.fieldConversationLastMessageAt: conversationData[
            FirebaseCollections.fieldConversationLastMessageAt],
        FirebaseCollections.fieldConversationLastProvider:
            conversationData[FirebaseCollections.fieldConversationLastProvider],
      });
    }

    // Write user and AI messages as separate documents
    final userRef = _firestore.doc(
      FirebaseCollections.messageDoc(
          uid, conversationId, 'UserRef-$userMessageId'),
    );
    final aiRef = _firestore.doc(
      FirebaseCollections.messageDoc(uid, conversationId, 'AIRef-$aiMessageId'),
    );

    batch.set(userRef, userMessageData);
    batch.set(aiRef, aiMessageData);

    await batch.commit();
    debugPrint('✅ RemoteChatStore: batch committed for $conversationId');
  }

  /// Update only the title field of a conversation document.
  Future<void> updateConversationTitle({
    required String uid,
    required String conversationId,
    required String title,
  }) async {
    await _firestore
        .doc(FirebaseCollections.conversationDoc(uid, conversationId))
        .update({FirebaseCollections.fieldConversationTitle: title});
  }

  // ── Delete Operations ──────────────────────────────────────────────────────

  /// Delete all messages and the conversation document from Firestore.
  ///
  /// Message documents are deleted in chunks of 500 to respect the
  /// Firestore batch write limit.
  Future<void> deleteConversationRemote({
    required String uid,
    required String conversationId,
  }) async {
    final messagesRef = _firestore.collection(
      FirebaseCollections.messagesCollection(uid, conversationId),
    );

    // Chunk deletions by 500 (Firestore batch limit)
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

    // Delete the conversation document itself
    await _firestore
        .doc(FirebaseCollections.conversationDoc(uid, conversationId))
        .delete();

    debugPrint('🗑️ RemoteChatStore: deleted $conversationId from Firestore');
  }

  /// Delete all conversations for a user up to a cutoff timestamp.
  ///
  /// Processes conversations sequentially in pages to avoid rate limits
  /// and unbounded Future.wait() over large collections.
  /// Only deletes conversations whose lastMessageAt is before [beforeCutoff]
  /// (if provided), ensuring newly created conversations after delete-all
  /// are preserved.
  Future<void> deleteAllConversationsRemote({
    required String uid,
    DateTime? beforeCutoff,
  }) async {
    Query query =
        _firestore.collection(FirebaseCollections.conversationsCollection(uid));

    // Apply cutoff filter if provided (prevents deleting post-cutoff conversations)
    if (beforeCutoff != null) {
      query = query.where(
        FirebaseCollections.fieldConversationLastMessageAt,
        isLessThanOrEqualTo: Timestamp.fromDate(beforeCutoff),
      );
    }

    // Page through conversations and delete each one sequentially
    DocumentSnapshot? lastDoc;
    while (true) {
      var pageQuery = query.limit(20);
      if (lastDoc != null) pageQuery = pageQuery.startAfterDocument(lastDoc);

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        await deleteConversationRemote(uid: uid, conversationId: doc.id);
      }

      lastDoc = snapshot.docs.last;
      if (snapshot.docs.length < 20) break;
    }

    debugPrint('🗑️ RemoteChatStore: deleted all conversations for uid=$uid');
  }

  // ── Stream Operations ─────────────────────────────────────────────────────

  /// Firestore real-time stream of all conversations for a user.
  ///
  /// Used by ChatSyncService to merge remote changes into Hive.
  /// Ordered descending so newest conversations are processed first.
  Stream<QuerySnapshot> watchConversations(String uid) {
    return _firestore
        .collection(FirebaseCollections.conversationsCollection(uid))
        .orderBy(
          FirebaseCollections.fieldConversationLastMessageAt,
          descending: true,
        )
        .snapshots();
  }

  /// Firestore real-time stream of all messages for a single conversation.
  ///
  /// Used by ChatSyncService when a conversation is opened, so that
  /// messages updated on another device appear on this device instantly.
  Stream<QuerySnapshot> watchMessages(String uid, String conversationId,
      {int? limit}) {
    Query query = _firestore
        .collection(FirebaseCollections.messagesCollection(uid, conversationId))
        .orderBy(FirebaseCollections.fieldMessageTimestamp, descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }
  // ── Pagination Operations ──────────────────────────────────────────────────

  Future<QuerySnapshot> fetchConversationPage({
    required String uid,
    required int limit,
    DocumentSnapshot? startAfterDocument,
  }) async {
    Query query = _firestore
        .collection(FirebaseCollections.conversationsCollection(uid))
        .orderBy(FirebaseCollections.fieldConversationLastMessageAt,
            descending: true)
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }
    return query.get();
  }

  Future<QuerySnapshot> fetchLatestMessagePage({
    required String uid,
    required String conversationId,
    required int limit,
  }) async {
    return _firestore
        .collection(FirebaseCollections.messagesCollection(uid, conversationId))
        .orderBy(FirebaseCollections.fieldMessageTimestamp, descending: true)
        .limit(limit)
        .get();
  }

  Future<QuerySnapshot> fetchOlderMessagePage({
    required String uid,
    required String conversationId,
    required int limit,
    DocumentSnapshot? startAfterDocument,
  }) async {
    Query query = _firestore
        .collection(FirebaseCollections.messagesCollection(uid, conversationId))
        .orderBy(FirebaseCollections.fieldMessageTimestamp, descending: true)
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }
    return query.get();
  }
}
