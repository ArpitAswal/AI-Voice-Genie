import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

const _unset = Object();

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

  /// Optional image URLs — populated for imageGeneration responses.
  /// Holds Cloudinary URLs after generation.
  final List<String>? imageUrls;

  /// Optional PDF file name — populated for pdfParsing responses
  final String? pdfName;

  /// Whether this message is a temporary optimistic insert (not yet in Firestore)
  final bool isOptimistic;

  /// List of valid providers available when this message was sent
  final List<AiProviderId> validProviders;

  /// Optional image size for image generation responses
  final AiImageSize? imageSize;

  /// Optional image count for image generation responses
  final int? imageCount;

  /// Optional decoded image bytes for fast rendering in the UI without main-thread base64 decoding
  final Uint8List? imageBytes;

  /// Optional image quality for image generation responses
  final ImageQuality? imageQuality;

  const MessageModel(
      {required this.id,
      required this.role,
      required this.content,
      this.contentType = MessageContentType.text,
      required this.timestamp,
      this.modelUsed,
      this.tokenCount = 0,
      this.status = MessageStatus.delivered,
      this.imageUrls,
      this.pdfName,
      this.isOptimistic = false,
      this.validProviders = const [],
      this.imageSize,
      this.imageCount,
      this.imageBytes,
      this.imageQuality});

  // ── Factory: New user message (optimistic) ────────────────────────────────

  factory MessageModel.userMessage(
    String content, {
    List<AiProviderId> validProviders = const [],
    MessageContentType contentType = MessageContentType.text,
    List<String>? imageUrls,
    String? pdfName,
    AiImageSize? imageSize,
    int? imageCount,
    ImageQuality? imageQuality,
  }) {
    return MessageModel(
        id: const Uuid().v4(),
        role: MessageRole.user,
        content: content,
        contentType: contentType,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        imageUrls: imageUrls,
        pdfName: pdfName,
        isOptimistic: true,
        validProviders: validProviders,
        imageSize: imageSize,
        imageCount: imageCount,
        imageQuality: imageQuality);
  }

  // ── Factory: New AI response ──────────────────────────────────────────────

  factory MessageModel.aiResponse({
    required String content,
    required AiProviderId modelUsed,
    MessageContentType contentType = MessageContentType.text,
    int tokenCount = 0,
    List<String>? imageUrls,
    String? pdfName,
    AiImageSize? imageSize,
    int? imageCount,
    Uint8List? imageBytes,
    ImageQuality? imageQuality,
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
        imageUrls: imageUrls,
        pdfName: pdfName,
        imageSize: imageSize,
        imageCount: imageCount,
        imageBytes: imageBytes,
        imageQuality: imageQuality);
  }

  // ── Factory: from Firestore ───────────────────────────────────────────────

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MessageModel(
        id: _normalizeStoredMessageId(id),
        role: MessageRole.fromValue(
          data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
        ),
        content: data[FirebaseCollections.fieldMessageContent] as String? ?? '',
        contentType: MessageContentType.fromValue(
          data[FirebaseCollections.fieldMessageContentType] as String? ??
              'text',
        ),
        timestamp:
            (data[FirebaseCollections.fieldMessageTimestamp] as Timestamp?)
                    ?.toDate() ??
                DateTime.now(),
        modelUsed: data[FirebaseCollections.fieldMessageModelUsed] is String
            ? AiProviderId.fromId(
                data[FirebaseCollections.fieldMessageModelUsed] as String,
              )
            : null,
        tokenCount:
            data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
        status: MessageStatus.fromValue(
          data[FirebaseCollections.fieldMessageStatus] as String? ??
              'delivered',
        ),
        imageUrls:
            _parseImageUrls(data[FirebaseCollections.fieldMessageImageUrl]),
        pdfName: data[FirebaseCollections.fieldMessagePdfName] as String?,
        validProviders: (data[FirebaseCollections.fieldMessageValidProviders]
                    as List<dynamic>?)
                ?.map((e) => AiProviderId.fromId(e as String))
                .toList() ??
            [],
        imageSize: data[FirebaseCollections.fieldImageSize] is String
            ? AiImageSize.fromValue(
                data[FirebaseCollections.fieldImageSize] as String)
            : null,
        imageCount: data[FirebaseCollections.fieldImageCount] as int?,
        imageQuality: data[FirebaseCollections.fieldImageQuality] is String
            ? ImageQuality.fromValue(
                data[FirebaseCollections.fieldImageQuality] as String)
            : null);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldMessageID: id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: content,
      FirebaseCollections.fieldMessageContentType: contentType.value,
      FirebaseCollections.fieldMessageTimestamp: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelUsed != null)
        FirebaseCollections.fieldMessageModelUsed: modelUsed!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: imageUrls,
      if (pdfName != null) FirebaseCollections.fieldMessagePdfName: pdfName,
      if (validProviders.isNotEmpty)
        FirebaseCollections.fieldMessageValidProviders:
            validProviders.map((e) => e.id).toList(),
      if (imageSize != null)
        FirebaseCollections.fieldImageSize: imageSize!.name,
      if (imageCount != null) FirebaseCollections.fieldImageCount: imageCount,
      if (imageQuality != null)
        FirebaseCollections.fieldImageQuality: imageQuality!.name,
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
      if (imageUrls != null && imageUrls!.isNotEmpty) 'imageUrls': imageUrls,
      if (pdfName != null) FirebaseCollections.fieldMessagePdfName: pdfName,
      'validProviders': validProviders.map((e) => e.id).toList(),
      if (imageSize != null) 'imageSize': imageSize!.name,
      if (imageCount != null) 'imageCount': imageCount,
      if (imageBytes != null) 'imageBytes': base64Encode(imageBytes!),
      if (imageQuality != null) 'imageQuality': imageQuality!.name,
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
          data[FirebaseCollections.fieldMessageContentType] as String? ??
              'text',
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
          data[FirebaseCollections.fieldMessageStatus] as String? ??
              'delivered',
        ),
        imageUrls: _parseImageUrls(data['imageUrls']),
        pdfName: data[FirebaseCollections.fieldMessagePdfName] as String?,
        validProviders: (data['validProviders'] as List<dynamic>?)
                ?.map((e) => AiProviderId.fromId(e as String))
                .toList() ??
            [],
        imageSize: data['imageSize'] is String
            ? AiImageSize.fromValue(data['imageSize'] as String)
            : null,
        imageCount: data['imageCount'] as int?,
        imageBytes: data['imageBytes'] is String
            ? base64Decode(data['imageBytes'] as String)
            : null,
        imageQuality: data['imageQuality'] is String
            ? ImageQuality.fromValue(data['imageQuality'] as String)
            : null);
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
  ///
  /// IMPORTANT: Raw image payloads (base64/data-URI) must never be written to
  /// Firestore — they exceed the 1 MB document limit and cause INVALID_ARGUMENT.
  /// Before calling this, ensure [aiMessage.imageUrl] contains a Cloudinary URL,
  /// not a raw base64 string.
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
      if (aiMessage.imageUrls != null && aiMessage.imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: aiMessage.imageUrls,
      if (aiMessage.pdfName != null)
        FirebaseCollections.fieldPdfName: aiMessage.pdfName,
      FirebaseCollections.fieldValidProviders:
          userMessage.validProviders.map((e) => e.id).toList(),
      if (aiMessage.imageSize != null)
        FirebaseCollections.fieldImageSize: aiMessage.imageSize!.name,
      if (aiMessage.imageCount != null)
        FirebaseCollections.fieldImageCount: aiMessage.imageCount,
      if (aiMessage.imageQuality != null)
        FirebaseCollections.fieldImageQuality: aiMessage.imageQuality!.name,
    };
  }

  /// Split a Firestore paired document back into two MessageModels.
  ///
  /// Returns [userMessage, aiMessage] in chronological order.
  static List<MessageModel> pairFromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final normalizedId = _normalizeStoredMessageId(docId);
    final timestamp =
        (data[FirebaseCollections.fieldTimestamp] as Timestamp?)?.toDate() ??
            DateTime.now();

    final userMsg = MessageModel(
      id: normalizedId,
      role: MessageRole.user,
      content: data[FirebaseCollections.fieldPrompt] as String? ??
          data[FirebaseCollections.fieldMessageContent] as String? ??
          '',
      timestamp: timestamp,
      contentType: MessageContentType.fromValue(
        data[FirebaseCollections.fieldContentType] as String? ?? 'prompt_text',
      ),
      status: MessageStatus.delivered,
      validProviders:
          (data[FirebaseCollections.fieldValidProviders] as List<dynamic>?)
                  ?.map((e) => AiProviderId.fromId(e as String))
                  .toList() ??
              [],
    );

    final aiMsg = MessageModel(
        id: normalizedId,
        role: MessageRole.assistant,
        content: data[FirebaseCollections.fieldResponse] as String? ??
            data[FirebaseCollections.fieldMessageContent] as String? ??
            '',
        contentType: MessageContentType.fromValue(
          data[FirebaseCollections.fieldContentType] as String? ??
              'prompt_text',
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
        imageUrls: _parseImageUrls(data[FirebaseCollections.fieldImageUrl]),
        pdfName: data[FirebaseCollections.fieldPdfName] as String?,
        imageSize: data[FirebaseCollections.fieldImageSize] is String
            ? AiImageSize.fromValue(
                data[FirebaseCollections.fieldImageSize] as String)
            : null,
        imageCount: data[FirebaseCollections.fieldImageCount] as int?,
        imageBytes: data[FirebaseCollections.fieldImageUrl] is String
            ? base64Decode(data[FirebaseCollections.fieldImageUrl] as String)
            : null,
        imageQuality: data[FirebaseCollections.fieldImageQuality] is String
            ? ImageQuality.fromValue(
                data[FirebaseCollections.fieldImageQuality] as String)
            : null);

    return [userMsg, aiMsg];
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  MessageModel copyWith({
    String? id,
    MessageRole? role,
    String? content,
    MessageContentType? contentType,
    DateTime? timestamp,
    Object? modelUsed = _unset,
    int? tokenCount,
    MessageStatus? status,
    Object? imageUrls = _unset,
    Object? pdfName = _unset,
    bool? isOptimistic,
    List<AiProviderId>? validProviders,
    Object? imageSize = _unset,
    Object? imageCount = _unset,
    Object? imageBytes = _unset,
    Object? imageQuality = _unset,
  }) {
    return MessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      modelUsed: identical(modelUsed, _unset)
          ? this.modelUsed
          : modelUsed as AiProviderId?,
      tokenCount: tokenCount ?? this.tokenCount,
      status: status ?? this.status,
      imageUrls: identical(imageUrls, _unset)
          ? this.imageUrls
          : imageUrls as List<String>?,
      pdfName: identical(pdfName, _unset) ? this.pdfName : pdfName as String?,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      validProviders: validProviders ?? this.validProviders,
      imageSize: identical(imageSize, _unset)
          ? this.imageSize
          : imageSize as AiImageSize?,
      imageCount:
          identical(imageCount, _unset) ? this.imageCount : imageCount as int?,
      imageBytes: identical(imageBytes, _unset)
          ? this.imageBytes
          : imageBytes as Uint8List?,
      imageQuality: identical(imageBytes, _unset)
          ? this.imageQuality
          : imageBytes as ImageQuality?,
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

String _normalizeStoredMessageId(String id) {
  const prefixes = ['UserRef-', 'AIRef-'];
  for (final prefix in prefixes) {
    if (id.startsWith(prefix)) {
      return id.substring(prefix.length);
    }
  }
  return id;
}

List<String>? _parseImageUrls(dynamic data) {
  if (data == null) return null;
  if (data is String) return [data];
  if (data is List) return data.map((e) => e.toString()).toList();
  return null;
}
