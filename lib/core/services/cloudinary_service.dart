import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for uploading generated images to Cloudinary.
///
/// Upload flow:
///
/// OpenAI
///        ↓
/// Base64 String
///        ↓
/// Decode into bytes
///        ↓
/// Multipart Upload
///        ↓
/// Cloudinary
///        ↓
/// secure_url
class CloudinaryService {
  static const String uploadPreset = 'voice_genie_uploads';

  static const String cloudName = 'lukl51sa';

  static const String apiUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  static final CloudinaryService instance = CloudinaryService._();

  CloudinaryService._();

  /// Uploads a Base64 image to Cloudinary.
  ///
  /// Returns:
  ///
  /// https://res.cloudinary.com/.....
  ///
  /// Returns null if upload fails.
  Future<String?> uploadBase64Image(
    String base64String,
  ) async {
    try {
      if (base64String.isEmpty) {
        return null;
      }

      //----------------------------------------------------
      // Remove Data URI if it already exists.
      //----------------------------------------------------

      final cleanedBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      //----------------------------------------------------
      // Decode Base64
      //----------------------------------------------------

      // CRITICAL BOTTLENECK:
      // Decoding a large base64 string (~870KB) on the main thread takes significant CPU cycles.
      // Since this runs on the main isolate, it temporarily blocks the UI thread.
      // A better approach would be wrapping this call in Isolate.run() to decode in the background.

      final imageBytes = await Isolate.run(() => base64Decode(cleanedBase64));

      //----------------------------------------------------
      // Generate filename
      //----------------------------------------------------

      final filename = 'generated_${DateTime.now().millisecondsSinceEpoch}.png';

      //----------------------------------------------------
      // Multipart Request
      //----------------------------------------------------

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ),
      );

      //----------------------------------------------------
      // Send request
      //----------------------------------------------------

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      //----------------------------------------------------
      // Success
      //----------------------------------------------------

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);

        final secureUrl = json['secure_url'];

        debugPrint('☁️ Cloudinary: Uploaded successfully -> $secureUrl');

        return secureUrl;
      }

      //----------------------------------------------------
      // Failure
      //----------------------------------------------------

      debugPrint(
          '⚠️ Cloudinary upload failed: ${response.statusCode} - ${response.body}');

      return null;
    } catch (e, stackTrace) {
      debugPrint('⚠️ CloudinaryService error: $e');
      debugPrint(stackTrace.toString());

      return null;
    }
  }
}
