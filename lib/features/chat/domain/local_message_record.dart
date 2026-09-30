import '../../../core/enums/app_enums.dart';
import 'message_model.dart';

/// Local Hive record for a single chat message.
///
/// Stores all displayable message fields plus sync metadata.
/// One Hive entry per message instead of one JSON blob per conversation,
/// which avoids rewriting the entire history on every update.
///
/// Hive box: `chat_messages_box`
/// Key: `{uid}_{conversationId}_{messageId}`
class LocalMessageRecord {
  final String uid;
  final String conversationId;
  final String messageId;
  final MessageRole role;
  final String content;
  final AiCapability contentType;
  final DateTime timestamp;
  final AiProviderId? modelRequest;
  final int tokenCount;
  final MessageStatus status;

  // ── Optional content fields ────────────────────────────────────────────────
  final List<String>? imageUrls;
  final List<PdfAttachmentInfo>? pdfInfo;
  final AiImageSize? imageSize;
  final int? imageCount;
  final ImageQuality? imageQuality;

  // ── Local-only sync metadata ──────────────────────────────────────────────

  /// true when the message belongs to a conversation that was locally deleted.
  /// Filtered out by LocalChatStore before exposing to the UI.
  final bool isDeleted;

  /// Current sync state — reflects whether this message reached Firestore.
  final SyncStatus syncStatus;

  /// When this local record was last written.
  final DateTime localUpdatedAt;

  /// The Firestore `updatedAt` from the last successful remote merge.
  final DateTime? remoteUpdatedAt;

  const LocalMessageRecord({
    required this.uid,
    required this.conversationId,
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.localUpdatedAt,
    this.contentType = AiCapability.textGeneration,
    this.modelRequest,
    this.tokenCount = 0,
    this.status = MessageStatus.delivered,
    this.imageUrls,
    this.pdfInfo,
    this.imageSize,
    this.imageCount,
    this.imageQuality,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pendingCreate,
    this.remoteUpdatedAt,
  });

