import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/enums/app_enums.dart';
import '../domain/local_conversation_record.dart';
import '../domain/local_message_record.dart';
import '../domain/conversation_page_cursor.dart';
import '../domain/message_page_cursor.dart';

/// Local Hive-backed store for conversations and messages.
///
/// This is the single source of truth for all chat UI state.
/// No UI widget or provider reads Firestore directly — they only read
/// from this store. Firestore changes flow in through ChatSyncService,
/// which writes to this store, triggering reactive UI updates.
///
/// Design principles:
///   - All reads return local Hive data instantly.
///   - Streams re-emit whenever the underlying Hive box changes.
///   - isDeleted=true records are filtered from all read operations so
///     that soft-deleted conversations/messages disappear immediately.
///   - Each user's data is namespaced under a `{uid}_` prefix, ensuring
///     complete isolation when multiple users sign in on the same device.
class LocalChatStore {
  // Singleton instance — one store for the entire app lifetime
  static final LocalChatStore instance = LocalChatStore._();
  LocalChatStore._();

  // Hive box references — assigned during StorageService.initialize()
  late Box _conversationsBox;
  late Box _messagesBox;

  // ── Box Initialization ─────────────────────────────────────────────────────

  /// Called by StorageService after the Hive boxes are opened.
  ///
  /// Must be called before any read or write operation.
  void init(Box conversationsBox, Box messagesBox) {
    _conversationsBox = conversationsBox;
    _messagesBox = messagesBox;
  }

  /// Package-visible accessor used by ChatSyncService to check
  /// a single message record during remote snapshot merge without
  /// exposing the full box as public API.
  Box get messagesBox => _messagesBox;

  /// Package-visible accessor used by ChatRepositoryImpl to check
  /// local conversation records during manual fetch merges.
  Box get conversationsBox => _conversationsBox;

  // ── Conversation Operations ────────────────────────────────────────────────

  /// Persist a conversation record to Hive.
  ///
  /// Uses the record's [hiveKey] = `{uid}_{conversationId}` as the Hive key,
  /// so upserts are idempotent: writing the same conversation twice is safe.
  Future<void> saveConversation(LocalConversationRecord record) async {
    await _conversationsBox.put(record.hiveKey, record.toMap());
  }

  /// Read a single conversation record by UID and conversation ID.
  ///
  /// Returns null if no local record exists yet (e.g. before first sync).
  LocalConversationRecord? getConversation(String uid, String conversationId) {
    final key = '${uid}_$conversationId';
    final raw = _conversationsBox.get(key);
    if (raw == null) return null;
    return LocalConversationRecord.fromMap(raw as Map);
  }

  /// Stream of a single conversation's record.
  ///
  /// Emits immediately with the current state, then re-emits on any change to this specific conversation.
  Stream<LocalConversationRecord?> watchConversation(
      String uid, String conversationId) async* {
    yield getConversation(uid, conversationId);

    final key = '${uid}_$conversationId';
    await for (final _ in _conversationsBox.watch(key: key)) {
      yield getConversation(uid, conversationId);
    }
  }

  /// Stream of all non-deleted conversations for a user, sorted newest-first.
  ///
  /// Emits immediately with the current Hive state, then re-emits whenever
  /// any key in the conversations box changes. Only changes that belong to
  /// this user (keyed with `{uid}_` prefix) trigger a new emission.
  Stream<List<LocalConversationRecord>> watchConversations(String uid) async* {
    // Emit the current state immediately for instant UI rendering
    yield _readConversations(uid);

    // Re-emit every time the box changes, filtering to this user's keys only
    await for (final event in _conversationsBox.watch()) {
      final changedKey = event.key?.toString() ?? '';
      if (changedKey.isEmpty || changedKey.startsWith('${uid}_')) {
        yield _readConversations(uid);
      }
    }
  }

  /// Synchronously read and filter all conversations for a user from Hive.
  List<LocalConversationRecord> getConversations(String uid) {
    return _readConversations(uid);
  }

