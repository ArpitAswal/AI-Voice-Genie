import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/local_message_record.dart';
import '../domain/message_model.dart';

/// Data Transfer Object (DTO) for Chat Messages.
///
/// Encapsulates serialization and deserialization across Firestore, Hive,
/// and local Cache formats. Implements resilient multi-key fallbacks and
/// defensive type conversions so that database schema changes or variations
/// never throw [TypeError] or crash the application.
class MessageDto {
  /// Unique identifier of the message turn (UUID v4).
  final String messageId;

  /// Sender role: [MessageRole.user] for user prompts, [MessageRole.assistant] for AI responses.
  final MessageRole role;

  /// Primary textual content:
  /// - Prompt for [MessageRole.user]
  /// - Response for [MessageRole.assistant]
  final String content;

  /// Active AI capability modality:
  /// - `request_capability` for [MessageRole.user]
  /// - `response_capability` for [MessageRole.assistant]
  final AiCapability capability;

  /// Timestamp indicating when the message was originally created locally.
  final DateTime timestamp;

  /// AI provider targeted or used (Gemini, OpenAI, Claude).
  final AiProviderId? modelUsed;

  /// Total tokens consumed (prompt + completion tokens, assistant responses only).
  final int tokenCount;

  /// Delivery lifecycle status: sending, delivered, failed, or partial.
  final MessageStatus status;

  /// Performance latency in milliseconds from request dispatch to response completion (assistant only).
  final int? responseTimeMs;

  /// Provider stop reason indicating why generation halted (e.g., 'STOP', 'length', 'safety').
  final String? finishReason;

  /// Originating user prompt ID correlating this assistant response.
  final String? requestId;

  /// Cloud Storage URLs or local image file paths attached to this message.
  final List<String>? imageUrls;

  /// Structured PDF attachments metadata (local file path, document name, size, Cloud Storage URL).
  final List<PdfAttachmentInfo>? pdfInfo;

  /// Image generation parameters (only relevant when capability == [AiCapability.imageGeneration]).
  final AiImageSize? imageSize;
  final int? imageCount;
  final ImageQuality? imageQuality;
  final ImageGenerateBackground? imageBackground;

  /// Vision understanding detail level ([VisionDetailLevel.low], [VisionDetailLevel.high]).
  final VisionDetailLevel? visionDetailLevel;

  /// Text generation parameters (stored on user messages for traceability and telemetry).
  final ResponseLength? responseLength;
  final GeminiThinkingLevel? thinkingLevel;
  final int? maxOutputTokens;

  // ── Local Hive-only sync metadata ─────────────────────────────────────────

  /// User ID owning this message (persisted only in local Hive).
  final String? uid;

  /// Conversation ID to which this message belongs (persisted only in local Hive).
  final String? conversationId;

  /// True when the message belongs to a locally deleted conversation.
  final bool isDeleted;

  /// Local synchronization lifecycle state ([SyncStatus.synced], [SyncStatus.pendingCreate], etc.).
  final SyncStatus syncStatus;

  /// When this record was written locally to Hive.
  final DateTime localUpdatedAt;

  /// Remote Firestore `updatedAt` timestamp from last successful merge.
  final DateTime? remoteUpdatedAt;

  const MessageDto({
    required this.messageId,
    required this.role,
    required this.content,
    required this.capability,
    required this.timestamp,
    this.modelUsed,
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
    this.uid,
    this.conversationId,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pendingCreate,
    required this.localUpdatedAt,
    this.remoteUpdatedAt,
  });

  // ── Defensive Deserializer (fromMap) ──────────────────────────────────────

