import 'package:ai_voice_genie/core/error/effect_bus.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/app_enums.dart';
import '../../core/extensions/build_context_extensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/status_message_utils.dart';
import '../../features/image_download/presentation/image_download_provider.dart';

/// Reusable overlay download button for AI-generated images in chat.
///
/// Placement: top-right corner of each generated image tile.
///
/// States:
///   - Idle     → download icon
///   - Loading  → small circular progress indicator (only for this image)
///   - Success  → check icon for 2 seconds, then returns to idle
///   - Failed   → returns to idle, shows a localized snackbar/toast
///
/// Each image gets an independent [imageKey] so multiple images in the same
/// message can be saved simultaneously without interfering.
///
/// Accessibility: semantic label + tooltip + minimum 44×44 tap target.
class GeneratedImageDownloadButton extends StatelessWidget {
  /// Raw image source: HTTPS URL, data-URI, or local file path.
  final String imageSource;

  /// Unique key for this image: typically "{messageId}_{imageIndex}".
  final String imageKey;

  /// AI provider name for analytics (e.g. "openai", "gemini").
  final String provider;

  /// Total number of generated images in this message — for analytics only.
  final int imageCountInMessage;

  const GeneratedImageDownloadButton({
    super.key,
    required this.imageSource,
    required this.imageKey,
    required this.provider,
    required this.imageCountInMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageDownloadProvider>(
      builder: (context, downloadProvider, _) {
        final state = downloadProvider.stateFor(imageKey);
        return Positioned(
          top: 4,
          right: 4,
          child: _DownloadButtonCore(
            state: state,
            onTap: state == ImageDownloadState.loading
                ? null
                : () => _onTap(context, downloadProvider),
          ),
        );
      },
    );
  }

  Future<void> _onTap(
    BuildContext context,
    ImageDownloadProvider downloadProvider,
  ) async {
    // Detect source type for analytics before download starts (source string is safe)
    final sourceType = _detectSourceType(imageSource);

    await downloadProvider.downloadImage(
      imageSource: imageSource,
      imageKey: imageKey,
      provider: provider,
    );

    // Read result after awaiting — use the state that the provider has settled into
    final finalState = downloadProvider.stateFor(imageKey);
    final failure = downloadProvider.failureFor(imageKey);

    // Guard: avoid showing UI if the widget was disposed while downloading
    if (!context.mounted) return;

    if (finalState == ImageDownloadState.success ||
        finalState == ImageDownloadState.idle && failure == null) {
      // Success toast
      final path = Platform.isIOS ? 'Photos' : 'Pictures/AI Voice Genie';
      context.showSuccessToast(context.l10n.imageSaved(path));
    } else if (failure != null) {
      // Failure toast with a specific message per failure reason
      final message = _failureMessage(context, failure);
      context.showErrorToast(message);
    }

    // Analytics: fire-and-forget after result is known.
    // Parameters are safe — no URL, prompt text, or user ID.
    final isSuccess = failure == null;
    // Read failure once to avoid repeated null checks — guaranteed non-null in failure branch.
    final failureValue = failure;
    EffectBus.instance.safeEffect(() async {
      AnalyticsService.instance.logImageDownload(
        provider: provider,
        result: isSuccess ? 'success' : 'failure',
        failureReason: failureValue != null ? _failureReason(failureValue) : '',
        mimeType: _guessMimeType(imageSource),
        sourceType: sourceType,
        imageCountInMessage: imageCountInMessage,
      );
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _detectSourceType(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return 'remote_url';
    }
    if (source.startsWith('data:image')) return 'data_uri';
    return 'local_file';
  }

  /// Maps a [DeviceImageSaveResult] failure to a localized user message.
  String _failureMessage(BuildContext context, DeviceImageSaveResult failure) {
    switch (failure) {
      case DeviceImageSaveResult.permissionDenied:
        return context.l10n.imageSavePermissionDenied;
      case DeviceImageSaveResult.noSpace:
        return context.l10n.imageSaveNoSpace;
      case DeviceImageSaveResult.networkFailure:
      case DeviceImageSaveResult.invalidImage:
        return context.l10n.imageDownloadFailed;
      default:
        return context.l10n.imageSaveFailed;
    }
  }

  String _failureReason(DeviceImageSaveResult failure) {
    switch (failure) {
      case DeviceImageSaveResult.permissionDenied:
        return 'permission_denied';
      case DeviceImageSaveResult.networkFailure:
        return 'network';
      case DeviceImageSaveResult.invalidImage:
        return 'invalid_image';
      case DeviceImageSaveResult.noSpace:
        return 'no_space';
      default:
        return 'unknown';
    }
  }

  String _guessMimeType(String source) {
    if (source.startsWith('data:image/')) {
      final end = source.indexOf(';');
      if (end > 11) return source.substring(5, end);
    }
    if (source.contains('.png')) return 'image/png';
    if (source.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

/// Private stateless core widget for the button icon + state rendering.
///
/// Extracted so the [Consumer] rebuild only repaints this small widget,
/// not the entire image stack.
class _DownloadButtonCore extends StatelessWidget {
  final ImageDownloadState state;
  final VoidCallback? onTap;

  const _DownloadButtonCore({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // Semi-transparent surface so the button is readable on any image background
    final bg = isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight;

    final iconColor = isDark ? AppColors.white : context.primaryColor;

    Widget icon;
    switch (state) {
      case ImageDownloadState.loading:
        // Small spinner — only for this specific image
        icon = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: iconColor,
          ),
        );
        break;

      case ImageDownloadState.success:
        // Temporary check icon after successful save
        icon = Icon(Icons.check_rounded,
            color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
            size: 20);
        break;

      default:
        // Idle and failed both show the download icon
        icon = Icon(Icons.download_rounded, color: iconColor, size: 20);
    }

    return Tooltip(
      message: 'Download image',
      child: Semantics(
        label: 'Download generated image',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            // Minimum 44×44 tap target for accessibility compliance
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
