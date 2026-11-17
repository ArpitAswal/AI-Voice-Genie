import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../extensions/build_context_extensions.dart';
import '../localization/app_localizations.dart';
import '../utils/status_message_utils.dart';
import '../widgets/app_alert_dialog.dart';

/// Production-grade helper to check and handle storage, media, camera, and gallery
/// permissions across Android, iOS, and desktop platforms.
///
/// Complete Lifecycle Behavior:
/// ─────────────────────────────────────────────────────────────────────────────
/// 1. "Always allow" / "While using the app":
///    - Status is [PermissionStatus.granted].
///    - Directly allows the operation (download or attach).
///    - Subsequent taps proceed without prompting.
///
/// 2. "Only this time" (Android 11+ / API 30+):
///    - Granted temporarily for the active app session.
///    - When expired, status reverts to [PermissionStatus.denied].
///    - Subsequent taps request permission again, redisplaying the system dialog.
///
/// 3. "Cancel" / "Don't allow" (one-time denial):
///    - Status is [PermissionStatus.denied].
///    - Displays a localized warning toast explaining why the permission is required.
///    - Does NOT open the Settings dialog prematurely.
///
/// 4. "Permanently denied" (checked "Don't ask again" on Android, or denied on iOS):
///    - Status is [PermissionStatus.permanentlyDenied].
///    - On subsequent taps, opens an [AppAlertDialog] explaining the requirement
///      with an "Open Settings" action button.
class StoragePermissionHelper {
  StoragePermissionHelper._();

  static const _channel = MethodChannel('com.voicegenie.app/image_save');

  // ── 1. Download Permissions (Generated Images & PDFs) ─────────────────────

  /// Checks and requests storage or media permission for downloading files.
  ///
  /// - Android 10+ (API 29+): Scoped storage via MediaStore writes to Pictures/
  ///   or Downloads/ without runtime permissions. Returns `true`.
  /// - Legacy Android (API <= 28): Prompts for [Permission.storage] (WRITE_EXTERNAL_STORAGE).
  /// - iOS Images: Prompts for [Permission.photos] to save into the camera roll.
  /// - iOS Documents: Sandboxed Documents folder requires no runtime permissions.
  static Future<bool> requestDownloadPermission(
    BuildContext context, {
    required bool isImage,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final l10n = context.l10n;

    // Android
    if (Platform.isAndroid) {
      final isScopedStorage = await _isAndroidScopedStorageSupported();
      if (isScopedStorage) {
        // Android 10+ (API 29+) Scoped Storage: MediaStore writes to Pictures/
        // and Downloads/ are managed via native ContentResolver without runtime permissions.
        return true;
      }

      if (!context.mounted) return false;

      // Legacy Android (API <= 28) requires WRITE_EXTERNAL_STORAGE to save files to public directories
      return await _handlePermissionFlow(
        context: context,
        permission: Permission.storage,
        warningMessage: l10n.storagePermissionRequired,
        permanentMessage: l10n.storagePermissionDeniedPermanent,
      );
    }

    // iOS
    if (Platform.isIOS) {
      if (!isImage) {
        // iOS sandboxed documents storage requires no runtime storage permission
        return true;
      }

      return await _handlePermissionFlow(
        context: context,
        permission: Permission.photos,
        warningMessage: l10n.storagePermissionRequired,
        permanentMessage: l10n.storagePermissionDeniedPermanent,
      );
    }

    return true;
  }

  // ── 2. Gallery / Photo Attachment Permission ──────────────────────────────

  /// Checks and requests permission to select images from the device gallery.
  ///
  /// - Android 13+ (API 33+): [Permission.photos] (READ_MEDIA_IMAGES).
  /// - Legacy Android (API <= 32): [Permission.storage] (READ_EXTERNAL_STORAGE).
  /// - iOS: [Permission.photos] (NSPhotoLibraryUsageDescription).
  static Future<bool> requestGalleryPermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final l10n = context.l10n;

    final Permission permission;
    if (Platform.isAndroid) {
      final sdk = await _getAndroidSdkVersion();
      permission = sdk >= 33 ? Permission.photos : Permission.storage;
    } else {
      permission = Permission.photos;
    }

    if (!context.mounted) return false;

    return await _handlePermissionFlow(
      context: context,
      permission: permission,
      warningMessage: l10n.galleryDeniedMessage,
      permanentMessage: l10n.galleryPermissionDeniedPermanent,
    );
  }

  // ── 3. Camera / Take Photo Permission ─────────────────────────────────────

