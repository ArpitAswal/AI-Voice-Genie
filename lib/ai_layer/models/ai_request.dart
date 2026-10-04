import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/enums/app_enums.dart';

/// Unified request object passed to AiOrchestrator.execute().
///
/// The orchestrator reads [capability] to determine which providers
/// can handle the request, then passes the full object to the
/// selected adapter.
///
/// Only [capability] and [prompt] are always required.
/// Other fields are capability-specific — the adapter reads only
/// what it needs and ignores the rest.
class AiRequest {
  // ── Always Required ────────────────────────────────────────────────────────

  /// The AI capability being requested — drives provider selection
  final AiCapability capability;

  /// The user's prompt or question
  final String prompt;

  // ── Text Chat ──────────────────────────────────────────────────────────────

  /// Previous messages in the conversation for context continuity.
  /// Each entry: {'role': 'user'|'assistant', 'content': '...'}
  final List<Map<String, String>> conversationHistory;

  // ── Image Understanding (Vision) ─────────────────────────────────────────

  /// Raw image bytes — used for imageUnderstanding capability.
  final List<Uint8List>? imageBytes;

  /// MIME type of the image — e.g. 'image/jpeg', 'image/png'.
  final String? imageMimeType;

  /// Detail level for image vision requests (OpenAI only).
  final VisionDetailLevel? visionDetailLevel;

  // ── Image Generation ───────────────────────────────────────────────────────

  /// Desired output image size for generation requests
  final AiImageSize? imageSize;

  /// Desired output image quality for generation requests
  final ImageQuality? imageQuality;

  /// Number of images to generate (e.g. 1-10) — used in imageGeneration
  final int? imageCount;

  /// Background type for the generated image — used in imageGeneration
  final ImageGenerateBackground? imageBackground;

  // ── PDF Reading Data ────────────────────────────────────────────────────────────

  /// Base64 encoded bytes of PDF documents.
  final List<Uint8List>? pdfBytes;

  /// File names of the PDF documents.
  final List<String>? pdfNames;

  /// The user's preferred response length/max tokens.
  final ResponseLength responseLength;

  /// The user's preferred thinking / reasoning level for Gemini 3.8 Flash.
  final GeminiThinkingLevel? thinkingLevel;

  /// The user's preferred aspect ratio for Gemini image generation (1:1, 16:9, 9:16).
  final GeminiAspectRatio? geminiAspectRatio;

  // ── Request Metadata ───────────────────────────────────────────────────────

  /// Unique request ID — used for correlation across logging, analytics, and usage tracking
  final String requestId;

  /// Timestamp when the request was created
  final DateTime createdAt;

  /// Creates a unified [AiRequest] instance.
  ///
  /// Flow:
  /// - [requestId] defaults to a newly generated UUID v4, which coordinates tracking
  ///   across optimistic UI rendering, provider API calls, analytics events, and outbox synchronization.
  /// - [createdAt] captures the instant the request was originated in the presentation layer.
  AiRequest({
    required this.capability,
    required this.prompt,
    this.conversationHistory = const [],
    this.imageBytes,
    this.imageMimeType,
    this.visionDetailLevel,
    this.responseLength = ResponseLength.balanced,
    this.thinkingLevel,
    this.geminiAspectRatio,
    this.imageSize,
    this.imageQuality,
    this.imageCount,
    this.imageBackground,
    this.pdfBytes,
    this.pdfNames,
    String? requestId,
    DateTime? createdAt,
  })  : requestId = requestId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Estimated token count of the prompt + history.
  ///
  /// Uses the 4-chars-per-token approximation.
  /// Used by adapters to check if context is within model limits.
  int get estimatedTokenCount {
    int charCount = prompt.length;
    for (final msg in conversationHistory) {
      charCount += (msg['content'] ?? '').length;
    }

    return (charCount / 4).ceil();
  }

  @override
  String toString() => 'AiRequest(capability: ${capability.id}, '
      'requestId: $requestId, estimatedTokens: $estimatedTokenCount)';
}
