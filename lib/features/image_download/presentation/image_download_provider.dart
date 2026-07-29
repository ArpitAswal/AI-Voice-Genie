import 'package:flutter/foundation.dart';

import '../../../../core/enums/app_enums.dart';
import '../domain/image_download_repository.dart';

/// ChangeNotifier provider for managing the download state of generated images.
///
/// State is keyed by a unique image key composed of [messageId_imageIndex].
/// This lets multiple images in the same message download independently.
///
/// Usage:
/// ```dart
/// final provider = context.read<ImageDownloadProvider>();
/// await provider.downloadImage(
///   imageSource: url,
///   imageKey: 'msg123_0',
///   provider: 'openai',
/// );
/// ```
class ImageDownloadProvider extends ChangeNotifier {
  final ImageDownloadRepository _repository;

  ImageDownloadProvider({required ImageDownloadRepository repository})
      : _repository = repository;

  /// Per-image state map — key: "{messageId}_{imageIndex}"
  final Map<String, ImageDownloadState> _states = {};

  /// Per-image error result — null when state is idle or success
  final Map<String, DeviceImageSaveResult> _failures = {};

  // ── Public Accessors ───────────────────────────────────────────────────────

  /// Returns the current download state for [imageKey].
  ImageDownloadState stateFor(String imageKey) =>
      _states[imageKey] ?? ImageDownloadState.idle;

  /// Returns the failure reason for [imageKey], or null if not failed.
  DeviceImageSaveResult? failureFor(String imageKey) => _failures[imageKey];

  // ── Download Action ────────────────────────────────────────────────────────

  /// Initiates the download-and-save pipeline for a generated image.
  ///
  /// Duplicate tap guard: silently ignores calls while [imageKey] is already
  /// [ImageDownloadState.loading], so rapid taps do not queue multiple saves.
  ///
  /// Analytics is fired after the save result is known (fire-and-forget after
  /// the await) as recommended in the image download plan.
  Future<void> downloadImage({
    required String imageSource,
    required String imageKey,
    String provider = 'unknown',
  }) async {
    // Duplicate tap guard — ignore if already in progress
    if (stateFor(imageKey) == ImageDownloadState.loading) return;

    _setState(imageKey, ImageDownloadState.loading);
    _failures.remove(imageKey);

    // Await the full pipeline so the UI receives an accurate success/failure result
    final result = await _repository.downloadAndSave(
      imageSource: imageSource,
      provider: provider,
    );

    if (result == DeviceImageSaveResult.success) {
      _setState(imageKey, ImageDownloadState.success);

      // Auto-reset to idle after 2 s so the user can download again if needed
      await Future.delayed(const Duration(seconds: 1));
      if (stateFor(imageKey) == ImageDownloadState.success) {
        _setState(imageKey, ImageDownloadState.idle);
      }
    } else {
      _failures[imageKey] = result;
      _setState(imageKey, ImageDownloadState.failed);

      // Auto-reset failed state to idle so the user can retry
      await Future.delayed(const Duration(seconds: 1));
      if (stateFor(imageKey) == ImageDownloadState.failed) {
        _failures.remove(imageKey);
        _setState(imageKey, ImageDownloadState.idle);
      }
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _setState(String key, ImageDownloadState state) {
    _states[key] = state;
    notifyListeners();
  }
}