  /// Checks and requests permission to capture photos with the device camera.
  ///
  /// - Both Android & iOS: [Permission.camera].
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final l10n = context.l10n;

    return await _handlePermissionFlow(
      context: context,
      permission: Permission.camera,
      warningMessage: l10n.cameraDeniedMessage,
      permanentMessage: l10n.cameraPermissionDeniedPermanent,
    );
  }

  // ── 4. Document / PDF Picker Permission ───────────────────────────────────

  /// Checks and requests permission to select documents (PDFs) from storage.
  ///
  /// - Android 13+ (API 33+) & iOS: System document pickers (SAF / UIDocumentPicker)
  ///   run in separate OS processes and do not require runtime permissions.
  /// - Legacy Android (API <= 32): Requires [Permission.storage] (READ_EXTERNAL_STORAGE).
  static Future<bool> requestDocumentPermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      final sdk = await _getAndroidSdkVersion();
      if (sdk >= 33) {
        return true;
      }

      if (!context.mounted) return false;

      final l10n = context.l10n;
      return await _handlePermissionFlow(
        context: context,
        permission: Permission.storage,
        warningMessage: l10n.filePermissionRequired,
        permanentMessage: l10n.filePermissionDeniedPermanent,
      );
    }

    return true;
  }

  // ── Core Permission Lifecycle Handler ──────────────────────────────────────

  /// Unified permission verification flow enforcing:
  /// - Immediate proceed if already granted or limited.
  /// - Dialog if permanently denied.
  /// - Native request if denied/first-time/one-time expired.
  /// - Warning toast on user cancel/denial.
  static Future<bool> _handlePermissionFlow({
    required BuildContext context,
    required Permission permission,
    required String warningMessage,
    required String permanentMessage,
  }) async {
    final l10n = context.l10n;

    // 1. Check current status
    final currentStatus = await permission.status;
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    // 2. If already permanently denied, don't attempt native request — show Settings dialog
    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await _showSettingsDialog(context, l10n, permanentMessage);
      }
      return false;
    }

    // 3. User is asking for the first time, or "Only this time" expired,
    // or previously pressed Cancel. Prompt the native OS permission sheet.
    final requestedStatus = await permission.request();

    if (!context.mounted) return false;

    // A. Granted or Limited (iOS limited photos / Android 14 visual user selected)
    if (requestedStatus.isGranted || requestedStatus.isLimited) {
      return true;
    }

    // B. User tapped "Cancel" / "Don't allow" (one-time denial) -> show warning toast
    if (requestedStatus.isDenied) {
      context.showWarningToast(warningMessage);
      return false;
    }

    // C. User checked "Don't ask again" on Android, or iOS permanent denial
    if (requestedStatus.isPermanentlyDenied) {
      await _showSettingsDialog(context, l10n, permanentMessage);
      return false;
    }

    // D. Restricted by parental control / MDM
    if (requestedStatus.isRestricted) {
      context.showWarningToast(warningMessage);
      return false;
    }

    return false;
  }

  // ── Android SDK Detection ──────────────────────────────────────────────────

  static Future<int> _getAndroidSdkVersion() async {
    try {
      final sdkInt = await _channel.invokeMethod<int>('getSdkVersion');
      if (sdkInt != null && sdkInt > 0) {
        return sdkInt;
      }
    } catch (_) {}

    try {
      final osVersion = Platform.operatingSystemVersion;
      final apiMatch =
          RegExp(r'API\s+(\d+)', caseSensitive: false).firstMatch(osVersion);
      if (apiMatch != null) {
        return int.tryParse(apiMatch.group(1) ?? '') ?? 34;
      }

      final verMatch = RegExp(r'Version\s+(\d+)', caseSensitive: false)
          .firstMatch(osVersion);
      if (verMatch != null) {
        final ver = int.tryParse(verMatch.group(1) ?? '') ?? 14;
        if (ver >= 14) return 34;
        if (ver == 13) return 33;
        if (ver == 12) return 31;
        if (ver == 11) return 30;
        if (ver == 10) return 29;
        return 28;
      }
    } catch (_) {}

    return 34;
  }

  static Future<bool> _isAndroidScopedStorageSupported() async {
    final sdk = await _getAndroidSdkVersion();
    return sdk >= 29;
  }

  // ── Settings Dialog ────────────────────────────────────────────────────────

  static Future<void> _showSettingsDialog(
    BuildContext context,
    AppLocalizations l10n,
    String message,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(l10n.permissionRequired),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: ctx.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await openAppSettings();
            },
            child: Text(
              l10n.openSettings,
              style: TextStyle(
                color: ctx.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
