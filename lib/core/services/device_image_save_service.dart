import 'package:flutter/services.dart';

import '../enums/app_enums.dart';

/// Abstract interface for writing image bytes to the device gallery.
///
/// Concrete implementation [DeviceImageSaveServiceImpl] calls the native
/// MethodChannel registered in MainActivity (Android) and AppDelegate (iOS).
///
/// Keeping this abstract lets tests inject a mock without touching platform code.
abstract class DeviceImageSaveService {
  /// Saves raw image [bytes] to the device gallery.
  ///
  /// [fileName] — safe file name including extension (e.g. "ai_voice_genie_openai_abc_001.jpg").
  /// [mimeType] — MIME type string (e.g. "image/jpeg", "image/png", "image/webp").
  ///
  /// Returns a typed [DeviceImageSaveResult].
  Future<DeviceImageSaveResult> saveImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}

/// Live implementation that delegates to the native MethodChannel.
///
/// Channel: "com.voicegenie.app/image_save"
/// Method:  "saveImageBytes"
///
/// Native response map:
///   "success" → bool
///   "error"   → String? — machine-readable reason code on failure
class DeviceImageSaveServiceImpl implements DeviceImageSaveService {
  static const _channel = MethodChannel('com.voicegenie.app/image_save');

  @override
  Future<DeviceImageSaveResult> saveImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('saveImageBytes', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });

      // Defensive null check — the native side should always return a map.
      if (result == null) return DeviceImageSaveResult.unknown;

      final success = result['success'] as bool? ?? false;
      if (success) return DeviceImageSaveResult.success;

      // Map native error codes to typed Dart results
      final error = result['error'] as String? ?? '';
      return _mapError(error);
    } on PlatformException catch (e) {
      return _mapError(e.code);
    } catch (_) {
      return DeviceImageSaveResult.unknown;
    }
  }

  /// Converts a native error string to a typed [DeviceImageSaveResult].
  ///
  /// Error strings come from the Kotlin/Swift plugin objects and are designed
  /// to be machine-readable prefix matches rather than full equality checks.
  static DeviceImageSaveResult _mapError(String error) {
    if (error.contains('permission')) {
      return DeviceImageSaveResult.permissionDenied;
    }
    if (error.contains('no_space') || error.contains('ENOSPC')) {
      return DeviceImageSaveResult.noSpace;
    }
    if (error.contains('invalid_image') || error.contains('no_bytes')) {
      return DeviceImageSaveResult.invalidImage;
    }
    if (error.contains('network') || error.contains('timeout')) {
      return DeviceImageSaveResult.networkFailure;
    }
    return DeviceImageSaveResult.unknown;
  }
}