  /// Read and filter all conversations for a user from Hive.
  ///
  /// - Filters out records where `isDeleted = true` (soft-deleted items).
  /// - Sorts by `lastMessageAt` descending (newest conversation first).
  List<LocalConversationRecord> _readConversations(String uid) {
    final prefix = '${uid}_';
    final records = _conversationsBox.keys
        // Only include records belonging to this user
        .where((key) => key.toString().startsWith(prefix))
        .map((key) {
          final raw = _conversationsBox.get(key);
          if (raw == null) return null;
          try {
            return LocalConversationRecord.fromMap(raw as Map);
          } catch (e) {
            // Corrupt Hive entry — skip it gracefully
            debugPrint(
                '⚠️ LocalChatStore: corrupt conversation record at $key: $e');
            return null;
          }
        })
        .whereType<LocalConversationRecord>()
        // Hide soft-deleted conversations and those with pending-delete status
        .where((r) => !r.isDeleted)
        .toList();

    // Sort newest conversation first based on last message timestamp
    records.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(0);
      final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return records;
  }

  /// Read a paginated list of conversations from Hive.
  List<LocalConversationRecord> getConversationPage({
    required String uid,
    required int limit,
    ConversationPageCursor? cursor,
    String? searchQuery,
  }) {
    // Re-use the in-memory sort since we don't have secondary indices yet.
    var records = _readConversations(uid);

    // Apply search filter if present
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      records = records.where((r) {
        final title = r.title.toLowerCase();
        final lastMsg = r.lastMessage.toLowerCase();
        return title.contains(query) || lastMsg.contains(query);
      }).toList();
    }

    // Apply cursor offset
    if (cursor != null) {
      final startIndex = records.indexWhere((r) {
        final rTime = r.lastMessageAt ?? r.createdAt ?? DateTime(0);
        return rTime == cursor.lastMessageAt &&
            r.conversationId == cursor.conversationId;
      });
      if (startIndex != -1) {
        records = records.skip(startIndex + 1).toList();
      }
    }

