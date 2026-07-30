import '../../../core/enums/app_enums.dart';
import 'conversation_model.dart';

/// Local Hive record for a single conversation's metadata.
///
/// This is the Hive-first source of truth for the conversation history list.
/// It mirrors the Firestore ConversationModel but adds local sync metadata
/// so the UI can show status (pending / failed) without reading Firestore.
///
/// Hive box: `chat_conversations_box`
/// Key: `{uid}_{conversationId}`
class LocalConversationRecord {
  final String uid;
  final String conversationId;
  final String title;
  final String lastMessage;

  /// When the last message was sent — used for list ordering.
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final AiCapability capability;
  final AiProviderId? lastProvider;

  // ── Local-only sync metadata ──────────────────────────────────────────────

  /// true when the user has deleted this conversation locally.
  /// Hive records with isDeleted=true are hidden from the UI immediately
  /// while the outbox task handles the remote Firestore delete.
  final bool isDeleted;

  /// Current sync state of this record relative to Firestore.
  final SyncStatus syncStatus;

  /// When this record was last successfully synced to Firestore.
  final DateTime? lastSyncedAt;

  /// The `updatedAt` timestamp of the last Firestore snapshot that was merged.
  final DateTime? remoteUpdatedAt;

  /// When this local record was last written.
  final DateTime localUpdatedAt;

  /// When the user requested deletion — used as a tombstone cutoff during sync.
  final DateTime? deleteRequestedAt;

  const LocalConversationRecord({
    required this.uid,
    required this.conversationId,
    required this.title,
    required this.lastMessage,
    required this.localUpdatedAt,
    this.lastMessageAt,
    this.createdAt,
    this.capability = AiCapability.textGeneration,
    this.lastProvider,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pendingCreate,
    this.lastSyncedAt,
    this.remoteUpdatedAt,
    this.deleteRequestedAt,
  });

  // ── Hive serialization ────────────────────────────────────────────────────

  /// Serialize to a plain Map for Hive storage.
  ///
  /// DateTime fields are stored as ISO-8601 strings for portability.
  /// Enum fields are stored as their string value.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'conversationId': conversationId,
      'title': title,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'capability': capability.id,
      'lastProvider': lastProvider?.id,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.value,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'remoteUpdatedAt': remoteUpdatedAt?.toIso8601String(),
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      'deleteRequestedAt': deleteRequestedAt?.toIso8601String(),
    };
  }

  /// Deserialize from a Hive-stored Map.
  ///
  /// Unknown or missing fields fall back to safe defaults so that
  /// old cached records can still be read after model changes.
  factory LocalConversationRecord.fromMap(Map<dynamic, dynamic> map) {
    return LocalConversationRecord(
      uid: map['uid'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      title: map['title'] as String? ?? 'Conversation',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.tryParse(map['lastMessageAt'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      capability: AiCapability.fromId(
        map['capability'] as String? ?? 'text_generation',
      ),
      lastProvider: map['lastProvider'] is String
          ? AiProviderId.fromId(map['lastProvider'] as String)
          : null,
      isDeleted: map['isDeleted'] as bool? ?? false,
      syncStatus: SyncStatus.fromValue(
        map['syncStatus'] as String? ?? SyncStatus.pendingCreate.value,
      ),
      lastSyncedAt: map['lastSyncedAt'] != null
          ? DateTime.tryParse(map['lastSyncedAt'] as String)
          : null,
      remoteUpdatedAt: map['remoteUpdatedAt'] != null
          ? DateTime.tryParse(map['remoteUpdatedAt'] as String)
          : null,
      localUpdatedAt: map['localUpdatedAt'] != null
          ? DateTime.tryParse(map['localUpdatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      deleteRequestedAt: map['deleteRequestedAt'] != null
          ? DateTime.tryParse(map['deleteRequestedAt'] as String)
          : null,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  LocalConversationRecord copyWith({
    String? uid,
    String? conversationId,
    String? title,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    AiCapability? capability,
    AiProviderId? lastProvider,
    bool? isDeleted,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    DateTime? remoteUpdatedAt,
    DateTime? localUpdatedAt,
    DateTime? deleteRequestedAt,
  }) {
    return LocalConversationRecord(
      uid: uid ?? this.uid,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      capability: capability ?? this.capability,
      lastProvider: lastProvider ?? this.lastProvider,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      deleteRequestedAt: deleteRequestedAt ?? this.deleteRequestedAt,
    );
  }

  /// Hive box key for this record: `{uid}_{conversationId}`.
  String get hiveKey => '${uid}_$conversationId';

  /// Maps this local record to the domain `ConversationModel`.
  ConversationModel toConversationModel() {
    return ConversationModel(
      id: conversationId,
      title: title,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      createdAt: createdAt,
      capability: capability,
      lastProvider: lastProvider,
      syncStatus: syncStatus,
    );
  }
}
