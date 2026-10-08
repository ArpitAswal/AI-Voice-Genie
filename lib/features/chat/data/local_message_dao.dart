import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/enums/app_enums.dart';
import '../domain/local_message_record.dart';
import '../domain/message_page_cursor.dart';
import 'message_dto.dart';

/// Data Access Object (DAO) for Hive message storage (`chat_messages_box`).
///
/// Encapsulates all low-level database operations for chat messages.
/// Bridges storage reading and writing through [MessageDto] to protect
/// against schema evolution and type errors.
class LocalMessageDao {
  final Box _box;

  LocalMessageDao(this._box);

  /// Persists a single [LocalMessageRecord] to Hive using [MessageDto] serialization.
  Future<void> saveMessage(LocalMessageRecord record) async {
    final dto = MessageDto.fromLocalRecord(record);
    await _box.put(record.hiveKey, dto.toHiveMap());
  }

  /// Persists a single [MessageDto] directly to Hive.
  Future<void> saveDto(MessageDto dto) async {
    final key = '${dto.uid}_${dto.conversationId}_${dto.messageId}';
    await _box.put(key, dto.toHiveMap());
  }

  /// Persists multiple [LocalMessageRecord] instances in a single atomic batch.
  Future<void> saveMessagesBatch(List<LocalMessageRecord> records) async {
    if (records.isEmpty) return;
    final map = <String, dynamic>{};
    for (final record in records) {
      final dto = MessageDto.fromLocalRecord(record);
      map[record.hiveKey] = dto.toHiveMap();
    }
    await _box.putAll(map);
  }

  /// Retrieves a single record by its Hive key (`{uid}_{conversationId}_{messageId}`).
  LocalMessageRecord? getMessage(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    if (raw is LocalMessageRecord) return raw;
    if (raw is Map) {
      try {
        return MessageDto.fromMap(raw).toLocalRecord();
      } catch (e) {
        debugPrint('⚠️ LocalMessageDao: corrupt message at $key: $e');
        return null;
      }
    }
    return null;
  }

  /// Reads and parses all non-deleted messages for a conversation, sorted chronologically.
  List<LocalMessageRecord> readMessages(String uid, String conversationId) {
    final prefix = '${uid}_${conversationId}_';
    final records = _box.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) {
          final raw = _box.get(key);
          if (raw == null) return null;
          try {
            if (raw is LocalMessageRecord) return raw;
            if (raw is Map) {
              return MessageDto.fromMap(raw).toLocalRecord();
            }
            return null;
          } catch (e) {
            debugPrint(
                '⚠️ LocalMessageDao: failed parsing message at $key: $e');
            return null;
          }
        })
        .whereType<LocalMessageRecord>()
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

  /// Watches all messages for a conversation, re-emitting on any box modification.
  Stream<List<LocalMessageRecord>> watchMessages(
      String uid, String conversationId) async* {
    yield readMessages(uid, conversationId);

    final prefix = '${uid}_${conversationId}_';
    await for (final event in _box.watch()) {
      final changedKey = event.key?.toString() ?? '';
      if (changedKey.isEmpty || changedKey.startsWith(prefix)) {
        yield readMessages(uid, conversationId);
      }
    }
  }

  /// Reads the latest page of messages (newest messages, returned in chronological order).
  List<LocalMessageRecord> getLatestPage({
    required String uid,
    required String conversationId,
    required int limit,
  }) {
    final allMessages = readMessages(uid, conversationId);
    if (allMessages.length <= limit) return allMessages;
    return allMessages.skip(allMessages.length - limit).toList();
  }

  /// Reads an older page of messages before a given cursor.
  List<LocalMessageRecord> getOlderPage({
    required String uid,
    required String conversationId,
    required MessagePageCursor before,
    required int limit,
  }) {
    final allMessages = readMessages(uid, conversationId);

    final endIndex = allMessages.indexWhere((m) {
      return m.timestamp == before.timestamp && m.messageId == before.messageId;
    });

    if (endIndex <= 0) return [];

    final startIndex = (endIndex - limit < 0) ? 0 : endIndex - limit;
    return allMessages.sublist(startIndex, endIndex);
  }

  /// Hard-deletes a specific message from Hive.
  Future<void> hardDeleteMessage(
      String uid, String conversationId, String messageId) async {
    final key = '${uid}_${conversationId}_$messageId';
    await _box.delete(key);
  }

  /// Soft-deletes all messages belonging to a conversation.
  Future<void> softDeleteMessagesForConversation(
      String uid, String conversationId) async {
    final prefix = '${uid}_${conversationId}_';
    final keys =
        _box.keys.where((k) => k.toString().startsWith(prefix)).toList();

    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        LocalMessageRecord? record;
        if (raw is LocalMessageRecord) {
          record = raw;
        } else if (raw is Map) {
          record = MessageDto.fromMap(raw).toLocalRecord();
        }

        if (record != null) {
          final updated = record.copyWith(
            isDeleted: true,
            syncStatus: SyncStatus.pendingDelete,
          );
          await _box.put(key, MessageDto.fromLocalRecord(updated).toHiveMap());
        }
      } catch (_) {
        await _box.delete(key);
      }
    }
  }

  /// Updates the syncStatus of multiple message records to [SyncStatus.synced].
  Future<void> markMessagesSynced(
      String uid, String conversationId, List<String> messageIds,
      {DateTime? remoteUpdatedAt}) async {
    final now = remoteUpdatedAt ?? DateTime.now();
    final map = <String, dynamic>{};

    for (final msgId in messageIds) {
      if (msgId.isEmpty) continue;
      final key = '${uid}_${conversationId}_$msgId';
      final raw = _box.get(key);
      if (raw != null) {
        try {
          LocalMessageRecord? record;
          if (raw is LocalMessageRecord) {
            record = raw;
          } else if (raw is Map) {
            record = MessageDto.fromMap(raw).toLocalRecord();
          }

          if (record != null) {
            final updated = record.copyWith(
              syncStatus: SyncStatus.synced,
              remoteUpdatedAt: now,
            );
            map[key] = MessageDto.fromLocalRecord(updated).toHiveMap();
          }
        } catch (e) {
          debugPrint(
              '⚠️ LocalMessageDao: could not mark message synced at $key: $e');
        }
      }
    }

    if (map.isNotEmpty) {
      await _box.putAll(map);
    }
  }
}
