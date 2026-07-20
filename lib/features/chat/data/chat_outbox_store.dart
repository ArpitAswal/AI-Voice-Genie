import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/chat_outbox_task.dart';

/// Durable outbox store for queued Firestore operations.
///
/// Persists sync tasks in Hive so they survive app restarts.
/// The ChatSyncService reads due tasks from this store, executes them
/// against Firestore, then marks them succeeded or updates retry state.
///
/// Hive box: `chat_outbox_box`
/// Key: `{createdAtMs}_{operationId}` — ordered by creation time naturally
class ChatOutboxStore {
  // Singleton — one outbox for the entire app
  static final ChatOutboxStore instance = ChatOutboxStore._();
  ChatOutboxStore._();

  late Box _outboxBox;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Called by StorageService after the outbox Hive box is opened.
  void init(Box outboxBox) {
    _outboxBox = outboxBox;
  }

  // ── Enqueue ───────────────────────────────────────────────────────────────

  /// Add a new outbox task to Hive for durable persistence.
  ///
  /// Before enqueuing, checks for an existing task with the same
  /// [idempotencyKey] that is still pending — avoids duplicate tasks
  /// for the same logical operation (e.g., repeated sends during retry).
  Future<void> enqueue(ChatOutboxTask task) async {
    // Idempotency check: do not re-add an equivalent pending task
    final existing = _outboxBox.values
        .whereType<Map>()
        .map((raw) => ChatOutboxTask.fromMap(raw))
        .where((t) =>
            t.idempotencyKey == task.idempotencyKey &&
            t.status == OutboxTaskStatus.pending)
        .firstOrNull;

    if (existing != null) {
      // A pending task with the same key already exists — skip
      debugPrint(
          '📤 OutboxStore: skipping duplicate task for ${task.idempotencyKey}');
      return;
    }

    await _outboxBox.put(task.hiveKey, task.toMap());
    debugPrint(
        '📤 OutboxStore: enqueued ${task.type.value} for conversation id = ${task.conversationId}');
  }

  // ── Read Due Tasks ─────────────────────────────────────────────────────────

  /// Return all tasks whose [nextAttemptAt] is now or in the past.
  ///
  /// Ordered by creation time (ascending) so oldest tasks are processed first.
  /// Tasks with status=processing or status=dead/succeeded are excluded.
  List<ChatOutboxTask> getDueTasks() {
    final now = DateTime.now();
    final tasks = _outboxBox.values
        .whereType<Map>()
        .map((raw) {
          try {
            return ChatOutboxTask.fromMap(raw);
          } catch (e) {
            debugPrint('⚠️ OutboxStore: corrupt task entry: $e');
            return null;
          }
        })
        .whereType<ChatOutboxTask>()
        // Only pending tasks whose retry delay has elapsed
        .where((t) =>
            t.status == OutboxTaskStatus.pending &&
            !t.nextAttemptAt.isAfter(now))
        .toList();

    // Oldest task first — maintains FIFO processing order
    tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return tasks;
  }

  // ── Status Updates ─────────────────────────────────────────────────────────

  /// Mark a task as in-flight. Called before starting Firestore execution.
  ///
  /// Prevents the same task from being picked up by a concurrent drain.
  Future<void> markProcessing(String operationId) async {
    final key = _findKey(operationId);
    if (key == null) return;
    final raw = _outboxBox.get(key) as Map?;
    if (raw == null) return;

    final task = ChatOutboxTask.fromMap(raw);
    task.status = OutboxTaskStatus.processing;
    task.lastAttemptAt = DateTime.now();
    await _outboxBox.put(key, task.toMap());
  }

  /// Mark a task as successfully completed and remove it from the outbox.
  ///
  /// Completed tasks are deleted rather than retained, keeping the outbox
  /// small and preventing re-processing on future drain cycles.
  Future<void> markSucceeded(String operationId) async {
    final key = _findKey(operationId);
    if (key == null) return;
    await _outboxBox.delete(key);
    debugPrint('✅ OutboxStore: task $operationId succeeded and removed');
  }

