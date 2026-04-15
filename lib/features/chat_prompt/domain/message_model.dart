import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Immutable entity representing a single message in a conversation.
///
/// In Firestore, messages are stored as prompt+response pairs:
///   AI_Voice_Genie/AI_Conversations/{uid}/{conversationId}/messages/{messageId}
///   Each document contains both the user prompt and AI response.
///
/// In the UI, each pair is split back into two MessageModel instances
/// (one user, one assistant) for display in the chat list.
///
/// Supports all content types: text, image URL, PDF summary, voice transcript.
class MessageModel {
  final String id;
  final MessageRole role;
  final String content;
  final MessageContentType contentType;
  final DateTime timestamp;
  final AiProviderId? modelUsed;
  final int tokenCount;
  final MessageStatus status;

  /// Optional image URL — populated for imageGeneration responses
  final String? imageUrl;

  /// Optional PDF file name — populated for pdfParsing responses
  final String? pdfName;

  /// Whether this message is a temporary optimistic insert (not yet in Firestore)
  final bool isOptimistic;

  const MessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.contentType = MessageContentType.text,
    required this.timestamp,
    this.modelUsed,
    this.tokenCount = 0,
    this.status = MessageStatus.delivered,
    this.imageUrl,
    this.pdfName,
    this.isOptimistic = false,
  });

  // ── Factory: New user message (optimistic) ────────────────────────────────

  factory MessageModel.userMessage(String content) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isOptimistic: true,
    );
  }

  // ── Factory: New AI response ──────────────────────────────────────────────

  factory MessageModel.aiResponse({
    required String content,
    required AiProviderId modelUsed,
    MessageContentType contentType = MessageContentType.text,
    int tokenCount = 0,
    String? imageUrl,
    String? pdfName,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.assistant,
      content: content,
      contentType: contentType,
      timestamp: DateTime.now(),
      modelUsed: modelUsed,
      tokenCount: tokenCount,
      status: MessageStatus.delivered,
      imageUrl: imageUrl,
      pdfName: pdfName,
    );
  }

  // ── Factory: from Firestore ───────────────────────────────────────────────

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: id,
      role: MessageRole.fromValue(
        data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
      ),
      content: data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      contentType: MessageContentType.fromValue(
        data[FirebaseCollections.fieldMessageContentType] as String? ?? 'text',
      ),
      timestamp: (data[FirebaseCollections.fieldMessageTimestamp] as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      modelUsed: data[FirebaseCollections.fieldMessageModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldMessageModelUsed] as String,
            )
          : null,
      tokenCount: data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldMessageStatus] as String? ?? 'delivered',
      ),
      imageUrl: data[FirebaseCollections.fieldMessageImageUrl] as String?,
      pdfName: data[FirebaseCollections.fieldMessagePdfName] as String?,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: content,
      FirebaseCollections.fieldMessageContentType: contentType.value,
      FirebaseCollections.fieldMessageTimestamp: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelUsed != null)
        FirebaseCollections.fieldMessageModelUsed: modelUsed!.id,
      if (imageUrl != null) FirebaseCollections.fieldMessageImageUrl: imageUrl,
      if (pdfName != null) FirebaseCollections.fieldMessagePdfName: pdfName,
    };
  }

  /// Serialize for Hive/JSON cache — uses ISO 8601 string instead of FieldValue.
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: content,
      FirebaseCollections.fieldMessageContentType: contentType.value,
      FirebaseCollections.fieldMessageTimestamp: timestamp.toIso8601String(),
      FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelUsed != null)
        FirebaseCollections.fieldMessageModelUsed: modelUsed!.id,
      if (imageUrl != null) FirebaseCollections.fieldMessageImageUrl: imageUrl,
      if (pdfName != null) FirebaseCollections.fieldMessagePdfName: pdfName,
    };
  }

  /// Deserialize from Hive/JSON cache — reads ISO 8601 timestamp string.
  factory MessageModel.fromCacheMap(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id'] as String? ?? '',
      role: MessageRole.fromValue(
        data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
      ),
      content: data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      contentType: MessageContentType.fromValue(
        data[FirebaseCollections.fieldMessageContentType] as String? ?? 'text',
      ),
      timestamp: DateTime.tryParse(
            data[FirebaseCollections.fieldMessageTimestamp] as String? ?? '',
          ) ??
          DateTime.now(),
      modelUsed: data[FirebaseCollections.fieldMessageModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldMessageModelUsed] as String,
            )
          : null,
      tokenCount:
          data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldMessageStatus] as String? ?? 'delivered',
      ),
      imageUrl: data[FirebaseCollections.fieldMessageImageUrl] as String?,
      pdfName: data[FirebaseCollections.fieldMessagePdfName] as String?,
    );
  }

  // ── Context history format ────────────────────────────────────────────────

  /// Convert to the format expected by AI provider adapters for history.
  Map<String, String> toHistoryEntry() {
    return {
      'role': role.value,
      'content': content,
    };
  }

  // ── Paired Firestore Serialization ────────────────────────────────────────
  //
  // Firestore stores each prompt + response as ONE document.
  // The pairId is the user message's UUID.
  // When reading back, we split into two MessageModels with deterministic IDs:
  //   user    → '{pairId}_user'
  //   assistant → '{pairId}_ai'

  /// Combine a user prompt and AI response into a single Firestore document.
  ///
  /// Uses [userMessage.id] as the Firestore document ID (the pair ID).
  static Map<String, dynamic> pairToFirestore({
    required MessageModel userMessage,
    required MessageModel aiMessage,
  }) {
    return {
      FirebaseCollections.fieldPrompt: userMessage.content,
      FirebaseCollections.fieldResponse: aiMessage.content,
      FirebaseCollections.fieldModelUsed: aiMessage.modelUsed?.id,
      FirebaseCollections.fieldTokenCount: aiMessage.tokenCount,
      FirebaseCollections.fieldContentType: aiMessage.contentType.value,
      FirebaseCollections.fieldStatus: aiMessage.status.value,
      FirebaseCollections.fieldTimestamp: FieldValue.serverTimestamp(),
      if (aiMessage.imageUrl != null)
        FirebaseCollections.fieldImageUrl: aiMessage.imageUrl,
      if (aiMessage.pdfName != null)
        FirebaseCollections.fieldPdfName: aiMessage.pdfName,
    };
  }

  /// Split a Firestore paired document back into two MessageModels.
  ///
  /// Returns [userMessage, aiMessage] in chronological order.
  static List<MessageModel> pairFromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final timestamp =
        (data[FirebaseCollections.fieldTimestamp] as Timestamp?)?.toDate() ??
            DateTime.now();

    final userMsg = MessageModel(
      id: '${docId}_user',
      role: MessageRole.user,
      content: data[FirebaseCollections.fieldPrompt] as String? ?? '',
      timestamp: timestamp,
      status: MessageStatus.delivered,
    );

    final aiMsg = MessageModel(
      id: '${docId}_ai',
      role: MessageRole.assistant,
      content: data[FirebaseCollections.fieldResponse] as String? ?? '',
      contentType: MessageContentType.fromValue(
        data[FirebaseCollections.fieldContentType] as String? ?? 'text',
      ),
      timestamp: timestamp,
      modelUsed: data[FirebaseCollections.fieldModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldModelUsed] as String,
            )
          : null,
      tokenCount: data[FirebaseCollections.fieldTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldStatus] as String? ?? 'delivered',
      ),
      imageUrl: data[FirebaseCollections.fieldImageUrl] as String?,
      pdfName: data[FirebaseCollections.fieldPdfName] as String?,
    );

    return [userMsg, aiMsg];
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  MessageModel copyWith({
    String? id,
    MessageRole? role,
    String? content,
    MessageContentType? contentType,
    DateTime? timestamp,
    AiProviderId? modelUsed,
    int? tokenCount,
    MessageStatus? status,
    String? imageUrl,
    String? pdfName,
    bool? isOptimistic,
  }) {
    return MessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      modelUsed: modelUsed ?? this.modelUsed,
      tokenCount: tokenCount ?? this.tokenCount,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      pdfName: pdfName ?? this.pdfName,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MessageModel(id: $id, role: ${role.value}, '
      'status: ${status.value})';
}
