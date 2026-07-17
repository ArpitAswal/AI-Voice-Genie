import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/enums/app_enums.dart';

/// Represents one AI request's usage — tokens consumed, images generated,
/// PDFs processed, and the resulting estimated cost.
///
/// Firestore path: AI_Voice_Genie/Users/User_Model/{uid}/usageEvents/{eventId}
class UsageEventModel {
  /// Unique ID for this event (UUID)
  final String id;

  /// Provider that handled the request
  final AiProviderId provider;

  /// Model string used (e.g. "gpt-4o", "gemini-2.5-flash")
  final String model;

  /// Capability used in this request
  final AiCapability capability;

  /// The originating AiRequest.requestId — used for deduplication
  final String requestId;

  /// Conversation this request belongs to (nullable for standalone requests)
  final String? conversationId;

  /// Message ID this event is linked to (nullable)
  final String? messageId;

  // ── Token Usage ─────────────────────────────────────────────────────────────

  /// Number of input/prompt tokens consumed
  final int inputTokens;

  /// Number of output/completion tokens generated
  final int outputTokens;

  /// Total tokens = inputTokens + outputTokens
  final int totalTokens;

  // ── Attachment Counts ────────────────────────────────────────────────────────

  /// Number of images generated (0 for non-image requests)
  final int imageCount;

  /// Number of PDF documents processed (0 for non-PDF requests)
  final int pdfCount;

  // ── Cost ─────────────────────────────────────────────────────────────────────

  /// Estimated cost in USD based on the provider's pricing table.
  /// May be 0.0 if pricing is unavailable.
  final double estimatedCostUsd;

  // ── Time ─────────────────────────────────────────────────────────────────────

  /// When this event was recorded
  final DateTime createdAt;

  /// Year-month key used for summary grouping: "2026-07"
  final String monthKey;

  const UsageEventModel({
    required this.id,
    required this.provider,
    required this.model,
    required this.capability,
    required this.requestId,
    this.conversationId,
    this.messageId,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.imageCount = 0,
    this.pdfCount = 0,
    this.estimatedCostUsd = 0.0,
    required this.createdAt,
    required this.monthKey,
  });

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseCollections.usageFieldId: id,
      FirebaseCollections.usageFieldProvider: provider.id,
      FirebaseCollections.usageFieldModel: model,
      FirebaseCollections.usageFieldCapability: capability.id,
      FirebaseCollections.usageFieldRequestId: requestId,
      if (conversationId != null)
        FirebaseCollections.usageFieldConversationId: conversationId,
      if (messageId != null) FirebaseCollections.usageFieldMessageId: messageId,
      FirebaseCollections.usageFieldInputTokens: inputTokens,
      FirebaseCollections.usageFieldOutputTokens: outputTokens,
      FirebaseCollections.usageFieldTotalTokens: totalTokens,
      FirebaseCollections.usageFieldImageCount: imageCount,
      FirebaseCollections.usageFieldPdfCount: pdfCount,
      FirebaseCollections.usageFieldEstimatedCostUsd: estimatedCostUsd,
      FirebaseCollections.usageFieldCreatedAt: FieldValue.serverTimestamp(),
      FirebaseCollections.usageFieldMonthKey: monthKey,
    };
  }

  /// Generates the month key string from a [DateTime], e.g. "2026-07"
  static String monthKeyFrom(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    return '${dt.year}-$month';
  }

  /// Returns the current month key
  static String get currentMonthKey => monthKeyFrom(DateTime.now());

  @override
  String toString() => 'UsageEventModel('
      'provider: ${provider.id}, model: $model, '
      'tokens: $totalTokens, cost: \$${estimatedCostUsd.toStringAsFixed(4)}, '
      'month: $monthKey)';
}