  /// Deserializes a [MessageDto] from any dynamic Map (Firestore, Hive, Cache, JSON).
  ///
  /// Implements multi-key fallbacks and defensive type casting to guarantee
  /// the app never crashes on schema evolution or alternate key names.
  factory MessageDto.fromMap(Map<dynamic, dynamic> map) {
    // 1. Message ID (strip reference prefixes if present)
    final rawId = _parseString(map, [
      FirebaseCollections.fieldMessageID,
      'messageId',
      'id',
      'msgId',
      'message_id',
    ]);
    final messageId = _normalizeStoredId(rawId);

    // 2. Role
    final rawRole = _parseString(
        map,
        [
          FirebaseCollections.fieldRole,
          FirebaseCollections.fieldMessageRole,
          'userRole',
          'role',
        ],
        fallback: 'user');
    final role = MessageRole.fromValue(rawRole);

    // 3. Content (Prompt vs Response vs legacy Content/Error)
    final List<String> contentKeys = role == MessageRole.user
        ? [
            FirebaseCollections.fieldPrompt,
            'request',
            FirebaseCollections.fieldMessageContent,
            'lastPrompt',
            'text',
            'message',
            FirebaseCollections.fieldResponse,
          ]
        : [
            FirebaseCollections.fieldResponse,
            FirebaseCollections.fieldMessageContent,
            'lastPrompt',
            'text',
            'message',
            FirebaseCollections.fieldPrompt,
            'request',
            FirebaseCollections.fieldError,
            'errorMessage',
            'error_message',
            'errorReason',
          ];
    final rawContent = _parseString(map, contentKeys);
    final String content;
    if (rawContent == 'error_unexpected_ai' ||
        rawContent == 'something_went_wrong') {
      content = AppLocalizations.lookupMessage(rawContent);
    } else {
      content = rawContent;
    }

    // 4. Capability (request_capability vs response_capability vs legacy contentType)
    final List<String> capabilityKeys = role == MessageRole.user
        ? [
            FirebaseCollections.fieldRequestCapability,
            FirebaseCollections.fieldMessageContentType,
            'capability',
            'requestCapability',
            FirebaseCollections.fieldResponseCapability,
          ]
        : [
            FirebaseCollections.fieldResponseCapability,
            FirebaseCollections.fieldMessageContentType,
            'capability',
            'responseCapability',
            FirebaseCollections.fieldRequestCapability,
          ];
    final rawCapability = _parseString(
      map,
      capabilityKeys,
      fallback: 'text_generation',
    );
    final capability = AiCapability.fromValue(rawCapability);

    // 5. Timestamp (handles Timestamp, DateTime, String, int millis)
    final timestamp = _parseDateTime(map, [
          FirebaseCollections.fieldTimestamp,
          FirebaseCollections.fieldMessageTimestamp,
          'createdAt',
          'created_at',
          'time',
        ]) ??
        DateTime.now();

    // 6. Model / Provider
    final rawModel = _parseOptionalString(map, [
      FirebaseCollections.fieldModelUsed,
      FirebaseCollections.fieldMessageModelUsed,
      'modelRequest',
      'model',
      'provider',
      'model_used',
    ]);
    final modelUsed = rawModel != null && rawModel.isNotEmpty
        ? AiProviderId.fromId(rawModel)
        : null;

    // 7. Token Count
    final tokenCount = _parseInt(map, [
      FirebaseCollections.fieldTokenCount,
      FirebaseCollections.fieldMessageTokenCount,
      'token_count',
      'tokens',
    ]);

    // 8. Status
    final rawStatus = _parseString(
        map,
        [
          FirebaseCollections.fieldStatus,
          FirebaseCollections.fieldMessageStatus,
        ],
        fallback: 'delivered');
    final status = MessageStatus.fromValue(rawStatus);

    // 9. Response Time (ms)
    final responseTimeMs = _parseOptionalInt(map, [
      FirebaseCollections.fieldResponseTimeMs,
      'response_time_ms',
      'durationMs',
      'latencyMs',
    ]);

    // 10. Finish Reason
    final finishReason = _parseOptionalString(map, [
      FirebaseCollections.fieldFinishReason,
      'finish_reason',
      'stopReason',
    ]);

    // 10b. Request ID (originating prompt ID)
    final requestId = _parseOptionalString(map, [
      FirebaseCollections.fieldRequestId,
      'requestId',
      'request_id',
    ]);

    // 11. Attachments
    final imageUrls = _parseImageUrls(map, [
      FirebaseCollections.fieldImageUrl,
      FirebaseCollections.fieldMessageImageUrl,
      'images',
      'image_urls',
    ]);

    final pdfInfo = _parsePdfAttachments(map);

    // 13. Image generation options
    final rawImageSize = _parseOptionalString(map, [
      FirebaseCollections.fieldImageSize,
      'size',
      'image_size',
    ]);
    final imageSize = rawImageSize != null
        ? AiImageSize.values.firstWhere(
            (s) => s.apiValue == rawImageSize || s.name == rawImageSize,
            orElse: () => AiImageSize.square,
          )
        : null;

    final imageCount = _parseOptionalInt(map, [
      FirebaseCollections.fieldImageCount,
      'count',
      'image_count',
      'generateImageRequest',
    ]);

    final rawImageQuality = _parseOptionalString(map, [
      FirebaseCollections.fieldImageQuality,
      'quality',
      'image_quality',
    ]);
    final imageQuality = rawImageQuality != null
        ? ImageQuality.values.firstWhere(
            (q) => q.name == rawImageQuality,
            orElse: () => ImageQuality.low,
          )
        : null;

    final rawImageBackground = _parseOptionalString(map, [
      FirebaseCollections.fieldImageBackground,
      'background',
      'image_background',
    ]);
    final imageBackground = rawImageBackground != null
        ? ImageGenerateBackground.fromString(rawImageBackground)
        : null;

    final rawVisionDetail = _parseOptionalString(map, [
      FirebaseCollections.fieldVisionDetailLevel,
      'vision_detail_level',
      'detail',
    ]);
    final visionDetailLevel = rawVisionDetail != null
        ? VisionDetailLevel.fromValue(rawVisionDetail)
        : null;

    // 14. Text generation parameters
    final rawResponseLength = _parseOptionalString(map, [
      FirebaseCollections.fieldResponseLength,
      'response_length',
      'responseLength',
    ]);
    final responseLength = rawResponseLength != null
        ? ResponseLength.fromName(rawResponseLength)
        : null;

    final rawThinkingLevel = _parseOptionalString(map, [
      FirebaseCollections.fieldThinkingLevel,
      'thinking_level',
      'thinkingLevel',
    ]);
    final thinkingLevel = rawThinkingLevel != null
        ? GeminiThinkingLevel.fromString(rawThinkingLevel)
        : null;

    final maxOutputTokens = _parseOptionalInt(map, [
      FirebaseCollections.fieldMaxOutputTokens,
      'max_output_tokens',
      'maxOutputTokens',
    ]);

    // 15. Local Hive metadata
    final uid = _parseOptionalString(map, ['uid', 'userId', 'user_id']);
    final conversationId = _parseOptionalString(map, [
      'conversationId',
      FirebaseCollections.fieldConversationID,
      'conversation_id',
    ]);
    final isDeleted = _parseBool(map, ['isDeleted', 'is_deleted', 'deleted']);
    final rawSyncStatus = _parseString(map, ['syncStatus', 'sync_status'],
        fallback: SyncStatus.pendingCreate.value);
    final syncStatus = SyncStatus.fromValue(rawSyncStatus);

    final localUpdatedAt =
        _parseDateTime(map, ['localUpdatedAt', 'local_updated_at']) ??
            DateTime.now();
    final remoteUpdatedAt =
        _parseDateTime(map, ['remoteUpdatedAt', 'remote_updated_at']);

    return MessageDto(
      messageId: messageId,
      role: role,
      content: content,
      capability: capability,
      timestamp: timestamp,
      modelUsed: modelUsed,
      tokenCount: tokenCount,
      status: status,
      responseTimeMs: responseTimeMs,
      finishReason: finishReason,
      requestId: requestId,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      imageCount: imageCount,
      imageQuality: imageQuality,
      imageBackground: imageBackground,
      visionDetailLevel: visionDetailLevel,
      responseLength: responseLength,
      thinkingLevel: thinkingLevel,
      maxOutputTokens: maxOutputTokens,
      uid: uid,
      conversationId: conversationId,
      isDeleted: isDeleted,
      syncStatus: syncStatus,
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
    );
  }

