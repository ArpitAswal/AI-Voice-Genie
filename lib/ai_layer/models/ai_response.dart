import '../../core/enums/app_enums.dart';

/// Represents a single generated image and its metadata from an AI provider.
class AiImageData {
  /// Base64-encoded image data (if requested format was b64_json)
  final String? b64Json;

  /// Publicly accessible image URL (if requested format was url)
  final String? url;

  /// The prompt used to generate the image, if revised by the provider
  final String? revisedPrompt;

  /// MIME type of the generated image (e.g. 'image/jpeg', 'image/png')
  final String? mimeType;

  const AiImageData({
    this.b64Json,
    this.url,
    this.revisedPrompt,
    this.mimeType,
  });
}

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

  /// Multiple image generation results including attributes like revised prompts.
  final List<AiImageData>? generatedImages;

  // ── Usage Metadata ─────────────────────────────────────────────────────────

  /// Input/prompt tokens consumed (for per-tier pricing)
  final int inputTokens;

  /// Output/completion tokens generated (for per-tier pricing)
  final int outputTokens;

  /// Total tokens = inputTokens + outputTokens
  /// (kept for backward compatibility with analytics)
  final int tokenCount;

  /// Why the model stopped generating (e.g., 'stop', 'length', 'content_filter')
  final String? finishReason;

  const AiResponse({
    required this.modelUsed,
    required this.capability,
    required this.contentType,
    required this.requestId,
    required this.responseTimeMs,
    this.text,
    this.imageUrl,
    this.imageBase64,
    this.generatedImages,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.tokenCount = 0,
    this.finishReason,
  });

  // ── Named Constructors ─────────────────────────────────────────────────────

  /// Create a text response (textGeneration, pdfParsing, imageUnderstanding)
  factory AiResponse.text({
    required AiProviderId modelUsed,
    required AiCapability capability,
    required String requestId,
    required int responseTimeMs,
    required String text,
    int inputTokens = 0,
    int outputTokens = 0,
    int tokenCount = 0,
    String? finishReason,
  }) {
    return AiResponse(
      modelUsed: modelUsed,
      capability: capability,
      contentType: AiResponseContentType.text,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      text: text,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      tokenCount: tokenCount > 0 ? tokenCount : inputTokens + outputTokens,
      finishReason: finishReason,
    );
  }

  factory AiResponse.analysis({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    required AiCapability capability,
    required String text,
    int inputTokens = 0,
    int outputTokens = 0,
    int tokenCount = 0,
    String? finishReason,
  }) {
    return AiResponse(
      modelUsed: modelUsed,
      capability: capability,
      requestId: requestId,
      contentType: AiResponseContentType.analysis,
      responseTimeMs: responseTimeMs,
      text: text,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      tokenCount: tokenCount > 0 ? tokenCount : inputTokens + outputTokens,
      finishReason: finishReason,
    );
  }

  /// Create a base64 image response (OpenAI/Gemini image generation)
  factory AiResponse.imageBase64({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    required String? imageBase64,
    required List<AiImageData> generatedImages,
    int inputTokens = 0,
    int outputTokens = 0,
    int tokenCount = 0,
  }) {
    // OpenAI doesn't always return tokens for image generation, so we use pseudo-tokens as fallback.
    final imageCount = generatedImages.length;
    final int finalInputTokens =
        inputTokens > 0 ? inputTokens : (35 * imageCount);
    final int finalOutputTokens =
        outputTokens > 0 ? outputTokens : (252 * imageCount);
    final int finalTotalTokens =
        tokenCount > 0 ? tokenCount : (finalInputTokens + finalOutputTokens);

    return AiResponse(
      modelUsed: modelUsed,
      capability: AiCapability.imageGeneration,
      contentType: AiResponseContentType.imageBase64,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      imageBase64: imageBase64,
      generatedImages: generatedImages,
      inputTokens: finalInputTokens,
      outputTokens: finalOutputTokens,
      tokenCount: finalTotalTokens,
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