  /// Handle a task failure.
  ///
  /// For **retryable errors** (network, server unavailable):
  ///   - Increments `attemptCount`.
  ///   - If attempts < maxAttempts (3): sets `nextAttemptAt` using backoff and
  ///     resets status to `pending` so the drain picks it up again later.
  ///   - If attempts >= maxAttempts: keeps as `pending` with far-future
  ///     `nextAttemptAt` (10 min) so it retries when connectivity is restored
  ///     but doesn't spam on every drain cycle.
  ///
  /// For **non-retryable errors** (permission denied, invalid payload):
  ///   - Marks as `dead` immediately — no further retries.
  Future<void> markFailed(
    String operationId,
    String error, {
    bool isRetryable = true,
  }) async {
    const maxAttempts = 3;
    final key = _findKey(operationId);
    if (key == null) return;

    final raw = _outboxBox.get(key) as Map?;
    if (raw == null) return;

    final task = ChatOutboxTask.fromMap(raw);
    task.attemptCount++;
    task.lastAttemptAt = DateTime.now();
    task.lastError = error;

    if (!isRetryable) {
      // Non-retryable: mark as dead so the sync worker never touches it again
      task.status = OutboxTaskStatus.dead;
      debugPrint(
          '💀 OutboxStore: task $operationId marked dead (non-retryable): $error');
    } else if (task.attemptCount >= maxAttempts) {
      // Exhausted session retries: keep pending but with a long backoff
      // so the connectivity listener can trigger a fresh attempt on reconnect
      task.status = OutboxTaskStatus.pending;
      task.nextAttemptAt = DateTime.now().add(const Duration(minutes: 10));
      debugPrint('⏳ OutboxStore: task $operationId exhausted ${maxAttempts}x, '
          'will retry in 10min or on reconnect');
    } else {
      // Still retrying: apply backoff delay based on current attempt count
      task.status = OutboxTaskStatus.pending;
      task.nextAttemptAt = DateTime.now().add(task.retryDelay);
      debugPrint(
          '🔄 OutboxStore: task $operationId attempt ${task.attemptCount}, '
          'retry in ${task.retryDelay.inSeconds}s');
    }

    await _outboxBox.put(key, task.toMap());
  }

  /// Reset all tasks that have a long backoff (10-min cooldown) back to
  /// immediately due. Called when connectivity is restored so that
  /// pending-but-cooling-off tasks are retried without waiting 10 minutes.
  Future<void> resetCooldownTasksForRetry() async {
    final keys = _outboxBox.keys.toList();
    for (final key in keys) {
      final raw = _outboxBox.get(key) as Map?;
      if (raw == null) continue;
      try {
        final task = ChatOutboxTask.fromMap(raw);
        // Only reset pending tasks that are cooling off (nextAttemptAt in future)
        if (task.status == OutboxTaskStatus.pending &&
            task.nextAttemptAt.isAfter(DateTime.now())) {
          task.nextAttemptAt = DateTime.now();
          await _outboxBox.put(key, task.toMap());
        }
      } catch (_) {
        // Corrupt entry — skip
      }
    }
    debugPrint('🔄 OutboxStore: reset cooldown tasks for immediate retry');
  }

  /// Number of tasks currently pending or processing.
  int get pendingCount {
    return _outboxBox.values
        .whereType<Map>()
        .map((raw) {
          try {
            return ChatOutboxTask.fromMap(raw);
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatOutboxTask>()
        .where((t) =>
            t.status == OutboxTaskStatus.pending ||
            t.status == OutboxTaskStatus.processing)
        .length;
  }

  /// Remove all outbox tasks for a specific user.
  ///
  /// Called on logout so one user's queued work doesn't run under another user's session.
  Future<void> clearForUser(String uid) async {
    final keys = _outboxBox.keys.toList();
    for (final key in keys) {
      final raw = _outboxBox.get(key) as Map?;
      if (raw == null) continue;
      try {
        final task = ChatOutboxTask.fromMap(raw);
        if (task.uid == uid) {
          await _outboxBox.delete(key);
        }
      } catch (_) {
        await _outboxBox.delete(key);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Find the Hive key for a task by its operationId.
  ///
  /// Iterates the box to locate the matching entry, since the key includes
  /// a timestamp prefix and we only know the operationId at call time.
  String? _findKey(String operationId) {
    for (final key in _outboxBox.keys) {
      final raw = _outboxBox.get(key) as Map?;
      if (raw == null) continue;
      try {
        final task = ChatOutboxTask.fromMap(raw);
        if (task.operationId == operationId) return key.toString();
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