  // ── Bridge: Domain Models ─────────────────────────────────────────────────

  /// Converts this DTO into a domain [MessageModel] for presentation & business logic.
  MessageModel toDomain() {
    return MessageModel(
      msgId: messageId,
      role: role,
      lastPrompt: content,
      requestCapability: capability,
      timestamp: timestamp,
      modelRequest: modelUsed,
      tokenCount: tokenCount,
      status: status,
      responseTimeMs: responseTimeMs,
      finishReason: finishReason,
      requestId: requestId,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      generateImageRequest: imageCount,
      imageQuality: imageQuality,
      imageBackground: imageBackground,
      visionDetailLevel: visionDetailLevel,
      responseLength: responseLength,
      thinkingLevel: thinkingLevel,
      maxOutputTokens: maxOutputTokens,
    );
  }

  /// Builds a [MessageDto] from a domain [MessageModel].
  factory MessageDto.fromDomain(
    MessageModel model, {
    String? uid,
    String? conversationId,
    bool isDeleted = false,
    SyncStatus syncStatus = SyncStatus.pendingCreate,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  }) {
    return MessageDto(
      messageId: model.messageId,
      role: model.role,
      content: model.lastPrompt,
      capability: model.requestCapability,
      timestamp: model.timestamp,
      modelUsed: model.modelRequest,
      tokenCount: model.tokenCount,
      status: model.status,
      responseTimeMs: model.responseTimeMs,
      finishReason: model.finishReason,
      requestId: model.requestId,
      imageUrls: model.imageUrls,
      pdfInfo: model.pdfInfo,
      imageSize: model.imageSize,
      imageCount: model.generateImageRequest,
      imageQuality: model.imageQuality,
      imageBackground: model.imageBackground,
      visionDetailLevel: model.visionDetailLevel,
      responseLength: model.responseLength,
      thinkingLevel: model.thinkingLevel,
      maxOutputTokens: model.maxOutputTokens,
      uid: uid,
      conversationId: conversationId,
      isDeleted: isDeleted,
      syncStatus: syncStatus,
      localUpdatedAt: localUpdatedAt ?? DateTime.now(),
      remoteUpdatedAt: remoteUpdatedAt,
    );
  }

