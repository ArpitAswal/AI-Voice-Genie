import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'remote_chat_store.dart';
import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../domain/chat_outbox_task.dart';
import '../domain/chat_sync_state.dart';
import '../domain/conversation_model.dart';
import '../domain/local_conversation_record.dart';
import '../domain/local_message_record.dart';
import '../domain/message_model.dart';
import 'chat_outbox_store.dart';
import 'local_chat_store.dart';

/// Background coordinator that keeps Hive and Firestore in sync.
///
/// Responsibilities:
///   1. Drain the outbox: execute queued Firestore mutations (create, delete).
///   2. Listen to Firestore conversation/message streams and merge changes into Hive.
///   3. React to connectivity changes: retry pending tasks when the device reconnects.
///   4. Stop cleanly on logout so subscriptions don't leak across user sessions.
///
/// Lifecycle:
///   - Call [start(uid)] after successful authentication.
///   - Call [stop()] on sign-out or app dispose.
///
/// Multi-device safety:
///   - All writes use deterministic IDs (same UUID on every device = idempotent Firestore set).
///   - Remote snapshot merges respect local tombstones (pendingDelete wins over remote data).
///   - deleteAllCutoff in ChatSyncState prevents resurrected remote conversations.
///
/// Multi-user / same-device safety:
///   - All Hive keys are prefixed with `{uid}_`.
///   - [stop()] cancels all subscriptions before the next user starts.
///   - StorageService.clearChatBoxes(uid) wipes the previous user's local data on logout.
class ChatSyncService {
  // Singleton — one sync service for the entire app
  static final ChatSyncService instance = ChatSyncService._();
  ChatSyncService._();

  // Dependencies
  final _localStore = LocalChatStore.instance;
  final _outboxStore = ChatOutboxStore.instance;
  final _remote = RemoteChatStore.instance;

  // Current authenticated user — null when stopped
  String? _activeUid;

  // Hive box for per-user sync state (lastSyncAt, deleteAllCutoff, etc.)
  late Box _syncStateBox;

  // Active subscriptions — all cancelled on stop()
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<QuerySnapshot>? _conversationStreamSub;
  final Map<String, StreamSubscription<QuerySnapshot>> _messageStreamSubs = {};

  // Prevents concurrent outbox drain runs
  bool _isDraining = false;

  // Periodic timer to wake up the worker for retries
  Timer? _retryTimer;

  // ── Initialization ─────────────────────────────────────────────────────────

