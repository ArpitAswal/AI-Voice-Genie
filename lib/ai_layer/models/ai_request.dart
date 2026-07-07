import '../../core/enums/app_enums.dart';

/// Unified request object passed to AiOrchestrator.execute().
///
/// The orchestrator reads [capability] to determine which providers
/// can handle the request, then passes the full object to the
/// selected adapter.
///
/// Only [capability], [uid], and [prompt] are always required.
/// Other fields are capability-specific — the adapter reads only
/// what it needs and ignores the rest.
///
/// Usage:
/// ```dart
/// // Text chat
/// final request = AiRequest(
///   capability: AiCapability.textGeneration,
///   uid: authProvider.currentUser!.uid,
///   prompt: 'Explain quantum computing',
///   conversationHistory: previousMessages,
/// );
///
/// // Image generation
/// final request = AiRequest(
///   capability: AiCapability.imageGeneration,
///   uid: uid,
///   prompt: 'A red fox sitting in a snowy forest',
///   imageSize: AiImageSize.square,
///   imageQuality: ImageQuality.Low,
///   imageCount: 1,
/// );
///
/// // Image understanding
/// final request = AiRequest(
///   capability: AiCapability.imageUnderstanding,
///   uid: uid,
///   prompt: 'What is in this image?',
///   imageBytes: jpegBytes,
///   imageMimeType: 'image/jpeg',
/// );
///
/// // PDF parsing
/// final request = AiRequest(
///   capability: AiCapability.pdfParsing,
///   uid: uid,
///   prompt: 'Summarise this document',
///   pdfText: extractedPdfText,
///   pdfFileName: 'report.pdf',
/// );
/// ```
class AiRequest {
  // ── Always Required ────────────────────────────────────────────────────────

  /// The AI capability being requested — drives provider selection
  final AiCapability capability;

  /// Firebase UID of the requesting user — used to look up their API key
  final String uid;

  /// The user's prompt or question
  final String prompt;

  // ── Text Chat ──────────────────────────────────────────────────────────────

  /// Previous messages in the conversation for context continuity.
  /// Each entry: {'role': 'user'|'assistant', 'content': '...'}
  final List<Map<String, String>> conversationHistory;

  // ── Image Understanding ────────────────────────────────────────────────────

  /// Raw image bytes — used for imageUnderstanding capability
  final List<int>? imageBytes;

  /// MIME type of the image — e.g. 'image/jpeg', 'image/png'
  final String? imageMimeType;

  // ── Image Generation ───────────────────────────────────────────────────────

  /// Desired output image size for generation requests
  final AiImageSize imageSize;

  /// Desired output image quality for generation requests
  final ImageQuality imageQuality;

  /// Number of images to generate for a single request
  final int imageCount;

  // ── PDF Parsing ────────────────────────────────────────────────────────────

  /// Text extracted from the PDF — passed as context to the AI
  final String? pdfText;

  /// Original file name of the PDF — for display purposes in response
  final String? pdfFileName;

  // ── Request Metadata ───────────────────────────────────────────────────────

  /// Unique request ID — used for deduplication and logging
  final String requestId;

  /// Timestamp when the request was created
  final DateTime createdAt;

  AiRequest({
    required this.capability,
    required this.uid,
    required this.prompt,
    this.conversationHistory = const [],
    this.imageBytes,
    this.imageMimeType,
    this.imageSize = AiImageSize.square,
    this.imageQuality = ImageQuality.low,
    int imageCount = 1,
    this.pdfText,
    this.pdfFileName,
    String? requestId,
    DateTime? createdAt,
  })  : imageCount = imageCount.clamp(1, 10),
        requestId = requestId ?? _generateId(),
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
    if (pdfText != null) charCount += pdfText!.length;
    return (charCount / 4).ceil();
  }

  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  @override
  String toString() => 'AiRequest(capability: ${capability.id}, uid: $uid, '
      'requestId: $requestId, estimatedTokens: $estimatedTokenCount)';
}