  /// Converts this DTO into a domain [LocalMessageRecord] for Hive storage tracking.
  LocalMessageRecord toLocalRecord() {
    return LocalMessageRecord(
      uid: uid ?? '',
      conversationId: conversationId ?? '',
      messageId: messageId,
      role: role,
      content: content,
      contentType: capability,
      timestamp: timestamp,
      modelRequest: modelUsed,
      tokenCount: tokenCount,
      status: status,
      responseTimeMs: responseTimeMs,
      finishReason: finishReason,
      requestId: requestId,
      imageUrls: imageUrls,
      pdfInfo: pdfInfo,
      imageSize: imageSize,
      imageCount: imageCount,
      imageQuality: imageQuality,
      imageBackground: imageBackground,
      visionDetailLevel: visionDetailLevel,
      responseLength: responseLength,
      thinkingLevel: thinkingLevel,
      maxOutputTokens: maxOutputTokens,
      isDeleted: isDeleted,
      syncStatus: syncStatus,
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
    );
  }

  /// Builds a [MessageDto] from a domain [LocalMessageRecord].
  factory MessageDto.fromLocalRecord(LocalMessageRecord record) {
    return MessageDto(
      messageId: record.messageId,
      role: record.role,
      content: record.content,
      capability: record.contentType,
      timestamp: record.timestamp,
      modelUsed: record.modelRequest,
      tokenCount: record.tokenCount,
      status: record.status,
      responseTimeMs: record.responseTimeMs,
      finishReason: record.finishReason,
      requestId: record.requestId,
      imageUrls: record.imageUrls,
      pdfInfo: record.pdfInfo,
      imageSize: record.imageSize,
      imageCount: record.imageCount,
      imageQuality: record.imageQuality,
      imageBackground: record.imageBackground,
      visionDetailLevel: record.visionDetailLevel,
      responseLength: record.responseLength,
      thinkingLevel: record.thinkingLevel,
      maxOutputTokens: record.maxOutputTokens,
      uid: record.uid,
      conversationId: record.conversationId,
      isDeleted: record.isDeleted,
      syncStatus: record.syncStatus,
      localUpdatedAt: record.localUpdatedAt,
      remoteUpdatedAt: record.remoteUpdatedAt,
    );
  }

