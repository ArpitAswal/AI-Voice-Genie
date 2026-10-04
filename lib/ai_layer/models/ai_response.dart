import '../../core/enums/app_enums.dart';

/// Lightweight representation for backward-compatible image metadata access.
class AiImageData {
  /// Base64-encoded image data
  final String? b64Json;

  /// MIME type of the generated image (e.g. 'image/jpeg', 'image/png')
  final String? mimeType;

  const AiImageData({
    this.b64Json,
    this.mimeType = 'image/png',
    String? url,
    String? revisedPrompt,
  });

  /// URL is not returned directly by the AI provider (uploaded to Cloud Storage later)
  String? get url => null;

  /// Revised prompt is not used by the application
  String? get revisedPrompt => null;
}

/// Unified response object returned by [AiOrchestrator.execute].
///
/// Regardless of which provider handled the request, the caller
/// always receives an [AiResponse] with the same normalized shape.
class AiResponse {
  // ── Always Present ─────────────────────────────────────────────────────────

  /// Which provider ultimately fulfilled this request
  final AiProviderId modelUsed;

  /// The capability that was executed
  final AiCapability capability;

  /// The original request ID for correlation across logs, analytics, and usage
  final String requestId;

  /// How long the provider took to respond in milliseconds
  final int responseTimeMs;

  // ── Payload Content ────────────────────────────────────────────────────────

  /// Text content — present for textGeneration, imageUnderstanding, pdfParsing, and pdfGeneration (Markdown)
  final String? text;

  /// Base64-encoded image string(s) returned by the AI provider (imageGeneration)
  final List<String>? imagesBase64;

  // ── Usage Metadata ─────────────────────────────────────────────────────────

  /// Input/prompt tokens consumed (for per-tier pricing)
  final int inputTokens;

  /// Output/completion tokens generated (for per-tier pricing)
  final int outputTokens;

  /// Total tokens = inputTokens + outputTokens
  final int tokenCount;

  /// Why the model stopped generating (e.g., 'stop', 'length', 'content_filter')
  final String? finishReason;

  /// Unified constructor for [AiResponse].
  ///
  /// Image Normalization Flow:
  /// Adapters may pass a list of base64 strings ([imagesBase64]), a single base64 string ([imageBase64]),
  /// or legacy [generatedImages] metadata. All are normalized into the primary [imagesBase64] list.
  AiResponse({
    required this.modelUsed,
    required this.capability,
    required this.requestId,
    required this.responseTimeMs,
    this.text,
    List<String>? imagesBase64,
    String? imageBase64,
    List<AiImageData>? generatedImages,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.tokenCount = 0,
    this.finishReason,
  }) : imagesBase64 = imagesBase64 ??
            (imageBase64 != null
                ? [imageBase64]
                : generatedImages
                    ?.map((e) => e.b64Json)
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .toList());

  // ── Named Constructors ─────────────────────────────────────────────────────

  /// Creates a text-based response (used for textGeneration, pdfParsing, imageUnderstanding, and pdfGeneration Markdown).
  ///
  /// Flow:
  /// - Sets [text] directly.
  /// - Automatically computes [tokenCount] as (inputTokens + outputTokens) if [tokenCount] is not explicitly supplied.
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
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      text: text,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      tokenCount: tokenCount > 0 ? tokenCount : (inputTokens + outputTokens),
      finishReason: finishReason,
    );
  }

  /// Alias for text-based analysis responses (imageUnderstanding, pdfParsing).
  /// Forwards directly to [AiResponse.text].
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
    return AiResponse.text(
      modelUsed: modelUsed,
      capability: capability,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      text: text,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      tokenCount: tokenCount,
      finishReason: finishReason,
    );
  }

  /// Creates an image generation response.
  ///
  /// Token Flow:
  /// Image generation endpoints (e.g. OpenAI DALL-E) do not always return raw token counts.
  /// When token counts are 0, standard pricing pseudo-tokens (35 input, 252 output per generated image)
  /// are calculated so usage accounting and budget tracking functions predictably.
  factory AiResponse.image({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    String? imageBase64,
    List<String>? imagesBase64,
    List<AiImageData>? generatedImages,
    int inputTokens = 0,
    int outputTokens = 0,
    int tokenCount = 0,
  }) {
    // 1. Resolve image list from any provided parameter format
    final List<String> resolvedImages = imagesBase64 ??
        (imageBase64 != null
            ? [imageBase64]
            : (generatedImages
                    ?.map((e) => e.b64Json)
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                const []));

    // 2. Compute token metrics or assign image generation pseudo-tokens
    final imageCount = resolvedImages.length;
    final int finalInputTokens =
        inputTokens > 0 ? inputTokens : (35 * imageCount);
    final int finalOutputTokens =
        outputTokens > 0 ? outputTokens : (252 * imageCount);
    final int finalTotalTokens =
        tokenCount > 0 ? tokenCount : (finalInputTokens + finalOutputTokens);

    return AiResponse(
      modelUsed: modelUsed,
      capability: AiCapability.imageGeneration,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      imagesBase64: resolvedImages,
      inputTokens: finalInputTokens,
      outputTokens: finalOutputTokens,
      tokenCount: finalTotalTokens,
    );
  }

  /// Backward-compatible alias for [AiResponse.image]
  factory AiResponse.imageBase64({
    required AiProviderId modelUsed,
    required String requestId,
    required int responseTimeMs,
    String? imageBase64,
    List<String>? imagesBase64,
    List<AiImageData>? generatedImages,
    int inputTokens = 0,
    int outputTokens = 0,
    int tokenCount = 0,
  }) =>
      AiResponse.image(
        modelUsed: modelUsed,
        requestId: requestId,
        responseTimeMs: responseTimeMs,
        imageBase64: imageBase64,
        imagesBase64: imagesBase64,
        generatedImages: generatedImages,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        tokenCount: tokenCount,
      );

  // ── Convenience Getters ────────────────────────────────────────────────────

  /// Base64 string of the primary generated image (if any)
  String? get imageBase64 => imagesBase64?.firstOrNull;

  /// Web URL of the primary generated image (if any) - null from LLM
  String? get imageUrl => null;

  /// Whether this response contains displayable text
  bool get hasText => text != null && text!.trim().isNotEmpty;

  /// Whether this response contains at least one generated image
  bool get hasImage => imagesBase64 != null && imagesBase64!.isNotEmpty;

  /// Backward compatibility bridge for code accessing [generatedImages]
  List<AiImageData>? get generatedImages => imagesBase64
      ?.map((b64) => AiImageData(
            b64Json: b64,
            mimeType: b64.startsWith('/9j/') ? 'image/jpeg' : 'image/png',
          ))
      .toList();

  @override
  String toString() =>
      'AiResponse(model: ${modelUsed.id}, capability: ${capability.id}, '
      'responseTimeMs: $responseTimeMs, tokens: $tokenCount)';
}