    return records.take(limit).toList();
  }

  /// Mark a conversation as locally deleted without removing it from Hive yet.
  ///
  /// Sets `isDeleted = true` and `syncStatus = pendingDelete`. The conversation
  /// disappears from `watchConversations()` immediately because the stream
  /// filters out isDeleted records. The actual Hive hard-delete and Firestore
  /// delete happen separately via the outbox worker.
  Future<void> softDeleteConversation(String uid, String conversationId) async {
    final key = '${uid}_$conversationId';
    final existing = _conversationsBox.get(key);
    if (existing == null) return;

    final record = LocalConversationRecord.fromMap(existing as Map);
    await _conversationsBox.put(
      key,
      record
          .copyWith(
            isDeleted: true,
            syncStatus: SyncStatus.pendingDelete,
            deleteRequestedAt: DateTime.now(),
            localUpdatedAt: DateTime.now(),
          )
          .toMap(),
    );

    // Also soft-delete all messages for this conversation
    await _softDeleteMessagesForConversation(uid, conversationId);
  }

  /// Permanently remove a conversation and all its messages from Hive.
  ///
  /// Called ONLY after the remote Firestore delete has been confirmed.
  /// Never call this before remote confirmation or data will be lost offline.
  Future<void> hardDeleteConversation(String uid, String conversationId) async {
    // Remove conversation record
    await _conversationsBox.delete('${uid}_$conversationId');

    // Remove all message records for this conversation
    final prefix = '${uid}_${conversationId}_';
    final keys = _messagesBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final key in keys) {
      await _messagesBox.delete(key);
    }

    debugPrint('🗑️ LocalChatStore: hard-deleted $conversationId from Hive');
  }

  /// Soft-delete all conversations for a user (bulk delete-all flow).
  ///
  /// Marks every conversation as `isDeleted = true` and `pendingDelete`.
  /// The UI empties immediately. The outbox handles remote Firestore deletes.
  Future<void> softDeleteAllConversations(String uid) async {
    final prefix = '${uid}_';
    final keys = _conversationsBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();

    final now = DateTime.now();
    for (final key in keys) {
      final raw = _conversationsBox.get(key);
      if (raw == null) continue;
      try {
        final record = LocalConversationRecord.fromMap(raw as Map);
        await _conversationsBox.put(
          key,
          record
              .copyWith(
                isDeleted: true,
                syncStatus: SyncStatus.pendingDelete,
                deleteRequestedAt: now,
                localUpdatedAt: now,
              )
              .toMap(),
        );
      } catch (_) {
        // Corrupt record — delete it directly
        await _conversationsBox.delete(key);
      }
    }

    // Soft-delete all message records for this user as well
    final msgPrefix = '${uid}_';
    final msgKeys = _messagesBox.keys
        .where((k) => k.toString().startsWith(msgPrefix))
        .toList();
    for (final key in msgKeys) {
      final raw = _messagesBox.get(key);
      if (raw == null) continue;
      try {
        final record = LocalMessageRecord.fromMap(raw as Map);
        await _messagesBox.put(
          key,
          record
              .copyWith(isDeleted: true, syncStatus: SyncStatus.pendingDelete)
              .toMap(),
        );
      } catch (_) {
        await _messagesBox.delete(key);
      }
    }
  }

  /// Hard-delete ALL Hive records for a user.
  ///
  /// Called on logout so one user's data does not bleed into another session
  /// when a different account signs in on the same device.
  Future<void> clearAllForUser(String uid) async {
    final convPrefix = '${uid}_';
    final convKeys = _conversationsBox.keys
        .where((k) => k.toString().startsWith(convPrefix))
        .toList();
    for (final key in convKeys) {
      await _conversationsBox.delete(key);
    }

    final msgKeys = _messagesBox.keys
        .where((k) => k.toString().startsWith(convPrefix))
        .toList();
    for (final key in msgKeys) {
      await _messagesBox.delete(key);
    }

    debugPrint('🗑️ LocalChatStore: cleared all Hive data for uid=$uid');
  }

  // ── Message Operations ─────────────────────────────────────────────────────

  /// Persist a single message record to Hive.
  ///
  /// Uses the record's [hiveKey] = `{uid}_{conversationId}_{messageId}`.
  /// Upserts are idempotent — writing the same message twice is safe.
  Future<void> saveMessage(LocalMessageRecord record) async {
    await _messagesBox.put(record.hiveKey, record.toMap());
  }

  /// Persist multiple message records in a single batch to Hive.
  ///
  /// Using putAll emits a single watch event rather than one per message,
  /// preventing excessive UI rebuilds during Firestore synchronization.
  Future<void> saveMessagesBatch(List<LocalMessageRecord> records) async {
    if (records.isEmpty) return;
    final map = <String, dynamic>{};
    for (final record in records) {
      map[record.hiveKey] = record.toMap();
    }
    await _messagesBox.putAll(map);
  }

  /// Hard-delete a specific message from Hive.
  Future<void> hardDeleteMessage(
      String uid, String conversationId, String messageId) async {
    final key = '${uid}_${conversationId}_$messageId';
    await _messagesBox.delete(key);
  }

  /// Stream of all non-deleted messages for a conversation, sorted chronologically.
  ///
  /// Emits immediately, then re-emits on any box change scoped to this conversation.
  Stream<List<LocalMessageRecord>> watchMessages(
      String uid, String conversationId) async* {
    // Emit current Hive state immediately
    yield _readMessages(uid, conversationId);

    // Re-emit when any message record for this conversation changes
    final prefix = '${uid}_${conversationId}_';
    await for (final event in _messagesBox.watch()) {
      final changedKey = event.key?.toString() ?? '';
      if (changedKey.isEmpty || changedKey.startsWith(prefix)) {
        yield _readMessages(uid, conversationId);
      }
    }
  }

  /// Read and sort all non-deleted messages for a conversation from Hive.
  List<LocalMessageRecord> _readMessages(String uid, String conversationId) {
    final prefix = '${uid}_${conversationId}_';
    final records = _messagesBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) {
          final raw = _messagesBox.get(key);
          if (raw == null) return null;
          try {
            return LocalMessageRecord.fromMap(raw as Map);
          } catch (e) {
            debugPrint('⚠️ LocalChatStore: corrupt message record at $key: $e');
            return null;
          }
        })
        .whereType<LocalMessageRecord>()
        // Hide messages belonging to soft-deleted conversations
        .where((r) => !r.isDeleted)
        .toList();

    // Sort chronologically: oldest message first
    records.sort((a, b) {
      final timeCompare = a.timestamp.compareTo(b.timestamp);
      if (timeCompare != 0) return timeCompare;
      // Tie-break: user message before AI message at same timestamp
      if (a.role != b.role) {
        return a.role == MessageRole.user ? -1 : 1;
      }
      return a.messageId.compareTo(b.messageId);
    });

    return records;
  }

  /// Read the latest page of messages (newest first in terms of query, but returned oldest-first).
  /// For the latest page, we actually want the newest N messages.
  List<LocalMessageRecord> getLatestMessagePage({
    required String uid,
    required String conversationId,
    required int limit,
  }) {
    final allMessages = _readMessages(uid, conversationId);

    // We want the *last* N items of the chronologically sorted list
    // (meaning the newest ones).
    if (allMessages.length <= limit) return allMessages;

    return allMessages.skip(allMessages.length - limit).toList();
  }

  /// Read an older page of messages before a given cursor.
  /// Returned oldest-first.
  List<LocalMessageRecord> getOlderMessagePage({
    required String uid,
    required String conversationId,
    required MessagePageCursor before,
    required int limit,
  }) {
    final allMessages = _readMessages(uid, conversationId);

    final endIndex = allMessages.indexWhere((m) {
      return m.timestamp == before.timestamp && m.messageId == before.messageId;
    });

    if (endIndex <= 0) return []; // None older

    // We want the `limit` items immediately *before* endIndex
    final startIndex = (endIndex - limit < 0) ? 0 : endIndex - limit;

    return allMessages.sublist(startIndex, endIndex);
  }

  /// Soft-delete all messages belonging to a conversation.
  ///
  /// Called internally during [softDeleteConversation].
  Future<void> _softDeleteMessagesForConversation(
      String uid, String conversationId) async {
    final prefix = '${uid}_${conversationId}_';
    final keys = _messagesBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();

    for (final key in keys) {
      final raw = _messagesBox.get(key);
      if (raw == null) continue;
      try {
        final record = LocalMessageRecord.fromMap(raw as Map);
        await _messagesBox.put(
          key,
          record
              .copyWith(
                isDeleted: true,
                syncStatus: SyncStatus.pendingDelete,
              )
              .toMap(),
        );
      } catch (_) {
        await _messagesBox.delete(key);
      }
    }
  }

  /// Update the syncStatus of a conversation record to [SyncStatus.synced].
  ///
  /// Called by ChatSyncService after a successful Firestore write confirms
  /// that the local record has been durably persisted remotely.
  Future<void> markConversationSynced(String uid, String conversationId) async {
    final key = '${uid}_$conversationId';
    final raw = _conversationsBox.get(key);
    if (raw == null) return;
    final record = LocalConversationRecord.fromMap(raw as Map);
    await _conversationsBox.put(
        key,
        record.copyWith(
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          localUpdatedAt: DateTime.now(),
        ));
  }

  /// Update the syncStatus of multiple message records to [SyncStatus.synced].
  ///
  /// Called by ChatSyncService after a successful Firestore write confirms
  /// that the local records have been durably persisted remotely.
  Future<void> markMessagesSynced(
      String uid, String conversationId, List<String> messageIds) async {
    final now = DateTime.now();
    final map = <String, dynamic>{};

    for (final msgId in messageIds) {
      if (msgId.isEmpty) continue;
      final key = '${uid}_${conversationId}_$msgId';
      final raw = _messagesBox.get(key);
      if (raw != null) {
        final record = LocalMessageRecord.fromMap(raw as Map);
        map[key] = record
            .copyWith(
              syncStatus: SyncStatus.synced,
              remoteUpdatedAt: now,
            )
            .toMap();
      }
    }

    if (map.isNotEmpty) {
      await _messagesBox.putAll(map);
    }
  }

  /// Mark a conversation's sync as failed after retries are exhausted
  /// for a non-retryable error.
  Future<void> markConversationSyncFailed(
      String uid, String conversationId) async {
    final key = '${uid}_$conversationId';
    final raw = _conversationsBox.get(key);
    if (raw == null) return;
    final record = LocalConversationRecord.fromMap(raw as Map);
    await _conversationsBox.put(
      key,
      record
          .copyWith(
            syncStatus: SyncStatus.syncFailed,
            localUpdatedAt: DateTime.now(),
          )
          .toMap(),
    );
  }
}