  // ── Serializers ───────────────────────────────────────────────────────────

  /// Serializes to Firestore document map using authentic message [Timestamp].
  Map<String, dynamic> toFirestoreMap() {
    final bool isUserMessage = role == MessageRole.user;
    return {
      FirebaseCollections.fieldMessageID: messageId,
      FirebaseCollections.fieldRole: role.value,
      if (isUserMessage) ...{
        FirebaseCollections.fieldPrompt: content,
        FirebaseCollections.fieldRequestCapability: capability.id,
        if (responseLength != null)
          FirebaseCollections.fieldResponseLength: responseLength!.name,
        if (thinkingLevel != null && modelUsed == AiProviderId.gemini)
          FirebaseCollections.fieldThinkingLevel: thinkingLevel!.apiValue,
        if (maxOutputTokens != null)
          FirebaseCollections.fieldMaxOutputTokens: maxOutputTokens,
      } else ...{
        if (requestId != null && requestId!.isNotEmpty)
          FirebaseCollections.fieldRequestId: requestId,
        FirebaseCollections.fieldResponse: content,
        FirebaseCollections.fieldResponseCapability: capability.id,
        FirebaseCollections.fieldTokenCount: tokenCount,
        if (responseTimeMs != null)
          FirebaseCollections.fieldResponseTimeMs: responseTimeMs,
        if (finishReason != null && finishReason!.isNotEmpty)
          FirebaseCollections.fieldFinishReason: finishReason,
      },
      FirebaseCollections.fieldTimestamp: Timestamp.fromDate(timestamp),
      FirebaseCollections.fieldStatus: status.value,
      if (modelUsed != null) FirebaseCollections.fieldModelUsed: modelUsed!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((p) => p.toMap()).toList(),
      if (capability == AiCapability.imageGeneration) ...{
        if (imageSize != null)
          FirebaseCollections.fieldImageSize: imageSize!.apiValue,
        if (imageCount != null) FirebaseCollections.fieldImageCount: imageCount,
        if (imageQuality != null && modelUsed != AiProviderId.gemini)
          FirebaseCollections.fieldImageQuality: imageQuality!.name,
        if (imageBackground != null)
          FirebaseCollections.fieldImageBackground: imageBackground!.name,
      },
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,
    };
  }