  // ── Hive serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'conversationId': conversationId,
      'messageId': messageId,
      'role': role.value,
      'content': content,
      'contentType': contentType.id,
      'timestamp': timestamp.toIso8601String(),
      'modelRequest': modelRequest?.id,
      'tokenCount': tokenCount,
      'status': status.value,
      'imageUrls': imageUrls,
      // PdfAttachmentInfo serialized as a list of maps for Hive compatibility
      'pdfInfo': pdfInfo
          ?.map((p) => {
                'path': p.path,
                'name': p.name,
                'fileSizeBytes': p.fileSizeBytes,
                if (p.url != null) 'url': p.url,
              })
          .toList(),
      'imageSize': imageSize?.apiValue,
      'imageCount': imageCount,
      'imageQuality': imageQuality?.name,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.value,
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      'remoteUpdatedAt': remoteUpdatedAt?.toIso8601String(),
    };
  }

  factory LocalMessageRecord.fromMap(Map<dynamic, dynamic> map) {
    // Restore pdfInfo list from stored maps, guarding against null safely
    final rawPdf = map['pdfInfo'];
    List<PdfAttachmentInfo>? pdfInfoList;
    if (rawPdf is List && rawPdf.isNotEmpty) {
      pdfInfoList = rawPdf
          .whereType<Map>()
          .map((p) => PdfAttachmentInfo(
                path: p['path'] as String? ?? '',
                name: p['name'] as String? ?? '',
                fileSizeBytes: p['fileSizeBytes'] as int? ?? 0,
                url: p['url'] as String?,
              ))
          .toList();
    }

    // Restore imageUrls list, guarding against non-list stored value
    final rawUrls = map['imageUrls'];
    List<String>? imageUrlsList;
    if (rawUrls is List && rawUrls.isNotEmpty) {
      imageUrlsList = rawUrls.whereType<String>().toList();
    }

    return LocalMessageRecord(
      uid: map['uid'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      messageId: map['messageId'] as String? ?? '',
      role: MessageRole.fromValue(map['role'] as String? ?? 'user'),
      content: map['content'] as String? ?? '',
      contentType: AiCapability.fromId(
        map['contentType'] as String? ?? 'text_generation',
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      modelRequest: map['modelRequest'] is String
          ? AiProviderId.fromId(map['modelRequest'] as String)
          : null,
      tokenCount: map['tokenCount'] as int? ?? 0,
      status: MessageStatus.fromValue(map['status'] as String? ?? 'delivered'),
      imageUrls: imageUrlsList,
      pdfInfo: pdfInfoList,
      imageSize: map['imageSize'] != null
          ? AiImageSize.values.firstWhere(
              (s) => s.apiValue == map['imageSize'],
              orElse: () => AiImageSize.square,
            )
          : null,
      imageCount: map['imageCount'] as int?,
      imageQuality: map['imageQuality'] != null
          ? ImageQuality.values.firstWhere(
              (q) => q.name == map['imageQuality'],
              orElse: () => ImageQuality.low,
            )
          : null,
      isDeleted: map['isDeleted'] as bool? ?? false,
      syncStatus: SyncStatus.fromValue(
        map['syncStatus'] as String? ?? SyncStatus.pendingCreate.value,
      ),
      localUpdatedAt: map['localUpdatedAt'] != null
          ? DateTime.tryParse(map['localUpdatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      remoteUpdatedAt: map['remoteUpdatedAt'] != null
          ? DateTime.tryParse(map['remoteUpdatedAt'] as String)
          : null,
    );
  }

  // ── Bridge: convert to/from MessageModel ──────────────────────────────────

  /// Build a LocalMessageRecord from a MessageModel.
  ///
  /// Used when saving new messages from the chat flow into Hive.
  factory LocalMessageRecord.fromMessageModel(
    MessageModel message, {
    required String uid,
    required String conversationId,
    SyncStatus syncStatus = SyncStatus.pendingCreate,
  }) {
    return LocalMessageRecord(
      uid: uid,
      conversationId: conversationId,
      messageId: message.id,
      role: message.role,
      content: message.content,
      contentType: message.contentType,
      timestamp: message.timestamp,
      modelRequest: message.modelRequest,
      tokenCount: message.tokenCount,
      status: message.status,
      imageUrls: message.imageUrls,
      pdfInfo: message.pdfInfo,
      imageSize: message.imageSize,
      imageCount: message.imageCount,
      imageQuality: message.imageQuality,
      localUpdatedAt: DateTime.now(),
      syncStatus: syncStatus,
    );
  }

  /// Convert back to MessageModel for use in ChatProvider / UI.
  MessageModel toMessageModel() {
    return MessageModel(
      id: messageId,
      role: role,
      content: content,
      contentType: contentType,
      timestamp: timestamp,
      modelRequest: modelRequest,
      tokenCount: tokenCount,
      status: status,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      imageCount: imageCount,
      imageQuality: imageQuality,
    );
  }

  /// Hive box key for this record: `{uid}_{conversationId}_{messageId}`.
  String get hiveKey => '${uid}_${conversationId}_$messageId';

  // ── copyWith ──────────────────────────────────────────────────────────────

  LocalMessageRecord copyWith({
    String? uid,
    String? conversationId,
    String? messageId,
    MessageRole? role,
    String? content,
    AiCapability? contentType,
    DateTime? timestamp,
    AiProviderId? modelRequest,
    int? tokenCount,
    MessageStatus? status,
    List<String>? imageUrls,
    List<PdfAttachmentInfo>? pdfInfo,
    AiImageSize? imageSize,
    int? imageCount,
    ImageQuality? imageQuality,
    bool? isDeleted,
    SyncStatus? syncStatus,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  }) {
    return LocalMessageRecord(
      uid: uid ?? this.uid,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      modelRequest: modelRequest ?? this.modelRequest,
      tokenCount: tokenCount ?? this.tokenCount,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      pdfInfo: pdfInfo ?? this.pdfInfo,
      imageSize: imageSize ?? this.imageSize,
      imageCount: imageCount ?? this.imageCount,
      imageQuality: imageQuality ?? this.imageQuality,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
    );
  }
}
