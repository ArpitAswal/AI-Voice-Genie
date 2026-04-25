import 'dart:typed_data';

import '../../../ai_layer/models/ai_response.dart';
import '../../../core/enums/app_enums.dart';

/// Abstract repository for image generation operations.
///
/// Handles both the AI response processing (URL vs base64 decoding)
/// and persisting the generated image as a conversation in Firestore.
abstract class ImageRepository {
  /// Process an AI image response into displayable bytes.
  ///
  /// OpenAI returns a URL — bytes are fetched from the URL.
  /// Gemini returns base64 — decoded directly to bytes.
  /// Returns null if processing fails.
  Future<Uint8List?> processImageResponse(AiResponse response);

  /// Save a generated image as a conversation + messages in Firestore.
  ///
  /// Creates a conversation of type imageGeneration with:
  ///   - User message: the prompt
  ///   - AI message: the image URL or placeholder text
  Future<String?> saveImageConversation({
    required String uid,
    required String prompt,
    required AiResponse response,
    required AiProviderId providerUsed,
  });

  /// Save image bytes to the device gallery.
  ///
  /// Returns true on success, false on failure.
  Future<bool> saveToGallery(Uint8List imageBytes, String fileName);
}

// =============================================================================
// GENERATED IMAGE RESULT — domain entity for a completed generation
// =============================================================================

/// Holds the result of a successful image generation.
///
/// Passed from ImageGeneratorProvider to the UI for display.
class GeneratedImageResult {
  /// Raw image bytes — used for display and saving
  final Uint8List imageBytes;

  /// Which provider generated this image
  final AiProviderId provider;

  /// The prompt that generated this image
  final String prompt;

  /// Remote URL (if OpenAI) — null for Gemini base64 responses
  final String? remoteUrl;

  /// Conversation ID where this image was saved — for navigation to history
  final String? conversationId;

  const GeneratedImageResult({
    required this.imageBytes,
    required this.provider,
    required this.prompt,
    this.remoteUrl,
    this.conversationId,
  });
}

// =============================================================================
// IMAGE EXCEPTION
// =============================================================================

class ImageException implements Exception {
  final String code;
  final String? technicalMessage;

  const ImageException(this.code, {this.technicalMessage});

  @override
  String toString() =>
      'ImageException(code: $code, technical: $technicalMessage)';
}

class ImageErrorCodes {
  static const String generationFailed = 'image_generation_failed';
  static const String saveFailed = 'something_went_wrong';
  static const String noCapableProvider = 'error_no_models_with_key';
  static const String processingFailed = 'something_went_wrong';
}