  /// Serializes to an outbox sync payload (uses ISO 8601 string for timestamp).
  Map<String, dynamic> toSyncPayload() {
    final bool isUserMessage = role == MessageRole.user;
    return {
      FirebaseCollections.fieldMessageID: messageId,
      FirebaseCollections.fieldRole: role.value,
      if (isUserMessage) ...{
        FirebaseCollections.fieldPrompt: content,
        FirebaseCollections.fieldRequestCapability: capability.id,
        if (responseLength != null)
          FirebaseCollections.fieldResponseLength: responseLength!.name,
        if (thinkingLevel != null && modelUsed == AiProviderId.gemini)
          FirebaseCollections.fieldThinkingLevel: thinkingLevel!.apiValue,
        if (maxOutputTokens != null)
          FirebaseCollections.fieldMaxOutputTokens: maxOutputTokens,
      } else ...{
        if (requestId != null && requestId!.isNotEmpty)
          FirebaseCollections.fieldRequestId: requestId,
        FirebaseCollections.fieldResponse: content,
        FirebaseCollections.fieldResponseCapability: capability.id,
        FirebaseCollections.fieldTokenCount: tokenCount,
        if (responseTimeMs != null)
          FirebaseCollections.fieldResponseTimeMs: responseTimeMs,
        if (finishReason != null && finishReason!.isNotEmpty)
          FirebaseCollections.fieldFinishReason: finishReason,
      },
      FirebaseCollections.fieldTimestamp: timestamp.toIso8601String(),
      FirebaseCollections.fieldStatus: status.value,
      if (modelUsed != null) FirebaseCollections.fieldModelUsed: modelUsed!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((p) => p.toMap()).toList(),
      if (capability == AiCapability.imageGeneration) ...{
        if (imageSize != null)
          FirebaseCollections.fieldImageSize: imageSize!.apiValue,
        if (imageCount != null) FirebaseCollections.fieldImageCount: imageCount,
        if (imageQuality != null && modelUsed != AiProviderId.gemini)
          FirebaseCollections.fieldImageQuality: imageQuality!.name,
        if (imageBackground != null)
          FirebaseCollections.fieldImageBackground: imageBackground!.name,
      },
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,
    };
  }

  /// Serializes to Hive local database map.
  ///
  /// Strictly aligns with Firestore field names and conditional logic:
  /// - User messages store [prompt], [request_capability], [responseLength], [thinkingLevel], [maxOutputTokens].
  /// - Assistant messages store [response], [response_capability], [tokenCount], [responseTimeMs], [finishReason].
  /// - Image quality is omitted for Gemini or when null.
  /// - Plus essential local Hive synchronization metadata (uid, conversationId, isDeleted, syncStatus, timestamps).
  Map<String, dynamic> toHiveMap() {
    final bool isUserMessage = role == MessageRole.user;
    return {
      // ── Identical Firestore Field Names & Conditions ─────────────────────
      FirebaseCollections.fieldMessageID: messageId,
      FirebaseCollections.fieldRole: role.value,
      if (isUserMessage) ...{
        FirebaseCollections.fieldPrompt: content,
        FirebaseCollections.fieldRequestCapability: capability.id,
        if (responseLength != null)
          FirebaseCollections.fieldResponseLength: responseLength!.name,
        if (thinkingLevel != null && modelUsed == AiProviderId.gemini)
          FirebaseCollections.fieldThinkingLevel: thinkingLevel!.apiValue,
        if (maxOutputTokens != null)
          FirebaseCollections.fieldMaxOutputTokens: maxOutputTokens,
      } else ...{
        if (requestId != null && requestId!.isNotEmpty)
          FirebaseCollections.fieldRequestId: requestId,
        FirebaseCollections.fieldResponse: content,
        FirebaseCollections.fieldResponseCapability: capability.id,
        FirebaseCollections.fieldTokenCount: tokenCount,
        if (responseTimeMs != null)
          FirebaseCollections.fieldResponseTimeMs: responseTimeMs,
        if (finishReason != null && finishReason!.isNotEmpty)
          FirebaseCollections.fieldFinishReason: finishReason,
      },
      FirebaseCollections.fieldTimestamp: timestamp.toIso8601String(),
      FirebaseCollections.fieldStatus: status.value,
      if (modelUsed != null) FirebaseCollections.fieldModelUsed: modelUsed!.id,
      if (imageUrls != null && imageUrls!.isNotEmpty)
        FirebaseCollections.fieldImageUrl: imageUrls,
      if (pdfInfo != null && pdfInfo!.isNotEmpty)
        FirebaseCollections.fieldPdfInfo:
            pdfInfo!.map((p) => p.toMap()).toList(),
      if (capability == AiCapability.imageGeneration) ...{
        if (imageSize != null)
          FirebaseCollections.fieldImageSize: imageSize!.apiValue,
        if (imageCount != null) FirebaseCollections.fieldImageCount: imageCount,
        if (imageQuality != null && modelUsed != AiProviderId.gemini)
          FirebaseCollections.fieldImageQuality: imageQuality!.name,
        if (imageBackground != null)
          FirebaseCollections.fieldImageBackground: imageBackground!.name,
      },
      if (visionDetailLevel != null)
        FirebaseCollections.fieldVisionDetailLevel: visionDetailLevel!.name,

      // ── Local Hive Metadata ──────────────────────────────────────────────
      if (uid != null && uid!.isNotEmpty) 'uid': uid,
      if (conversationId != null && conversationId!.isNotEmpty)
        'conversationId': conversationId,
      'isDeleted': isDeleted,
      'syncStatus': syncStatus.value,
      'localUpdatedAt': localUpdatedAt.toIso8601String(),
      if (remoteUpdatedAt != null)
        'remoteUpdatedAt': remoteUpdatedAt!.toIso8601String(),
    };
  }

