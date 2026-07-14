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
  /// The unique identifier of the message (typically a UUID).
  final String id;

  /// The role of the sender, indicating if it's from the 'user' or the 'assistant'.
  final MessageRole role;

  /// The text content of the message (either user prompt or AI response).
  final String content;

  /// The type of content represented by this message (text, imageUrl, pdfSummary, etc.).
  final AiCapability contentType;

  /// The timestamp indicating when the message was created.
  final DateTime timestamp;

  /// The AI provider (model) used or requested for this message.
  /// Nullable because user messages do not request themselves, but required in constructor.
  final AiProviderId? modelRequest;

  /// The token count consumed by this message (mostly relevant for AI responses).
  final int tokenCount;

  /// The delivery status of this message (sending, delivered, failed).
  final MessageStatus status;

  /// Optional image URLs — populated for imageGeneration responses.
  /// Holds Cloudinary URLs after generation.
  final List<String>? imageUrls;

  /// Optional PDF attachments — populated for pdfParsing responses.
  final List<PdfAttachmentInfo>? pdfInfo;

  /// Whether this message is a temporary optimistic insert (not yet persisted in Firestore).
  final bool isOptimistic;

  /// Optional image size for image generation responses.
  final AiImageSize? imageSize;

  /// Optional image count for image generation responses.
  final int? imageCount;

  /// Optional decoded image bytes for fast rendering in the UI without main-thread base64 decoding.
  final Uint8List? imageBytes;

  /// Optional image quality for image generation responses.
  final ImageQuality? imageQuality;

  /// Standard constructor for [MessageModel]. All key fields are required.
  const MessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.modelRequest,
    this.contentType = AiCapability.textGeneration,
    this.tokenCount = 0,
    this.status = MessageStatus.partial,
    this.imageUrls,
    this.pdfInfo,
    this.isOptimistic = false,
    this.imageSize,
    this.imageCount,
    this.imageBytes,
    this.imageQuality,
  });

  /// Factory constructor to build a new optimistic User message.
  /// Used to instantly show the user's message in the UI before sending it to the server.
  factory MessageModel.userMessage(
    String content,
    AiProviderId? validProvider, {
    AiCapability contentType = AiCapability.textGeneration,
    List<String>? imagePaths,
    List<PdfAttachmentInfo>? pdfInfo,
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
      modelRequest: validProvider,
      status: MessageStatus.sending,
      imageUrls: imagePaths,
      pdfInfo: pdfInfo,
      isOptimistic: true,
      imageSize: imageSize,
      imageCount: imageCount,
      imageQuality: imageQuality,
    );
  }

  /// Factory constructor to build a new AI response message.
  /// Used when the AI completes its generation successfully.
  factory MessageModel.aiResponse({
    required String content,
    required AiProviderId modelUsed,
    AiCapability contentType = AiCapability.textGeneration,
    int tokenCount = 0,
    List<String>? imageUrls,
    List<PdfAttachmentInfo>? pdfInfo,
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
      modelRequest: modelUsed,
      tokenCount: tokenCount,
      status: MessageStatus.delivered,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      imageCount: imageCount,
      imageBytes: imageBytes,
      imageQuality: imageQuality,
    );
  }

  /// Deserializes a [MessageModel] from a Firestore document snapshot.
  /// Reads standard keys mapped from [FirebaseCollections].
  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: _normalizeStoredMessageId(id),
      role: MessageRole.fromValue(
        data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
      ),
      content: data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      contentType: AiCapability.fromValue(
        data[FirebaseCollections.fieldMessageContentType] as String? ??
            'text_generation',
      ),
      timestamp: (data[FirebaseCollections.fieldMessageTimestamp] as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      modelRequest: data[FirebaseCollections.fieldMessageModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldMessageModelUsed] as String)
          : null,
      tokenCount: data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldMessageStatus] as String? ?? 'delivered',
      ),
      imageUrls:
          _parseImageUrls(data[FirebaseCollections.fieldMessageImageUrl]),
      pdfInfo: _parsePdfInfo(data),
      imageSize: data[FirebaseCollections.fieldImageSize] is String
          ? AiImageSize.fromValue(
              data[FirebaseCollections.fieldImageSize] as String)
          : null,
      imageCount: data[FirebaseCollections.fieldImageCount] as int?,
      imageQuality: data[FirebaseCollections.fieldImageQuality] is String
          ? ImageQuality.fromValue(
              data[FirebaseCollections.fieldImageQuality] as String)
          : null,
    );
  }

  /// Serializes the message model for storage in Firestore.
  /// Maps object properties to standard database keys.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldMessageID: id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: content,
      FirebaseCollections.fieldMessageContentType: contentType.id,
      FirebaseCollections.fieldMessageTimestamp: FieldValue.serverTimestamp(),
      FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelRequest != null)
        FirebaseCollections.fieldMessageModelUsed: modelRequest!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((e) => e.toMap()).toList(),
      if (imageSize != null)
        FirebaseCollections.fieldImageSize: imageSize!.name,
      if (imageCount != null) FirebaseCollections.fieldImageCount: imageCount,
      if (imageQuality != null)
        FirebaseCollections.fieldImageQuality: imageQuality!.name,
    };
  }

  /// Serializes the message model for local Hive / JSON cache.
  /// Converts the [DateTime] to ISO 8601 string as Firestore FieldValue isn't supported locally.
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: content,
      FirebaseCollections.fieldMessageContentType: contentType.id,
      FirebaseCollections.fieldMessageTimestamp: timestamp.toIso8601String(),
      FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelRequest != null)
        FirebaseCollections.fieldMessageModelUsed: modelRequest!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty) 'imageUrls': imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        'pdfInfo': pdfInfo!.map((e) => e.toMap()).toList(),
      if (imageSize != null) 'imageSize': imageSize!.name,
      if (imageCount != null) 'imageCount': imageCount,
      if (imageBytes != null) 'imageBytes': base64Encode(imageBytes!),
      if (imageQuality != null) 'imageQuality': imageQuality!.name,
    };
  }

  /// Deserializes a [MessageModel] from local Hive / JSON cache.
  /// Parses the ISO 8601 string back to a [DateTime] object.
  factory MessageModel.fromCacheMap(Map<String, dynamic> data) {
    return MessageModel(
      id: data['id'] as String? ?? '',
      role: MessageRole.fromValue(
        data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
      ),
      content: data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      contentType: AiCapability.fromValue(
        data[FirebaseCollections.fieldMessageContentType] as String? ??
            'text_generation',
      ),
      timestamp: DateTime.tryParse(
            data[FirebaseCollections.fieldMessageTimestamp] as String? ?? '',
          ) ??
          DateTime.now(),
      modelRequest: data[FirebaseCollections.fieldMessageModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldMessageModelUsed] as String)
          : null,
      tokenCount: data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldMessageStatus] as String? ?? 'delivered',
      ),
      imageUrls: _parseImageUrls(data['imageUrls']),
      pdfInfo: _parsePdfInfo(data),
      imageSize: data['imageSize'] is String
          ? AiImageSize.fromValue(data['imageSize'] as String)
          : null,
      imageCount: data['imageCount'] as int?,
      imageBytes: data['imageBytes'] is String
          ? base64Decode(data['imageBytes'] as String)
          : null,
      imageQuality: data['imageQuality'] is String
          ? ImageQuality.fromValue(data['imageQuality'] as String)
          : null,
    );
  }

  /// Converts the message model to a standard map entry suitable for conveying
  /// chat history context to standard AI provider APIs.
  Map<String, String> toHistoryEntry() {
    return {
      'role': role.value,
      'content': content,
    };
  }

  /// Combines a user prompt and AI response message into a single Firestore document.
  ///
  /// Uses [userMessage.id] as the Firestore document ID (the pair ID).
  ///
  /// IMPORTANT: Raw image payloads (base64/data-URI) must never be written to
  /// Firestore — they exceed the 1 MB document limit and cause INVALID_ARGUMENT.
  /// Before calling this, ensure [aiMessage.imageUrls] contains Cloudinary URLs.
  static Map<String, dynamic> pairToFirestore({
    required MessageModel userMessage,
    required MessageModel aiMessage,
  }) {
    return {
      FirebaseCollections.fieldPrompt: userMessage.content,
      FirebaseCollections.fieldResponse: aiMessage.content,
      FirebaseCollections.fieldModelUsed: aiMessage.modelRequest?.id,
      FirebaseCollections.fieldTokenCount: aiMessage.tokenCount,
      FirebaseCollections.fieldContentType: aiMessage.contentType.id,
      FirebaseCollections.fieldStatus: aiMessage.status.value,
      FirebaseCollections.fieldTimestamp: FieldValue.serverTimestamp(),
      if (aiMessage.imageUrls != null && aiMessage.imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: aiMessage.imageUrls,
      if (aiMessage.pdfInfo != null && aiMessage.pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            aiMessage.pdfInfo!.map((e) => e.toMap()).toList(),
      if (aiMessage.imageSize != null)
        FirebaseCollections.fieldImageSize: aiMessage.imageSize!.name,
      if (aiMessage.imageCount != null)
        FirebaseCollections.fieldImageCount: aiMessage.imageCount,
      if (aiMessage.imageQuality != null)
        FirebaseCollections.fieldImageQuality: aiMessage.imageQuality!.name,
    };
  }

  /// Splits a paired Firestore document back into two individual chronological [MessageModel]s
  /// (first the user message, then the AI response).
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
      modelRequest: null,
      contentType: AiCapability.fromValue(
        data[FirebaseCollections.fieldContentType] as String? ??
            'text_generation',
      ),
      status: MessageStatus.delivered,
      pdfInfo: _parsePdfInfo(data),
    );

    final aiMsg = MessageModel(
      id: normalizedId,
      role: MessageRole.assistant,
      content: data[FirebaseCollections.fieldResponse] as String? ??
          data[FirebaseCollections.fieldMessageContent] as String? ??
          '',
      contentType: AiCapability.fromValue(
        data[FirebaseCollections.fieldContentType] as String? ??
            'text_generation',
      ),
      timestamp: timestamp,
      modelRequest: data[FirebaseCollections.fieldModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldModelUsed] as String)
          : null,
      tokenCount: data[FirebaseCollections.fieldTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldStatus] as String? ?? 'delivered',
      ),
      imageUrls: _parseImageUrls(data[FirebaseCollections.fieldImageUrl]),
      pdfInfo: _parsePdfInfo(data),
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
          : null,
    );

    return [userMsg, aiMsg];
  }

  /// Creates a copy of this message model with the given fields replaced.
  MessageModel copyWith({
    String? id,
    MessageRole? role,
    String? content,
    AiCapability? contentType,
    DateTime? timestamp,
    Object? modelUsed = _unset,
    int? tokenCount,
    MessageStatus? status,
    Object? imageUrls = _unset,
    Object? pdfInfo = _unset,
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
      modelRequest: identical(modelUsed, _unset)
          ? modelRequest
          : modelUsed as AiProviderId?,
      tokenCount: tokenCount ?? this.tokenCount,
      status: status ?? this.status,
      imageUrls: identical(imageUrls, _unset)
          ? this.imageUrls
          : imageUrls as List<String>?,
      pdfInfo: identical(pdfInfo, _unset)
          ? this.pdfInfo
          : pdfInfo as List<PdfAttachmentInfo>?,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      imageSize: identical(imageSize, _unset)
          ? this.imageSize
          : imageSize as AiImageSize?,
      imageCount:
          identical(imageCount, _unset) ? this.imageCount : imageCount as int?,
      imageBytes: identical(imageBytes, _unset)
          ? this.imageBytes
          : imageBytes as Uint8List?,
      imageQuality: identical(imageQuality, _unset)
          ? this.imageQuality
          : imageQuality as ImageQuality?,
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

/// Normalizes message IDs stored with references to prevent duplication.
String _normalizeStoredMessageId(String id) {
  const prefixes = ['UserRef-', 'AIRef-'];
  for (final prefix in prefixes) {
    if (id.startsWith(prefix)) {
      return id.substring(prefix.length);
    }
  }
  return id;
}

/// Parses a dynamic object into a list of image URLs.
List<String>? _parseImageUrls(dynamic data) {
  if (data == null) return null;
  if (data is String) return [data];
  if (data is List) return data.map((e) => e.toString()).toList();
  return null;
}

/// Helper method to parse PDF attachments from dynamic cache/Firestore structure.
List<PdfAttachmentInfo>? _parsePdfInfo(Map<String, dynamic>? data) {
  if (data == null) return null;

  if (data[FirebaseCollections.fieldPdfInfo] is List) {
    return (data[FirebaseCollections.fieldPdfInfo] as List)
        .map((e) =>
            PdfAttachmentInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  if (data[FirebaseCollections.fieldMessagePdfInfo] is List) {
    return (data[FirebaseCollections.fieldMessagePdfInfo] as List)
        .map((e) =>
            PdfAttachmentInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  if (data['pdfInfo'] is List) {
    return (data['pdfInfo'] as List)
        .map((e) =>
            PdfAttachmentInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // Legacy fallback
  final paths = _parseImageUrls(
      data[FirebaseCollections.fieldMessagePdfPaths] ?? data['pdfPaths']);
  final names = _parseImageUrls(data[FirebaseCollections.fieldPdfName] ??
      data[FirebaseCollections.fieldMessagePdfName] ??
      data['pdfName']);
  if (paths != null && names != null) {
    final pdfs = <PdfAttachmentInfo>[];
    final len = paths.length < names.length ? paths.length : names.length;
    for (int i = 0; i < len; i++) {
      pdfs.add(PdfAttachmentInfo(path: paths[i], name: names[i]));
    }
    return pdfs;
  }
  return null;
}

/// Immutable class representing combined PDF attachment path and name.
class PdfAttachmentInfo {
  final String path;
  final String name;
  final int? fileSizeBytes;

  const PdfAttachmentInfo({
    required this.path,
    required this.name,
    this.fileSizeBytes,
  });

  factory PdfAttachmentInfo.fromMap(Map<String, dynamic> map) {
    return PdfAttachmentInfo(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
      fileSizeBytes: map['fileSizeBytes'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    };
  }

  String get fileSizeLabel {
    if (fileSizeBytes == null) return '';
    if (fileSizeBytes! >= 1000 * 1000) {
      return '${(fileSizeBytes! / (1000 * 1000)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes! / 1000).toStringAsFixed(0)} KB';
  }

  @override
  String toString() =>
      'PdfAttachmentInfo(name: $name, path: $path, size: $fileSizeBytes)';
}
