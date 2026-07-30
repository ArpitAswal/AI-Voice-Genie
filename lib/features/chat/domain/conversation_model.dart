import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Immutable entity representing a conversation's metadata.
///
/// Stored in Firestore at:
///   AI_Voice_Genie/users/{uid}/conversations/{conversationId}
///
/// Does NOT contain messages — those live in the messages subcollection.
/// This document is updated on every new message (title, lastMessage, count).
class ConversationModel {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  /// Which AI capability this conversation used
  final AiCapability capability;

  /// Which AI provider sent the last response
  final AiProviderId? lastProvider;

  /// Local-only sync status — exposed for UI badge rendering (e.g., sync-failed warning).
  /// This field is NOT stored in Firestore; it is populated from the Hive local record.
  final SyncStatus syncStatus;

  const ConversationModel({
    required this.id,
    required this.title,
    required this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.capability = AiCapability.textGeneration,
    this.lastProvider,
    this.syncStatus = SyncStatus.synced,
  });

  // ── Factory: from Firestore ───────────────────────────────────────────────

  factory ConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ConversationModel(
      id: id,
      title: data[FirebaseCollections.fieldConversationTitle] as String? ??
          'Conversation',
      lastMessage:
          data[FirebaseCollections.fieldConversationLastMessage] as String? ??
              '',
      lastMessageAt: (data[FirebaseCollections.fieldConversationLastMessageAt]
              as Timestamp?)
          ?.toDate(),
      createdAt:
          (data[FirebaseCollections.fieldConversationCreatedAt] as Timestamp?)
              ?.toDate(),
      capability: AiCapability.fromId(
        data[FirebaseCollections.fieldConversationCapability] as String? ??
            'text_generation',
      ),
      lastProvider: data[FirebaseCollections.fieldConversationLastProvider]
              is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldConversationLastProvider] as String,
            )
          : null,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldConversationID: id,
      FirebaseCollections.fieldConversationTitle: title,
      FirebaseCollections.fieldConversationLastMessage: lastMessage,
      FirebaseCollections.fieldConversationCapability: capability.id,
      if (lastProvider != null)
        FirebaseCollections.fieldConversationLastProvider: lastProvider!.id,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ConversationModel copyWith({
    String? id,
    String? title,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    AiCapability? capability,
    AiProviderId? lastProvider,
    SyncStatus? syncStatus,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      capability: capability ?? this.capability,
      lastProvider: lastProvider ?? this.lastProvider,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ConversationModel(id: $id, title: $title)';
}
