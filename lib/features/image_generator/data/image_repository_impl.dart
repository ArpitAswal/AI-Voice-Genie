import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../ai_layer/models/ai_response.dart';
import '../../chat_prompt/data/chat_repository_impl.dart';
import '../../chat_prompt/domain/chat_repository.dart';
import '../domain/image_repository.dart';

/// Concrete implementation of ImageRepository.
///
/// Image response handling:
///   OpenAI/Gemini (base64) → base64.decode() → Uint8List bytes
///
/// Gallery saving uses path_provider + dart:io to write a temp file,
/// then saves using a gallery-saver approach compatible with both platforms.
class ImageRepositoryImpl implements ImageRepository {
  final ChatRepository _chatRepository;
  final http.Client _httpClient;

  ImageRepositoryImpl({
    ChatRepository? chatRepository,
    http.Client? httpClient,
  })  : _chatRepository = chatRepository ?? ChatRepositoryImpl(),
        _httpClient = httpClient ?? http.Client();

  // ── Process Image Response ─────────────────────────────────────────────────

  @override
  Future<Uint8List?> processImageResponse(AiResponse response) async {
    try {
      if (response.contentType == AiResponseContentType.imageUrl &&
          response.imageUrl != null) {
        // OpenAI: fetch bytes from the remote URL
        final httpResponse =
            await _httpClient.get(Uri.parse(response.imageUrl!));

        if (httpResponse.statusCode == 200) {
          return httpResponse.bodyBytes;
        }

        debugPrint(
          '⚠️ ImageRepository: URL fetch failed — ${httpResponse.statusCode}',
        );
        return null;
      }

      if (response.contentType == AiResponseContentType.imageBase64 &&
          response.imageBase64 != null) {
        // Gemini: decode base64 directly
        return base64Decode(response.imageBase64!);
      }

      debugPrint('⚠️ ImageRepository: unsupported content type');
      return null;
    } catch (e) {
      debugPrint('⚠️ ImageRepository.processImageResponse error: $e');
      return null;
    }
  }

  // ── Save to Gallery ────────────────────────────────────────────────────────

  @override
  Future<bool> saveToGallery(Uint8List imageBytes, String fileName) async {
    try {
      // NOTE: Full gallery saving requires the image_gallery_saver package
      // which needs platform-specific permissions setup.
      //
      // Implementation pattern (to be wired after pubspec update):
      // final result = await ImageGallerySaver.saveImage(
      //   imageBytes,
      //   name: fileName,
      //   quality: 100,
      // );
      // return result['isSuccess'] as bool? ?? false;
      //
      // For Phase 5 initial delivery, saving is stubbed.
      // The UI button is functional but shows a "coming soon" message.
      debugPrint('📸 Gallery save stubbed — add image_gallery_saver package');
      return false;
    } catch (e) {
      debugPrint('⚠️ ImageRepository.saveToGallery error: $e');
      return false;
    }
  }
}
