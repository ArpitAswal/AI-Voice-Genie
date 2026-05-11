import '../../core/enums/app_enums.dart';

/// Unified response object returned by AiOrchestrator.execute().
///
/// Regardless of which provider handled the request, the caller
/// always receives an AiResponse with the same shape.
///
/// Use [contentType] to determine which field to read:
///   text        → read [text]
///   imageUrl    → read [imageUrl]
///   pdfSummary  → read [text]
class AiResponse {
  // ── Always Present ─────────────────────────────────────────────────────────

  /// Which provider ultimately fulfilled this request
  final AiProviderId modelUsed;

  /// The capability that was executed
  final AiCapability capability;

  /// How the content should be rendered in the UI
  final AiResponseContentType contentType;

  /// The original request ID — for correlation and deduplication
  final String requestId;

  /// How long the provider took to respond in milliseconds
  final int responseTimeMs;

  // ── Text Response ──────────────────────────────────────────────────────────

  /// Text content — present for textGeneration and pdfParsing responses
  final String? text;

  // ── Image Response ─────────────────────────────────────────────────────────

  /// Publicly accessible image URL — present for imageGeneration responses
  final String? imageUrl;

  /// Base64-encoded image data — alternative to imageUrl for some providers
  final String? imageBase64;

  // ── Usage Metadata ─────────────────────────────────────────────────────────

  /// Approximate token count used in this response (from provider metadata)
  final int tokenCount;

  const AiResponse({
    required this.modelUsed,
    required this.capability,
    required this.contentType,
    required this.requestId,
    required this.responseTimeMs,
    this.text,
    this.imageUrl,
    this.imageBase64,
    this.tokenCount = 0,
  });

  // ── Named Constructors ─────────────────────────────────────────────────────

  /// Create a text response (textGeneration, pdfParsing, imageUnderstanding)
  factory AiResponse.text({
    required AiProviderId modelUsed,
    required AiCapability capability,
    required String requestId,
    required int responseTimeMs,
    required String text,
    int tokenCount = 0,
  }) {
    return AiResponse(
      modelUsed: modelUsed,
      capability: capability,
      contentType: AiResponseContentType.text,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      text: text,
      tokenCount: tokenCount,
    );
  }

  /// Create an image URL response (imageGeneration)
  factory AiResponse.imageUrl({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    required String imageUrl,
  }) {
    return AiResponse(
      modelUsed: modelUsed,
      capability: AiCapability.imageGeneration,
      contentType: AiResponseContentType.imageUrl,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      imageUrl: imageUrl,
    );
  }

  /// Create a base64 image response (OpenAI/Gemini image generation)
  factory AiResponse.imageBase64({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    required String imageBase64,
  }) {
    return AiResponse(
      modelUsed: modelUsed,
      capability: AiCapability.imageGeneration,
      contentType: AiResponseContentType.imageBase64,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      imageBase64: imageBase64,
    );
  }

  // ── Convenience Getters ────────────────────────────────────────────────────

  /// Whether this response contains displayable text
  bool get hasText => text != null && text!.isNotEmpty;

  /// Whether this response contains an image (URL or base64)
  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (imageBase64 != null && imageBase64!.isNotEmpty);

  @override
  String toString() =>
      'AiResponse(model: ${modelUsed.id}, type: ${contentType.name}, '
      'responseTimeMs: $responseTimeMs, tokens: $tokenCount)';
}

/// How the response content should be rendered in the UI.
enum AiResponseContentType {
  /// Plain or markdown text
  text,

  /// Remote image URL
  imageUrl,

  /// Base64-encoded image data
  imageBase64,
}
