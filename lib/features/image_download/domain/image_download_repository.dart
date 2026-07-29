import 'dart:typed_data';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/services/device_image_save_service.dart';

/// Abstract interface for the image download feature repository.
///
/// Owns the full pipeline from image source → bytes → device save:
///   1. Detect image source type (remote URL, data URI, local file).
///   2. Resolve source to raw bytes.
///   3. Detect MIME type.
///   4. Build a safe filename.
///   5. Delegate to [DeviceImageSaveService].
///   6. Return a typed [DeviceImageSaveResult].
abstract class ImageDownloadRepository {
  /// Downloads and saves an image from any supported source.
  ///
  /// [imageSource] — one of:
  ///   - Remote URL: "https://..."
  ///   - Data URI: "data:image/png;base64,..."
  ///   - Local file path: "/data/user/0/.../profile_avatar.jpg"
  ///
  /// Optional context parameters are used only to build the safe filename
  /// and analytics event. They are never stored.
  ///
  /// [provider]        — AI provider name (e.g. "openai", "gemini").
  /// [conversationId]  — Conversation document ID (alphanumeric only after sanitation).
  /// [messageId]       — Message document ID.
  /// [imageIndex]      — Zero-based index of the image within a multi-image message.
  Future<DeviceImageSaveResult> downloadAndSave({
    required String imageSource,
    String provider = 'unknown',
  });

  /// Resolves an image source string to raw bytes without saving.
  ///
  /// Used internally and exposed for testability.
  Future<Uint8List?> resolveToBytes(String imageSource);
}
