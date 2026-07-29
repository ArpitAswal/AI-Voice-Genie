import 'dart:convert';
import 'dart:io';

import 'package:ai_voice_genie/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/enums/app_enums.dart';
import '../../../../core/services/device_image_save_service.dart';
import '../domain/image_download_repository.dart';

/// Concrete implementation of [ImageDownloadRepository].
///
/// Pipeline:
///   1. Detect image source type from the URL/data-URI/path string.
///   2. Resolve to raw bytes (HTTP fetch, base64 decode, or file read).
///   3. Validate bytes (non-empty, below 25 MB max guard).
///   4. Detect MIME type from data-URI prefix or HTTP Content-Type header.
///   5. Build a safe, non-sensitive filename using only provider/ID/timestamp.
///   6. Delegate save to [DeviceImageSaveService] (native MethodChannel).
class ImageDownloadRepositoryImpl implements ImageDownloadRepository {
  final DeviceImageSaveService _saveService;

  ImageDownloadRepositoryImpl({required DeviceImageSaveService saveService})
      : _saveService = saveService;

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<DeviceImageSaveResult> downloadAndSave({
    required String imageSource,
    String provider = 'unknown',
  }) async {
    // 1. Resolve source string to bytes
    final bytes = await resolveToBytes(imageSource);

    // 2. Validate — reject null, empty, or oversized byte arrays
    if (bytes == null || bytes.isEmpty) {
      return DeviceImageSaveResult.invalidImage;
    }
    if (bytes.length > AppConstants.maxImageDownloadBytes) {
      debugPrint(
          '⚠️ ImageDownload: Image size ${bytes.length} bytes exceeds the 25 MB guard');
      return DeviceImageSaveResult.invalidImage;
    }

    // 3. Detect MIME type and matching extension
    final mime = _detectMimeType(imageSource, bytes);
    final extension = _mimeToExtension(mime);

    // 4. Build a safe filename — never include prompt text or raw URLs
    final fileName = _buildSafeFileName(
      provider: provider,
      extension: extension,
    );

    // 5. Delegate the actual device save to the platform service
    return await _saveService.saveImageBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mime,
    );
  }

  @override
  Future<Uint8List?> resolveToBytes(String imageSource) async {
    final src = imageSource.trim();
    if (src.isEmpty) return null;

    // ── Remote URL ─────────────────────────────────────────────────────────
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return _downloadRemote(src);
    }

    // ── Data URI (e.g. "data:image/png;base64,...") ───────────────────────
    if (src.startsWith('data:image')) {
      return _decodeDataUri(src);
    }

    // ── Local File Path ────────────────────────────────────────────────────
    if (src.startsWith('/') || src.startsWith('file://')) {
      return _readLocalFile(src);
    }

    // ── Raw Base64 (long strings that are not tagged as data URIs) ────────
    // Heuristic used by the existing SmartAsyncImageViewer in message_bubble.dart
    if (src.length > 200 && !src.contains('/')) {
      return _decodeBase64Raw(src);
    }

    return null;
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Fetches image bytes from a remote HTTP/HTTPS URL.
  ///
  /// Returns null on any network error so the caller can map to [DeviceImageSaveResult.networkFailure].
  Future<Uint8List?> _downloadRemote(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(AppConstants.aiRequestTimeout);
      if (response.statusCode != 200) {
        debugPrint(
            '⚠️ ImageDownload: Remote fetch returned ${response.statusCode} for URL');
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('⚠️ ImageDownload: Remote fetch failed — $e');
      return null;
    }
  }

  /// Decodes a base64 data-URI string to bytes.
  ///
  /// Runs the CPU-heavy base64 decode on an isolate to avoid jank on the UI thread.
  Future<Uint8List?> _decodeDataUri(String dataUri) async {
    try {
      final commaIdx = dataUri.indexOf(',');
      if (commaIdx == -1) return null;
      final base64Data = dataUri.substring(commaIdx + 1);
      return await compute(_base64DecodeIsolate, base64Data);
    } catch (e) {
      debugPrint('⚠️ ImageDownload: Data URI decode failed — $e');
      return null;
    }
  }

  /// Decodes a raw base64 string (no data-URI prefix) to bytes.
  Future<Uint8List?> _decodeBase64Raw(String base64Data) async {
    try {
      return await compute(_base64DecodeIsolate, base64Data);
    } catch (e) {
      debugPrint('⚠️ ImageDownload: Raw base64 decode failed — $e');
      return null;
    }
  }

  /// Reads a local file into bytes.
  Future<Uint8List?> _readLocalFile(String path) async {
    try {
      final filePath = path.replaceFirst('file://', '');
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('⚠️ ImageDownload: Local file not found at $filePath');
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('⚠️ ImageDownload: Local file read failed — $e');
      return null;
    }
  }

  // ── MIME / Extension Helpers ───────────────────────────────────────────────

  /// Detects MIME type from:
  ///   1. Data-URI prefix (most reliable for base64 images).
  ///   2. URL file extension.
  ///   3. File magic bytes as a last resort.
  String _detectMimeType(String source, Uint8List bytes) {
    // Data-URI contains the MIME in its prefix (e.g. "data:image/webp;base64,...")
    if (source.startsWith('data:image/')) {
      final semicolonIdx = source.indexOf(';');
      if (semicolonIdx > 11) {
        return source.substring(5, semicolonIdx); // "image/webp"
      }
    }

    // URL extension
    final lower = source.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    if (lower.contains('.gif')) return 'image/gif';
    if (lower.contains('.jpg') || lower.contains('.jpeg')) return 'image/jpeg';

    // Magic bytes — PNG signature: 0x89 50 4E 47
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    // JPEG signature: 0xFF 0xD8
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    // WebP signature: "RIFF....WEBP"
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    // Default fallback — JPEG is the most broadly supported format
    return 'image/jpeg';
  }

  /// Maps a MIME type string to a file extension.
  String _mimeToExtension(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  /// Builds a filename that is safe, unique, and non-sensitive.
  ///
  /// Rules from the plan:
  ///   - Never include prompt text or raw image URLs.
  ///   - Sanitize all parts (strip non-alphanumeric characters).
  ///   - Use timestamp to avoid duplicate name collisions.
  String _buildSafeFileName({
    required String provider,
    required String extension,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final modelProvider = _sanitize(provider);
    return 'aivoicegenie_${modelProvider}_$ts.$extension';
  }

  /// Removes any character that is not alphanumeric or an underscore.
  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}

/// Top-level function for [compute] — must be top-level or static to run in an isolate.
Uint8List _base64DecodeIsolate(String data) {
  return base64Decode(data);
}
