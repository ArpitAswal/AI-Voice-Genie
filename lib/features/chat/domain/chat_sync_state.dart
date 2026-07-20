/// Per-user sync state persisted in Hive.
///
/// Tracks when data was last synced from Firestore so that incremental
/// sync can fetch only changed records instead of the full collection.
///
/// Also stores the `deleteAllCutoff` timestamp to prevent stale Firestore
/// snapshots from resurrecting locally-deleted conversations after a
/// delete-all operation.
///
/// Hive box: `chat_sync_state_box`
/// Key: `{uid}`
class ChatSyncState {
  /// When the conversation list was last successfully synced from Firestore.
  /// Used to query only conversations updated after this timestamp.
  final DateTime? lastConversationSyncAt;

  /// Per-conversation timestamp of the last successful message sync.
  /// Key: conversationId, Value: ISO-8601 sync timestamp.
  final Map<String, String> lastMessageSyncAtByConversation;

  /// When delete-all was triggered. Remote snapshot merge ignores any
  /// conversation whose `createdAt` / `lastMessageAt` is before this cutoff,
  /// preventing deleted data from reappearing via Firestore streams.
  /// Cleared after the delete-all outbox task succeeds.
  final DateTime? activeDeleteAllCutoff;

  /// When the outbox was last fully drained (all pending tasks processed).
  final DateTime? lastSuccessfulOutboxDrainAt;

  const ChatSyncState({
    this.lastConversationSyncAt,
    this.lastMessageSyncAtByConversation = const {},
    this.activeDeleteAllCutoff,
    this.lastSuccessfulOutboxDrainAt,
  });

  // ── Hive serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'lastConversationSyncAt': lastConversationSyncAt?.toIso8601String(),
      'lastMessageSyncAtByConversation': lastMessageSyncAtByConversation,
      'activeDeleteAllCutoff': activeDeleteAllCutoff?.toIso8601String(),
      'lastSuccessfulOutboxDrainAt':
          lastSuccessfulOutboxDrainAt?.toIso8601String(),
    };
  }

  factory ChatSyncState.fromMap(Map<dynamic, dynamic> map) {
    // Reconstruct the per-conversation sync map safely from dynamic keys
    final rawMap = map['lastMessageSyncAtByConversation'];
    final Map<String, String> syncMap = rawMap is Map
        ? rawMap.map((k, v) => MapEntry(k.toString(), v.toString()))
        : {};

    return ChatSyncState(
      lastConversationSyncAt: map['lastConversationSyncAt'] != null
          ? DateTime.tryParse(map['lastConversationSyncAt'] as String)
          : null,
      lastMessageSyncAtByConversation: syncMap,
      activeDeleteAllCutoff: map['activeDeleteAllCutoff'] != null
          ? DateTime.tryParse(map['activeDeleteAllCutoff'] as String)
          : null,
      lastSuccessfulOutboxDrainAt: map['lastSuccessfulOutboxDrainAt'] != null
          ? DateTime.tryParse(map['lastSuccessfulOutboxDrainAt'] as String)
          : null,
    );
  }

  ChatSyncState copyWith({
    DateTime? lastConversationSyncAt,
    Map<String, String>? lastMessageSyncAtByConversation,
    DateTime? activeDeleteAllCutoff,
    DateTime? lastSuccessfulOutboxDrainAt,
    bool clearDeleteAllCutoff = false,
  }) {
    return ChatSyncState(
      lastConversationSyncAt:
          lastConversationSyncAt ?? this.lastConversationSyncAt,
      lastMessageSyncAtByConversation: lastMessageSyncAtByConversation ??
          this.lastMessageSyncAtByConversation,
      // Allow explicitly clearing the cutoff after delete-all completes
      activeDeleteAllCutoff: clearDeleteAllCutoff
          ? null
          : (activeDeleteAllCutoff ?? this.activeDeleteAllCutoff),
      lastSuccessfulOutboxDrainAt:
          lastSuccessfulOutboxDrainAt ?? this.lastSuccessfulOutboxDrainAt,
    );
  }
}