  /// Serializes for local memory / JSON cache.
  Map<String, dynamic> toCacheMap() => toHiveMap();

  // ── Private Defensive Parsing Helpers ─────────────────────────────────────

  static String _parseString(Map map, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) {
        final str = val.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return fallback;
  }

  static String? _parseOptionalString(Map map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) {
        final str = val.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

  static int _parseInt(Map map, List<String> keys, {int fallback = 0}) {
    for (final key in keys) {
      final val = map[key];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val.trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static int? _parseOptionalInt(Map map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool _parseBool(Map map, List<String> keys, {bool fallback = false}) {
    for (final key in keys) {
      final val = map[key];
      if (val is bool) return val;
      if (val is String) {
        final lower = val.trim().toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      if (val is num) return val != 0;
    }
    return fallback;
  }

  static DateTime? _parseDateTime(Map map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val == null) continue;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      if (val is int && val > 0) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
    }
    return null;
  }

  static List<String>? _parseImageUrls(Map map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is List && val.isNotEmpty) {
        return val.map((e) => e.toString()).toList();
      }
      if (val is String && val.trim().isNotEmpty) {
        return [val.trim()];
      }
    }
    return null;
  }

  static List<PdfAttachmentInfo>? _parsePdfAttachments(Map map) {
    // 1. Direct structured PDF list
    final direct = map[FirebaseCollections.fieldPdfInfo] ??
        map[FirebaseCollections.fieldMessagePdfInfo] ??
        map['pdfInfo'] ??
        map['pdf_info'];
    if (direct is List && direct.isNotEmpty) {
      final list = <PdfAttachmentInfo>[];
      for (final item in direct) {
        if (item is Map) {
          list.add(PdfAttachmentInfo.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      if (list.isNotEmpty) return list;
    }

    // 2. Legacy parallel arrays fallback (pdfPaths & pdfName)
    final rawPaths = map['pdfPaths'] ?? map['paths'];
    final rawNames =
        map[FirebaseCollections.fieldPdfName] ?? map['pdfName'] ?? map['names'];
    final paths =
        rawPaths is List ? rawPaths.map((e) => e.toString()).toList() : null;
    final names =
        rawNames is List ? rawNames.map((e) => e.toString()).toList() : null;

    if (paths != null && names != null) {
      final pdfs = <PdfAttachmentInfo>[];
      final len = paths.length < names.length ? paths.length : names.length;
      for (int i = 0; i < len; i++) {
        pdfs.add(PdfAttachmentInfo(path: paths[i], name: names[i]));
      }
      return pdfs.isNotEmpty ? pdfs : null;
    }

    return null;
  }

  static String _normalizeStoredId(String id) {
    const prefixes = ['UserRef-', 'AIRef-'];
    for (final prefix in prefixes) {
      if (id.startsWith(prefix)) {
        return id.substring(prefix.length);
      }
    }
    return id;
  }
}
