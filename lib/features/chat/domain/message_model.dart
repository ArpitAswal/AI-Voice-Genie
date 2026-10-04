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
  final String lastPrompt;

  /// The type of content represented by this message (text, imageUrl, pdfSummary, etc.).
  final AiCapability requestCapability;

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
  /// Holds Firebase Cloud Storage URLs after generation.
  final List<String>? imageUrls;

  /// Optional PDF attachments — populated for pdfParsing responses.
  final List<PdfAttachmentInfo>? pdfInfo;

  /// Whether this message is a temporary optimistic insert (not yet persisted in Firestore).
  final bool isOptimistic;

  /// Optional image size for image generation responses.
  final AiImageSize? imageSize;

  /// Optional image count for image generation responses.
  final int? generateImageRequest;

  /// Optional image quality for image generation responses (OpenAI only).
  final ImageQuality? imageQuality;

  /// Optional image background for image generation responses (OpenAI only).
  final ImageGenerateBackground? imageBackground;

  /// Optional vision detail level for image understanding requests (OpenAI only).
  final VisionDetailLevel? visionDetailLevel;

  /// Convenience getter for message text content.
  String get content => lastPrompt;

  /// Formatted image size / aspect ratio for Firestore persistence.
  /// For Gemini: "Square (1:1)", "Landscape (16:9)", "Portrait (9:16)"
  /// For OpenAI: "Square (1024x1024)", "Landscape (1536x1024)", "Portrait (1024x1536)"
  String? get effectiveImageSizeString {
    if (imageSize == null) return null;
    if (modelRequest == AiProviderId.gemini) {
      switch (imageSize!) {
        case AiImageSize.landscape:
          return 'Landscape (16:9)';
        case AiImageSize.portrait:
          return 'Portrait (9:16)';
        case AiImageSize.square:
          return 'Square (1:1)';
      }
    }
    return imageSize!.name;
  }

  /// Standard constructor for [MessageModel]. All key fields are required.
  const MessageModel({
    required this.id,
    required this.role,
    required this.lastPrompt,
    required this.timestamp,
    required this.modelRequest,
    this.requestCapability = AiCapability.textGeneration,
    this.tokenCount = 0,
    this.status = MessageStatus.partial,
    this.imageUrls,
    this.pdfInfo,
    this.isOptimistic = false,
    this.imageSize,
    this.generateImageRequest,
    this.imageQuality,
    this.imageBackground,
    this.visionDetailLevel,
  });

  /// Factory constructor to build a new optimistic User message.
  /// Used to instantly show the user's message in the UI before sending it to the server.
  factory MessageModel.userMessage({
    required String lastPrompt,
    required AiProviderId provider,
    AiCapability requestCapability = AiCapability.textGeneration,
    List<String>? imagePaths,
    List<PdfAttachmentInfo>? pdfInfo,
    AiImageSize? imageSize,
    int? generateImageRequest,
    ImageQuality? imageQuality,
    ImageGenerateBackground? imageBackground,
    VisionDetailLevel? visionDetailLevel,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.user,
      lastPrompt: lastPrompt,
      requestCapability: requestCapability,
      timestamp: DateTime.now(),
      modelRequest: provider,
      status: MessageStatus.sending,
      imageUrls: imagePaths,
      pdfInfo: pdfInfo,
      isOptimistic: true,
      imageSize: imageSize,
      generateImageRequest: generateImageRequest,
      imageQuality: imageQuality,
      imageBackground: imageBackground,
      visionDetailLevel: visionDetailLevel,
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
    int? generateImageRequest,
    ImageQuality? imageQuality,
    ImageGenerateBackground? imageBackground,
    VisionDetailLevel? visionDetailLevel,
  }) {
    return MessageModel(
      id: const Uuid().v4(),
      role: MessageRole.assistant,
      lastPrompt: content,
      requestCapability: contentType,
      timestamp: DateTime.now(),
      modelRequest: modelUsed,
      tokenCount: tokenCount,
      status: MessageStatus.delivered,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      generateImageRequest: generateImageRequest,
      imageQuality: imageQuality,
      imageBackground: imageBackground,
      visionDetailLevel: visionDetailLevel,
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
      lastPrompt:
          data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      requestCapability: AiCapability.fromValue(
        data[FirebaseCollections.fieldMessageContentType] as String? ??
            'text_generation',
      ),
      timestamp: data[FirebaseCollections.fieldMessageTimestamp] is Timestamp
          ? (data[FirebaseCollections.fieldMessageTimestamp] as Timestamp)
              .toDate()
          : (data[FirebaseCollections.fieldMessageTimestamp] is DateTime
              ? data[FirebaseCollections.fieldMessageTimestamp] as DateTime
              : DateTime.now()),
      modelRequest: data[FirebaseCollections.fieldMessageModelUsed] is String
          ? AiProviderId.fromId(
              data[FirebaseCollections.fieldMessageModelUsed] as String)
          : null,
      tokenCount: data[FirebaseCollections.fieldMessageTokenCount] as int? ?? 0,
      status: MessageStatus.fromValue(
        data[FirebaseCollections.fieldMessageStatus] as String? ?? 'delivered',
      ),
      imageUrls:
          _parseImageUrls(data[FirebaseCollections.fieldMessageImageUrl]) ??
              _parseImageUrls(data['imageUrls']),
      pdfInfo: _parsePdfInfo(data),
      imageSize: data[FirebaseCollections.fieldImageSize] is String
          ? AiImageSize.fromValue(
              data[FirebaseCollections.fieldImageSize] as String)
          : (data['imageSize'] is String
              ? AiImageSize.fromValue(data['imageSize'] as String)
              : null),
      generateImageRequest: data[FirebaseCollections.fieldImageCount] as int? ??
          data['imageCount'] as int?,
      imageQuality: data[FirebaseCollections.fieldImageQuality] is String
          ? ImageQuality.fromValue(
              data[FirebaseCollections.fieldImageQuality] as String)
          : (data['imageQuality'] is String
              ? ImageQuality.fromValue(data['imageQuality'] as String)
              : null),
      imageBackground: data[FirebaseCollections.fieldImageBackground] is String
          ? ImageGenerateBackground.fromString(
              data[FirebaseCollections.fieldImageBackground] as String)
          : (data['imageBackground'] is String
              ? ImageGenerateBackground.fromString(
                  data['imageBackground'] as String)
              : null),
      visionDetailLevel: data[FirebaseCollections.fieldVisionDetailLevel]
              is String
          ? VisionDetailLevel.fromValue(
              data[FirebaseCollections.fieldVisionDetailLevel] as String)
          : (data['visionDetailLevel'] is String
              ? VisionDetailLevel.fromValue(data['visionDetailLevel'] as String)
              : null),
    );
  }

  /// Convenience getter indicating if the message originated from the human user.
  bool get isUser => role == MessageRole.user;

  /// Serializes the message model for storage in Firestore.
  /// Maps object properties to standard database keys.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.fieldMessageID: id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: lastPrompt,
      FirebaseCollections.fieldMessageContentType: requestCapability.id,
      FirebaseCollections.fieldMessageTimestamp: FieldValue.serverTimestamp(),
      // Role-based token guard: User messages never generate token metrics and omit this key.
      // Assistant messages always record tokenCount (including 0 if unparsed) for accurate audit diagnostics.
      if (role == MessageRole.assistant)
        FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelRequest != null)
        FirebaseCollections.fieldMessageModelUsed: modelRequest!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((e) => e.toMap()).toList(),
      if (effectiveImageSizeString != null)
        FirebaseCollections.fieldImageSize: effectiveImageSizeString,
      if (generateImageRequest != null)
        FirebaseCollections.fieldImageCount: generateImageRequest,
      if (modelRequest == AiProviderId.gemini)
        FirebaseCollections.fieldImageQuality: null
      else if (imageQuality != null)
        FirebaseCollections.fieldImageQuality: imageQuality!.name,
      if (imageBackground != null)
        FirebaseCollections.fieldImageBackground: imageBackground!.name,
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,
    };
  }

  /// Serializes the message model for outbox payload (Firestore sync).
  /// Uses Firestore keys, but uses ISO string for timestamp since
  /// FieldValue cannot be serialized in the background Hive outbox.
  Map<String, dynamic> toSyncPayload() {
    return {
      FirebaseCollections.fieldMessageID: id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: lastPrompt,
      FirebaseCollections.fieldMessageContentType: requestCapability.id,
      FirebaseCollections.fieldMessageTimestamp: timestamp.toIso8601String(),
      // Role-based token guard: User messages omit token metrics.
      // Assistant messages always record tokenCount (including 0 if unparsed) for accurate audit diagnostics.
      if (role == MessageRole.assistant)
        FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelRequest != null)
        FirebaseCollections.fieldMessageModelUsed: modelRequest!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((e) => e.toMap()).toList(),
      if (effectiveImageSizeString != null)
        FirebaseCollections.fieldImageSize: effectiveImageSizeString,
      if (generateImageRequest != null)
        FirebaseCollections.fieldImageCount: generateImageRequest,
      if (modelRequest == AiProviderId.gemini)
        FirebaseCollections.fieldImageQuality: null
      else if (imageQuality != null)
        FirebaseCollections.fieldImageQuality: imageQuality!.name,
      if (imageBackground != null)
        FirebaseCollections.fieldImageBackground: imageBackground!.name,
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,
    };
  }

  /// Serializes the message model for local Hive / JSON cache.
  /// Converts the [DateTime] to ISO 8601 string as Firestore FieldValue isn't supported locally.
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      FirebaseCollections.fieldMessageID: id,
      FirebaseCollections.fieldMessageRole: role.value,
      FirebaseCollections.fieldMessageContent: lastPrompt,
      FirebaseCollections.fieldMessageContentType: requestCapability.id,
      FirebaseCollections.fieldMessageTimestamp: timestamp.toIso8601String(),
      // Role-based token guard: User messages omit token metrics.
      // Assistant messages always record tokenCount (including 0 if unparsed) for accurate audit diagnostics.
      if (role == MessageRole.assistant)
        FirebaseCollections.fieldMessageTokenCount: tokenCount,
      FirebaseCollections.fieldMessageStatus: status.value,
      if (modelRequest != null)
        FirebaseCollections.fieldMessageModelUsed: modelRequest!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldMessageImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((e) => e.toMap()).toList(),
      if (effectiveImageSizeString != null)
        FirebaseCollections.fieldImageSize: effectiveImageSizeString,
      if (generateImageRequest != null)
        FirebaseCollections.fieldImageCount: generateImageRequest,
      if (modelRequest == AiProviderId.gemini)
        FirebaseCollections.fieldImageQuality: null
      else if (imageQuality != null)
        FirebaseCollections.fieldImageQuality: imageQuality!.name,
      if (imageBackground != null)
        FirebaseCollections.fieldImageBackground: imageBackground!.name,
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,
    };
  }

  /// Deserializes a [MessageModel] from local Hive / JSON cache.
  /// Parses the ISO 8601 string back to a [DateTime] object.
  factory MessageModel.fromCacheMap(Map<String, dynamic> data) {
    return MessageModel(
      id: data[FirebaseCollections.fieldMessageID] as String? ??
          data['id'] as String? ??
          '',
      role: MessageRole.fromValue(
        data[FirebaseCollections.fieldMessageRole] as String? ?? 'user',
      ),
      lastPrompt:
          data[FirebaseCollections.fieldMessageContent] as String? ?? '',
      requestCapability: AiCapability.fromValue(
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
      imageUrls:
          _parseImageUrls(data[FirebaseCollections.fieldMessageImageUrl]) ??
              _parseImageUrls(data['imageUrls']),
      pdfInfo: _parsePdfInfo(data),
      imageSize: data[FirebaseCollections.fieldImageSize] is String
          ? AiImageSize.fromValue(
              data[FirebaseCollections.fieldImageSize] as String)
          : (data['imageSize'] is String
              ? AiImageSize.fromValue(data['imageSize'] as String)
              : null),
      generateImageRequest: data[FirebaseCollections.fieldImageCount] as int? ??
          data['imageCount'] as int?,
      imageQuality: data[FirebaseCollections.fieldImageQuality] is String
          ? ImageQuality.fromValue(
              data[FirebaseCollections.fieldImageQuality] as String)
          : (data['imageQuality'] is String
              ? ImageQuality.fromValue(data['imageQuality'] as String)
              : null),
      imageBackground: data[FirebaseCollections.fieldImageBackground] is String
          ? ImageGenerateBackground.fromString(
              data[FirebaseCollections.fieldImageBackground] as String)
          : (data['imageBackground'] is String
              ? ImageGenerateBackground.fromString(
                  data['imageBackground'] as String)
              : null),
      visionDetailLevel: data[FirebaseCollections.fieldVisionDetailLevel]
              is String
          ? VisionDetailLevel.fromValue(
              data[FirebaseCollections.fieldVisionDetailLevel] as String)
          : (data['visionDetailLevel'] is String
              ? VisionDetailLevel.fromValue(data['visionDetailLevel'] as String)
              : null),
    );
  }

  /// Converts the message model to a standard map entry suitable for conveying
  /// chat history context to standard AI provider APIs (OpenAI, Gemini, Claude).
  ///
  /// Intelligently represents user attachments (images, PDFs) and AI-generated
  /// media (images, PDFs) so the LLM retains complete context of prior turns
  /// even when messages contain media instead of plain text.
  Map<String, String> toHistoryEntry() {
    String resolvedContent = lastPrompt.trim();

    // 1. Failed messages
    if (status == MessageStatus.failed) {
      return {
        'role': role.value,
        'content':
            '[The previous response encountered a temporary error and could not complete.]',
      };
    }

    // 2. User messages with attachments
    if (role == MessageRole.user) {
      if (pdfInfo != null && pdfInfo!.isNotEmpty) {
        final names = pdfInfo!
            .map((p) => p.name)
            .where((n) => n.isNotEmpty)
            .join(', ');
        final label = names.isNotEmpty
            ? '[Attached PDF: $names]'
            : '[Attached PDF document]';
        resolvedContent =
            resolvedContent.isNotEmpty ? '$label $resolvedContent' : label;
      } else if (imageUrls != null && imageUrls!.isNotEmpty) {
        final count = imageUrls!.length;
        final label =
            count > 1 ? '[Attached $count images]' : '[Attached image]';
        resolvedContent =
            resolvedContent.isNotEmpty ? '$label $resolvedContent' : label;
      }
    }

    // 3. Assistant messages with generated media
    if (role == MessageRole.assistant) {
      if (requestCapability == AiCapability.pdfGeneration ||
          (pdfInfo != null && pdfInfo!.isNotEmpty)) {
        final docName = pdfInfo?.firstOrNull?.name;
        final label = docName != null && docName.isNotEmpty
            ? '[Generated PDF document: $docName]'
            : '[Generated PDF document]';
        resolvedContent =
            resolvedContent.isNotEmpty && resolvedContent != label
                ? '$label $resolvedContent'
                : label;
      } else if (requestCapability == AiCapability.imageGeneration ||
          (imageUrls != null && imageUrls!.isNotEmpty)) {
        final count = imageUrls?.length ?? 1;
        final label =
            count > 1 ? '[Generated $count images]' : '[Generated image]';
        resolvedContent =
            resolvedContent.isNotEmpty ? '$resolvedContent $label' : label;
      }
    }

    // Fallback if completely empty
    if (resolvedContent.isEmpty) {
      resolvedContent =
          role == MessageRole.user ? '[User message]' : '[Assistant response]';
    }

    return {
      'role': role.value,
      'content': resolvedContent,
    };
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
    Object? imageSize = _unset,
    Object? generateImageRequest = _unset,
    Object? imageQuality = _unset,
    Object? imageBackground = _unset,
    Object? visionDetailLevel = _unset,
  }) {
    return MessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      lastPrompt: content ?? lastPrompt,
      requestCapability: contentType ?? requestCapability,
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
      generateImageRequest: identical(generateImageRequest, _unset)
          ? this.generateImageRequest
          : generateImageRequest as int?,
      imageQuality: identical(imageQuality, _unset)
          ? this.imageQuality
          : imageQuality as ImageQuality?,
      imageBackground: identical(imageBackground, _unset)
          ? this.imageBackground
          : imageBackground as ImageGenerateBackground?,
      visionDetailLevel: identical(visionDetailLevel, _unset)
          ? this.visionDetailLevel
          : visionDetailLevel as VisionDetailLevel?,
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

/// Immutable class representing combined PDF attachment path, cloud URL, and name.
class PdfAttachmentInfo {
  final String path;
  final String name;
  final int? fileSizeBytes;
  final String? url;

  const PdfAttachmentInfo({
    required this.path,
    required this.name,
    this.fileSizeBytes,
    this.url,
  });

  factory PdfAttachmentInfo.fromMap(Map<String, dynamic> map) {
    final rawPath = map['path'] as String? ?? '';
    final rawUrl = map['url'] as String?;
    return PdfAttachmentInfo(
      path: rawPath,
      name: map['name'] as String? ?? '',
      fileSizeBytes: map['fileSizeBytes'] as int?,
      url: rawUrl ?? (rawPath.startsWith('http') ? rawPath : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (url != null) 'url': url,
    };
  }

  PdfAttachmentInfo copyWith({
    String? path,
    String? name,
    int? fileSizeBytes,
    String? url,
  }) {
    return PdfAttachmentInfo(
      path: path ?? this.path,
      name: name ?? this.name,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      url: url ?? this.url,
    );
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
      'PdfAttachmentInfo(name: $name, path: $path, size: $fileSizeBytes, url: $url)';
}