  void initBox(Box syncStateBox) {
    _syncStateBox = syncStateBox;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start sync for an authenticated user.
  ///
  /// Called immediately after login / app startup with a valid session.
  /// Starts the outbox drain, conversation stream, and connectivity monitor.
  Future<void> start(String uid) async {
    // If a previous session is active (e.g., user switched accounts),
    // stop it cleanly before starting the new one
    if (_activeUid != null && _activeUid != uid) {
      await stop();
    }
    _activeUid = uid;

    debugPrint('🔄 ChatSyncService: starting for uid=$uid');

    // Start monitoring network connectivity changes
    _startConnectivityMonitor();

    // Listen to the Firestore conversation collection for remote changes
    _startConversationStream(uid);

    // Drain any outbox tasks that survived from a previous session
    await processOutbox();

    // Start a periodic timer to wake up the worker and retry delayed tasks
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isDraining) {
        processOutbox();
      }
    });
  }

  /// Stop all sync activity and cancel subscriptions.
  ///
  /// Must be called on sign-out. Leaves Hive data intact
  /// (user data is cleared separately in StorageService.clearChatBoxes).
  Future<void> stop() async {
    debugPrint('🛑 ChatSyncService: stopping for uid=$_activeUid');

    await _connectivitySubscription?.cancel();
    await _conversationStreamSub?.cancel();

    // Cancel all per-conversation message stream subscriptions
    for (final sub in _messageStreamSubs.values) {
      await sub.cancel();
    }
    _messageStreamSubs.clear();

    _activeUid = null;
    _isDraining = false;
    _retryTimer?.cancel();
  }

  /// Subscribe to message updates for a specific conversation.
  ///
  /// Called by ChatProvider when a conversation is opened. Remote message
  /// changes (e.g., from another device) flow into Hive and automatically
  /// update the UI via LocalChatStore.watchMessages().
  void watchOpenConversation(String uid, String conversationId) {
    // Avoid duplicate subscriptions
    if (_messageStreamSubs.containsKey(conversationId)) return;

    final sub = _remote.watchMessages(uid, conversationId).listen(
          (snapshot) => _mergeRemoteMessages(uid, conversationId, snapshot),
          onError: (e) => debugPrint(
              '⚠️ ChatSyncService: message stream error for $conversationId: $e'),
        );

    _messageStreamSubs[conversationId] = sub;
  }

  /// Stop watching a specific conversation's messages.
  ///
  /// Called when the user navigates away from ChatDetailScreen.
  Future<void> stopWatchingConversation(String conversationId) async {
    final sub = _messageStreamSubs.remove(conversationId);
    await sub?.cancel();
  }

  // ── Outbox Drain ──────────────────────────────────────────────────────────

  /// Process all due outbox tasks sequentially.
  ///
  /// Sequential processing (not parallel) prevents race conditions on the
  /// same conversation document — e.g., a delete task running after an
  /// upsert task for the same conversation.
  /// This is called automatically on startup, reconnect, and whenever new tasks
  /// are enqueued by the repository.
  Future<void> processOutbox() async {
    if (_activeUid == null) return;
    if (_isDraining) return;

    _isDraining = true;
    try {
      final tasks = _outboxStore.getDueTasks();
      if (tasks.isEmpty) return; // Exit early if nothing to do

      debugPrint('📤 ChatSyncService: draining ${tasks.length} outbox tasks');

      for (final task in tasks) {
        // Check if service was stopped mid-drain
        if (_activeUid == null) break;
        await _executeTask(task);
      }

      // Update the last successful drain timestamp in sync state
      if (_activeUid != null && tasks.isNotEmpty) {
        final state = _getSyncState(_activeUid!);
        await _saveSyncState(
          _activeUid!,
          state.copyWith(lastSuccessfulOutboxDrainAt: DateTime.now()),
        );
      }
    } finally {
      _isDraining = false;
    }
  }

  /// Execute a single outbox task against Firestore.
  ///
  /// Routes the task to the appropriate remote operation based on its type.
  Future<void> _executeTask(ChatOutboxTask task) async {
    await _outboxStore.markProcessing(task.operationId);

    if (task.attemptCount > 0) {
      debugPrint(
          '⚠️ Sync Retry Attempt #${task.attemptCount + 1} for ${task.type.name} '
          '(uid: ${task.uid}, conversationId: ${task.conversationId})');
    }

    try {
      // Fail fast if we know we are offline.
      // This prevents Firebase from hanging the worker indefinitely in its native offline queue,
      // allowing our custom outbox to manage the retry backoff and print logs.
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw Exception('device_offline');
      }

      switch (task.type) {
        case OutboxTaskType.upsertMessagePair:
          await _executeUpsertMessagePair(task);

        case OutboxTaskType.deleteConversation:
          await _executeDeleteConversation(task);

        case OutboxTaskType.deleteAllConversations:
          await _executeDeleteAllConversations(task);

        case OutboxTaskType.updateConversationTitle:
          await _executeUpdateTitle(task);

        case OutboxTaskType.hardDeleteLocalConversation:
          // This task type only manipulates local Hive, not Firestore
          await _localStore.hardDeleteConversation(
              task.uid, task.conversationId);
          await _outboxStore.markSucceeded(task.operationId);
      }
    } on FirebaseException catch (e) {
      // Classify the error to determine retry behavior
      final isRetryable = _isRetryableFirestoreError(e.code);
      await _outboxStore.markFailed(
        task.operationId,
        'FirebaseException: ${e.code} — ${e.message}',
        isRetryable: isRetryable,
      );

      // For non-retryable errors on upsert tasks, mark the local conversation
      // as syncFailed so the UI can show a subtle warning indicator
      if (!isRetryable && task.type == OutboxTaskType.upsertMessagePair) {
        await _localStore.markConversationSyncFailed(
            task.uid, task.conversationId);
      }
    } catch (e) {
      // Unexpected errors — treat as retryable by default
      await _outboxStore.markFailed(
        task.operationId,
        e.toString(),
        isRetryable: true,
      );
    }
  }

  // ── Task Handlers ──────────────────────────────────────────────────────────

  /// Write a conversation document + user + AI message pair to Firestore.
  ///
  /// The payload map was built by ChatRepositoryImpl at the time of enqueue,
  /// containing everything Firestore needs to construct the three documents.
  Future<void> _executeUpsertMessagePair(ChatOutboxTask task) async {
    final payload = task.payload;
    final uid = task.uid;
    final conversationId = task.conversationId;

    // Extract the serialized conversation and messages from the payload
    // We must clone them (Map.from) because mutating the raw payload map
    // directly mutates Hive's in-memory cache, causing serialization errors.
    final rawConv = payload['conversation'] as Map<dynamic, dynamic>?;
    final rawUser = payload['userMessage'] as Map<dynamic, dynamic>?;
    final rawAi = payload['aiMessage'] as Map<dynamic, dynamic>?;
    final isFirstMessage = payload['isFirstMessage'] as bool? ?? false;

    if (rawConv == null || rawUser == null || rawAi == null) {
      // Corrupt payload — mark dead to prevent infinite retries
      await _outboxStore.markFailed(task.operationId, 'Corrupt payload',
          isRetryable: false);
      return;
    }

    final convData = Map<String, dynamic>.from(rawConv);
    final userMsgData = Map<String, dynamic>.from(rawUser);
    final aiMsgData = Map<String, dynamic>.from(rawAi);

    // Replace the ISO string timestamp (from toCacheMap) with the Firestore server timestamp
    userMsgData[FirebaseCollections.fieldMessageTimestamp] =
        FieldValue.serverTimestamp();
    aiMsgData[FirebaseCollections.fieldMessageTimestamp] =
        FieldValue.serverTimestamp();
    convData[FirebaseCollections.fieldConversationLastMessageAt] =
        FieldValue.serverTimestamp();

    final userMessageId = payload['userMessageId'] as String? ?? '';
    final aiMessageId = payload['aiMessageId'] as String? ?? '';

    await _remote.saveMessagePairBatch(
      uid: uid,
      conversationId: conversationId,
      conversationData: convData,
      userMessageData: userMsgData,
      aiMessageData: aiMsgData,
      userMessageId: userMessageId,
      aiMessageId: aiMessageId,
      isFirstMessage: isFirstMessage,
    );

    // Mark local conversation as synced after Firestore confirms
    await _localStore.markConversationSynced(uid, conversationId);
    await _outboxStore.markSucceeded(task.operationId);

    debugPrint('✅ ChatSyncService: upserted message pair for $conversationId');
  }

  /// Delete all messages and the conversation document from Firestore.
  Future<void> _executeDeleteConversation(ChatOutboxTask task) async {
    await _remote.deleteConversationRemote(
        uid: task.uid, conversationId: task.conversationId);

    // Hard-delete local Hive records now that remote is confirmed clean
    await _localStore.hardDeleteConversation(task.uid, task.conversationId);
    await _outboxStore.markSucceeded(task.operationId);

    debugPrint(
        '✅ ChatSyncService: deleted conversation ${task.conversationId} remotely');
  }

  /// Delete all conversations for a user up to the cutoff timestamp.
  Future<void> _executeDeleteAllConversations(ChatOutboxTask task) async {
    final cutoffStr = task.payload['deleteAllCutoff'] as String?;
    final cutoff = cutoffStr != null ? DateTime.tryParse(cutoffStr) : null;

    await _remote.deleteAllConversationsRemote(
        uid: task.uid, beforeCutoff: cutoff);

    // Clear the deleteAllCutoff from sync state now that Firestore is clean
    final state = _getSyncState(task.uid);
    await _saveSyncState(
      task.uid,
      state.copyWith(clearDeleteAllCutoff: true),
    );

    await _outboxStore.markSucceeded(task.operationId);
    debugPrint(
        '✅ ChatSyncService: deleted all conversations for uid=${task.uid}');
  }

  /// Update only the conversation title field in Firestore.
  Future<void> _executeUpdateTitle(ChatOutboxTask task) async {
    final newTitle = task.payload['title'] as String? ?? '';
    await _remote.updateConversationTitle(
      uid: task.uid,
      conversationId: task.conversationId,
      title: newTitle,
    );
    await _outboxStore.markSucceeded(task.operationId);
  }

  // ── Remote Stream Merge ────────────────────────────────────────────────────

  /// Start listening to Firestore conversation snapshots for this user.
  ///
  /// Uses an incremental query: only fetches conversations updated after
  /// the last known sync timestamp, reducing bandwidth and Firestore reads.
  void _startConversationStream(String uid) {
    // Cancel any existing subscription before creating a new one
    _conversationStreamSub?.cancel();

    _conversationStreamSub = _remote.watchConversations(uid).listen(
          (snapshot) => _mergeRemoteConversations(uid, snapshot),
          onError: (e) =>
              debugPrint('⚠️ ChatSyncService: conversation stream error: $e'),
        );
  }

  /// Merge remote Firestore conversation snapshots into Hive.
  ///
  /// Conflict resolution rules:
  ///   - If local record has `pendingDelete` → local tombstone wins; skip remote update.
  ///   - If local record has `pendingCreate` or `pendingUpdate` → preserve local data.
  ///   - If local record is `synced` → remote wins (newer remote data replaces local).
  ///   - If the conversation's `lastMessageAt` is before the `deleteAllCutoff` → skip
  ///     (prevents stale Firestore records from reappearing after delete-all).
  Future<void> _mergeRemoteConversations(
      String uid, QuerySnapshot snapshot) async {
    final syncState = _getSyncState(uid);
    final cutoff = syncState.activeDeleteAllCutoff;
    final now = DateTime.now();

    for (final change in snapshot.docChanges) {
      final doc = change.doc;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final conversationId = doc.id;
      final remoteModel = ConversationModel.fromFirestore(conversationId, data);

      // Guard: if delete-all is active, ignore conversations that predate the cutoff
      if (cutoff != null) {
        final remoteTime =
            remoteModel.lastMessageAt ?? remoteModel.createdAt ?? DateTime(0);
        if (!remoteTime.isAfter(cutoff)) {
          debugPrint(
              '🛡️ ChatSyncService: skipping $conversationId (before deleteAllCutoff)');
          continue;
        }
      }

      // Handle removed documents from Firestore (deleted remotely on another device)
      if (change.type == DocumentChangeType.removed) {
        final local = _localStore.getConversation(uid, conversationId);
        // Only hard-delete locally if we don't have a local pending-delete
        // (which means we already know about the deletion)
        if (local != null && local.syncStatus != SyncStatus.pendingDelete) {
          await _localStore.hardDeleteConversation(uid, conversationId);
        }
        continue;
      }

      // Check local record to determine merge strategy
      final local = _localStore.getConversation(uid, conversationId);

      if (local != null) {
        // Local tombstone wins — never resurrect a conversation marked for deletion
        if (local.syncStatus == SyncStatus.pendingDelete || local.isDeleted) {
          continue;
        }

        // Pending local changes win — do not overwrite in-flight user data
        if (local.syncStatus == SyncStatus.pendingCreate ||
            local.syncStatus == SyncStatus.pendingUpdate) {
          continue;
        }
      }

      // Remote wins: write or update local record as synced
      final record = LocalConversationRecord(
        uid: uid,
        conversationId: conversationId,
        title: remoteModel.title,
        lastMessage: remoteModel.lastMessage,
        lastMessageAt: remoteModel.lastMessageAt,
        createdAt: remoteModel.createdAt,
        messageCount: remoteModel.messageCount,
        capability: remoteModel.capability,
        lastProvider: remoteModel.lastProvider,
        syncStatus: SyncStatus.synced,
        localUpdatedAt: now,
        remoteUpdatedAt: remoteModel.lastMessageAt ?? now,
        lastSyncedAt: now,
      );

      await _localStore.saveConversation(record);
    }

    // Record that we've synced the conversation list up to now
    await _saveSyncState(
      uid,
      syncState.copyWith(lastConversationSyncAt: now),
    );
  }

  /// Merge remote Firestore message snapshots for an open conversation into Hive.
  ///
  /// Conflict resolution rules:
  ///   - Remote messages never overwrite locally pending messages.
  ///   - Removed messages on Firestore are soft-deleted locally.
  Future<void> _mergeRemoteMessages(
      String uid, String conversationId, QuerySnapshot snapshot) async {
    final now = DateTime.now();
    final recordsToSave = <LocalMessageRecord>[];

    for (final change in snapshot.docChanges) {
      final doc = change.doc;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // Firestore document IDs use `UserRef-{id}` and `AIRef-{id}` prefixes
      final docId = doc.id;
      final messageId =
          docId.replaceFirst('UserRef-', '').replaceFirst('AIRef-', '');

      // Handle messages deleted remotely (e.g., moderation or another device)
      if (change.type == DocumentChangeType.removed) {
        await _localStore.hardDeleteMessage(uid, conversationId, messageId);
        continue;
      }

      final message = MessageModel.fromFirestore(docId, data);

      // Check if a local record exists
      final localKey = '${uid}_${conversationId}_$messageId';
      // A locally-pending message must not be overwritten by remote snapshot
      // (the remote copy will match once Firestore confirms the write)
      final rawLocal = _localStore.messagesBox.get(localKey);
      if (rawLocal != null) {
        try {
          final localRecord = LocalMessageRecord.fromMap(rawLocal as Map);
          if (localRecord.syncStatus == SyncStatus.pendingCreate ||
              localRecord.syncStatus == SyncStatus.pendingUpdate) {
            continue;
          }
        } catch (_) {
          // Corrupt record — fall through and let remote win
        }
      }

      // Remote wins: collect to save in batch
      final record = LocalMessageRecord.fromMessageModel(
        message,
        uid: uid,
        conversationId: conversationId,
        syncStatus: SyncStatus.synced,
      ).copyWith(remoteUpdatedAt: now);

      recordsToSave.add(record);
    }

    if (recordsToSave.isNotEmpty) {
      await _localStore.saveMessagesBatch(recordsToSave);
    }
  }

  // ── Connectivity Monitor ──────────────────────────────────────────────────

  /// Listen for network connectivity changes.
  ///
  /// When the device reconnects after being offline:
  ///   1. Reset any tasks that were cooling off (10-min backoff) back to
  ///      immediately due so they are retried right away.
  ///   2. Trigger a fresh outbox drain.
  ///
  /// Uses connectivity_plus, but treats it as a hint, not the sole truth —
  /// the actual Firestore operation result determines success or failure.
  void _startConnectivityMonitor() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final isConnected =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (isConnected && !_isDraining) {
        debugPrint(
            '🌐 ChatSyncService: Network reconnected. Resetting cooldowns.');
        await _outboxStore.resetCooldownTasksForRetry();
        await processOutbox();
      }
    });
  }

  // ── Sync State Helpers ────────────────────────────────────────────────────

  /// Read sync state for a user from Hive. Returns empty state if none exists.
  ChatSyncState _getSyncState(String uid) {
    final raw = _syncStateBox.get(uid);
    if (raw == null) return const ChatSyncState();
    try {
      return ChatSyncState.fromMap(raw as Map);
    } catch (_) {
      return const ChatSyncState();
    }
  }

  /// Persist updated sync state for a user.
  Future<void> _saveSyncState(String uid, ChatSyncState state) async {
    await _syncStateBox.put(uid, state.toMap());
  }

  // ── Error Classification ──────────────────────────────────────────────────

  /// Determine whether a Firestore error code should be retried.
  ///
  /// Retryable: network issues, server unavailable, rate limits
  /// Non-retryable: permission errors, auth failures, bad request payloads
  bool _isRetryableFirestoreError(String? code) {
    const nonRetryable = {
      'permission-denied',
      'unauthenticated',
      'invalid-argument',
      'not-found', // Trying to update a doc that never existed
    };
    return !nonRetryable.contains(code);
  }
}
