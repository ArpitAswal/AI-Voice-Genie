import 'package:uuid/uuid.dart';

/// Types of durable outbox operations that can be queued for Firestore.
///
/// Each type corresponds to one class of remote mutation.
/// The sync worker reads the type to determine which Firestore call to make.
enum OutboxTaskType {
  /// Write a new conversation doc + user + AI message pair as a batch.
  upsertMessagePair('upsert_message_pair'),

  /// Update only the conversation title field in Firestore.
  updateConversationTitle('update_conversation_title'),

  /// Delete all message documents and the conversation document in Firestore.
  deleteConversation('delete_conversation'),

  /// Delete all conversations for a user up to a cutoff timestamp.
  deleteAllConversations('delete_all_conversations'),

  /// Hard-delete local Hive records after remote deletion is confirmed.
  hardDeleteLocalConversation('hard_delete_local_conversation');

  final String value;
  const OutboxTaskType(this.value);

  static OutboxTaskType fromValue(String value) {
    return OutboxTaskType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OutboxTaskType.upsertMessagePair,
    );
  }
}

/// Status of a single outbox task.
enum OutboxTaskStatus {
  /// Waiting to be processed by the sync worker.
  pending('pending'),

  /// Currently being executed by the sync worker (in-flight).
  processing('processing'),

  /// Successfully executed — Firestore confirmed the write.
  succeeded('succeeded'),

  /// Failed after exhausting all retry attempts for a non-retryable error.
  dead('dead');

  final String value;
  const OutboxTaskStatus(this.value);

  static OutboxTaskStatus fromValue(String value) {
    return OutboxTaskStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OutboxTaskStatus.pending,
    );
  }
}

/// A durable outbox task persisted in Hive.
///
/// The sync worker reads these tasks and executes the corresponding Firestore
/// operations. Tasks survive app restarts — if the app closes mid-sync,
/// the task is replayed on next launch.
///
/// Retry strategy (3 attempts, retryable errors only):
///   attempt 1: immediate
///   attempt 2: after 5 seconds
///   attempt 3: after 30 seconds
/// After 3 failures with a retryable error → keep as pending, retry on reconnect.
/// On a non-retryable error (permission denied, bad payload) → mark as dead immediately.
///
/// Hive box: `chat_outbox_box`
/// Key: `{createdAtMs}_{operationId}`
class ChatOutboxTask {
  final String operationId;
  final String uid;
  final OutboxTaskType type;
  final String conversationId;

  /// Message IDs involved in this task (for upsertMessagePair).
  final List<String> messageIds;

  /// Full Firestore payload needed to execute the task.
  /// For upsertMessagePair: contains serialized conversation + messages.
  /// For deleteConversation/deleteAllConversations: may be empty.
  final Map<String, dynamic> payload;

  OutboxTaskStatus status;
  int attemptCount;

  /// When the task should next be attempted. The sync worker skips tasks
  /// where nextAttemptAt is in the future (exponential backoff).
  DateTime nextAttemptAt;

  final DateTime createdAt;
  DateTime? lastAttemptAt;
  String? lastError;

  /// Deterministic key used to prevent duplicate execution.
  /// Format: `{type}:{uid}:{conversationId}` for delete operations,
  ///         `{type}:{uid}:{conversationId}:{userMessageId}` for upserts.
  final String idempotencyKey;

  ChatOutboxTask({
    String? operationId,
    required this.uid,
    required this.type,
    required this.conversationId,
    this.messageIds = const [],
    this.payload = const {},
    this.status = OutboxTaskStatus.pending,
    this.attemptCount = 0,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
    this.lastAttemptAt,
    this.lastError,
    required this.idempotencyKey,
  })  : operationId = operationId ?? const Uuid().v4(),
        nextAttemptAt = nextAttemptAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  // ── Hive serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'uid': uid,
      'type': type.value,
      'conversationId': conversationId,
      'messageIds': messageIds,
      'payload': payload,
      'status': status.value,
      'attemptCount': attemptCount,
      'nextAttemptAt': nextAttemptAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
      'idempotencyKey': idempotencyKey,
    };
  }

  factory ChatOutboxTask.fromMap(Map<dynamic, dynamic> map) {
    // Reconstruct payload map from dynamic keys safely
    final rawPayload = map['payload'];
    final Map<String, dynamic> payload = rawPayload is Map
        ? rawPayload.map((k, v) => MapEntry(k.toString(), v))
        : {};

    // Reconstruct messageIds list from dynamic list safely
    final rawIds = map['messageIds'];
    final List<String> messageIds =
        rawIds is List ? rawIds.whereType<String>().toList() : [];

    return ChatOutboxTask(
      operationId: map['operationId'] as String? ?? const Uuid().v4(),
      uid: map['uid'] as String? ?? '',
      type: OutboxTaskType.fromValue(
        map['type'] as String? ?? OutboxTaskType.upsertMessagePair.value,
      ),
      conversationId: map['conversationId'] as String? ?? '',
      messageIds: messageIds,
      payload: payload,
      status: OutboxTaskStatus.fromValue(
        map['status'] as String? ?? OutboxTaskStatus.pending.value,
      ),
      attemptCount: map['attemptCount'] as int? ?? 0,
      nextAttemptAt: map['nextAttemptAt'] != null
          ? DateTime.tryParse(map['nextAttemptAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.tryParse(map['lastAttemptAt'] as String)
          : null,
      lastError: map['lastError'] as String?,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
    );
  }

  /// Hive box key for this task: `{createdAtMs}_{operationId}`.
  ///
  /// Using timestamp prefix ensures tasks are naturally ordered by creation
  /// time when iterated, which is the desired drain order.
  String get hiveKey => '${createdAt.millisecondsSinceEpoch}_$operationId';

  /// Compute the delay for the next attempt based on attempt count.
  ///
  /// Backoff schedule:
  ///   attempt 1 → immediate (0s)
  ///   attempt 2 → 5 seconds
  ///   attempt 3+ → 30 seconds
  Duration get retryDelay {
    switch (attemptCount) {
      case 0:
        return Duration.zero;
      case 1:
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 30);
    }
  }
}
