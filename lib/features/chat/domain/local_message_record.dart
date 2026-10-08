import '../../../core/enums/app_enums.dart';
import '../data/message_dto.dart';
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
  /// The user ID owning this conversation message.
  final String uid;

  /// The conversation ID to which this message belongs.
  final String conversationId;

  /// Unique identifier of the message turn (UUID v4).
  final String messageId;

  /// Sender role: [MessageRole.user] for user prompts, [MessageRole.assistant] for AI responses.
  final MessageRole role;

  /// Primary text content (user prompt, assistant response, or localized error text).
  final String content;

  /// The active AI capability modality (textGeneration, imageGeneration, pdfGeneration, etc.).
  final AiCapability contentType;

  /// The timestamp indicating when the message was originally created locally.
  final DateTime timestamp;

  /// The AI provider targeted or used for this message (Gemini, OpenAI, Claude).
  final AiProviderId? modelRequest;

  /// Total tokens consumed (prompt + completion tokens, assistant responses only).
  final int tokenCount;

  /// Delivery lifecycle status: sending, delivered, failed, or partial.
  final MessageStatus status;

  /// Latency in milliseconds from request dispatch to final response completion (assistant only).
  final int? responseTimeMs;

  /// Provider stop reason indicating why generation halted (e.g., 'STOP', 'length', 'safety').
  final String? finishReason;

  /// The originating request ID correlating this response turn to the prompt turn that created it.
  final String? requestId;

  // ── Optional content fields ────────────────────────────────────────────────

  /// Cloud Storage URLs or local image file paths attached to this message.
  final List<String>? imageUrls;

  /// Structured PDF attachments metadata (local file path, document name, size, Cloud Storage URL).
  final List<PdfAttachmentInfo>? pdfInfo;

  /// Requested image aspect ratio / resolution (for [AiCapability.imageGeneration]).
  final AiImageSize? imageSize;

  /// Number of images requested in an image generation prompt.
  final int? imageCount;

  /// Quality tier for generated images (e.g. [ImageQuality.standard] vs [ImageQuality.hd]).
  final ImageQuality? imageQuality;

  /// Requested background aesthetic for generated images (transparent, white, auto).
  final ImageGenerateBackground? imageBackground;

  /// Fidelity detail level for vision understanding requests ([VisionDetailLevel.low], [VisionDetailLevel.high]).
  final VisionDetailLevel? visionDetailLevel;

  /// User's preferred AI response length tier (short, balanced, detailed, maximum).
  final ResponseLength? responseLength;

  /// User's preferred reasoning thinking depth for Gemini models (low, medium, high).
  final GeminiThinkingLevel? thinkingLevel;

  /// Explicit maximum output tokens calculated for the selected provider.
  final int? maxOutputTokens;

  // ── Local-only sync metadata ──────────────────────────────────────────────

  /// True when the message belongs to a conversation that was locally deleted.
  /// Filtered out before exposing to the UI.
  final bool isDeleted;

  /// Current sync state — reflects whether this message reached Firestore ([SyncStatus.synced], etc.).
  final SyncStatus syncStatus;

  /// When this local record was last written to Hive.
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
    this.responseTimeMs,
    this.finishReason,
    this.requestId,
    this.imageUrls,
    this.pdfInfo,
    this.imageSize,
    this.imageCount,
    this.imageQuality,
    this.imageBackground,
    this.visionDetailLevel,
    this.responseLength,
    this.thinkingLevel,
    this.maxOutputTokens,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pendingCreate,
    this.remoteUpdatedAt,
  });

  // ── Hive serialization via MessageDto ─────────────────────────────────────

  /// Serializes this record to Hive using identical Firestore fields & conditions.
  Map<String, dynamic> toMap() => MessageDto.fromLocalRecord(this).toHiveMap();

  /// Deserializes a [LocalMessageRecord] from Hive using resilient [MessageDto] fallbacks.
  factory LocalMessageRecord.fromMap(Map<dynamic, dynamic> map) =>
      MessageDto.fromMap(map).toLocalRecord();

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
    return MessageDto.fromDomain(
      message,
      uid: uid,
      conversationId: conversationId,
      syncStatus: syncStatus,
    ).toLocalRecord();
  }

  /// Convert back to MessageModel for use in ChatProvider / UI.
  MessageModel toMessageModel() => MessageDto.fromLocalRecord(this).toDomain();

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
    int? responseTimeMs,
    String? finishReason,
    String? requestId,
    List<String>? imageUrls,
    List<PdfAttachmentInfo>? pdfInfo,
    AiImageSize? imageSize,
    int? imageCount,
    ImageQuality? imageQuality,
    ImageGenerateBackground? imageBackground,
    VisionDetailLevel? visionDetailLevel,
    ResponseLength? responseLength,
    GeminiThinkingLevel? thinkingLevel,
    int? maxOutputTokens,
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
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      finishReason: finishReason ?? this.finishReason,
      requestId: requestId ?? this.requestId,
      imageUrls: imageUrls ?? this.imageUrls,
      pdfInfo: pdfInfo ?? this.pdfInfo,
      imageSize: imageSize ?? this.imageSize,
      imageCount: imageCount ?? this.imageCount,
      imageQuality: imageQuality ?? this.imageQuality,
      imageBackground: imageBackground ?? this.imageBackground,
      visionDetailLevel: visionDetailLevel ?? this.visionDetailLevel,
      responseLength: responseLength ?? this.responseLength,
      thinkingLevel: thinkingLevel ?? this.thinkingLevel,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
    );
  }
}
