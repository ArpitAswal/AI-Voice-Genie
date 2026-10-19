import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_provider.dart';

enum ProfileLinkResult { opened, copied, missing, failed }

class ProfileViewModel extends ChangeNotifier {
  bool _isSavingProfile = false;
  String? _errorMessage;
  String _versionLabel = AppConstants.appVersion;

  bool get isSavingProfile => _isSavingProfile;
  String? get errorMessage => _errorMessage;
  String get versionLabel => _versionLabel;

  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> signOut(AuthProvider authProvider) async {
    _errorMessage = null;
    try {
      final success = await authProvider.signOut();
      if (!success) {
        _errorMessage = authProvider.authError ?? 'sign_out_failed';
        return false;
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.code;
      return false;
    } catch (e) {
      _errorMessage = 'sign_out_failed';
      return false;
    }
  }

  Future<bool> deleteAccount(AuthProvider authProvider) async {
    _errorMessage = null;
    try {
      final success = await authProvider.deleteAccount();
      if (!success) {
        _errorMessage = authProvider.authError ?? 'delete_account_failed';
        notifyListeners();
        return false;
      }
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'delete_account_failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required AuthProvider authProvider,
    required String displayName,
    required String photoUrl,
    required String email,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? country,
    String? state,
    File? photoFile,
  }) async {
    _setSavingProfile(true);
    _errorMessage = null;
    try {
      final success = await authProvider.updateProfile(
        displayName: displayName,
        photoUrl: photoUrl,
        email: email,
        dateOfBirth: dateOfBirth,
        age: age,
        gender: gender,
        country: country,
        state: state,
        photoFile: photoFile,
      );
      if (!success) {
        _errorMessage = authProvider.authError ?? 'profile_update_failed';
        notifyListeners();
      }
      return success;
    } on AuthException catch (e) {
      _errorMessage = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'profile_update_failed';
      notifyListeners();
      return false;
    } finally {
      _setSavingProfile(false);
    }
  }

  Future<void> loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _versionLabel = '${info.version} + ${info.buildNumber}';
    } catch (_) {
      _versionLabel = AppConstants.appVersion;
    }
    notifyListeners();
  }

  Future<ProfileLinkResult> openUrl(String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return ProfileLinkResult.missing;

    final uri = Uri.tryParse(trimmedValue);
    if (uri == null) return ProfileLinkResult.failed;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return opened ? ProfileLinkResult.opened : ProfileLinkResult.failed;
  }

  Future<ProfileLinkResult> openSupport([String? subject, String? body]) async {
    if (AppConstants.helpCenterUrl.trim().isNotEmpty) {
      return openUrl(AppConstants.helpCenterUrl);
    }

    final email = AppConstants.supportEmail.trim();
    if (email.isEmpty) {
      return ProfileLinkResult.missing;
    }

    final effectiveSubject = (subject != null && subject.trim().isNotEmpty)
        ? subject.trim()
        : '${AppConstants.copyrightOwner} Support & Feedback';

    final effectiveBody = (body != null && body.trim().isNotEmpty)
        ? body.trim()
        : 'Dear Support Team,\n\n'
            '[Please describe your question, issue, or feedback here]\n\n'
            '---\n'
            'App: ${AppConstants.copyrightOwner} (v${_versionLabel.isNotEmpty ? _versionLabel : AppConstants.appVersion})\n'
            'Support Email: $email\n'
            'Platform: ${Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : Platform.operatingSystem}';

    // Helper: RFC 3986 percent-encoding (%20 instead of +) for mailto parameters
    String encodeMailQuery(Map<String, String> params) {
      return params.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.trim())}')
          .join('&');
    }

    // 1. Primary: Standard mailto: URI with RFC 3986 query encoding
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: email,
      query: encodeMailQuery({
        'subject': effectiveSubject,
        'body': effectiveBody,
      }),
    );

    // Attempt standard mailto with LaunchMode.platformDefault
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) return ProfileLinkResult.opened;
    } catch (e) {
      debugPrint(
          '⚠️ ProfileViewModel.openSupport platformDefault mailto error: $e');
    }

    // Attempt standard mailto with LaunchMode.externalApplication
    try {
      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return ProfileLinkResult.opened;
    } catch (e) {
      debugPrint(
          '⚠️ ProfileViewModel.openSupport externalApplication mailto error: $e');
    }

    // Fallback 1b: Concise mailto without long body (bypasses URL length limits on some mail handlers)
    final conciseMailtoUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(effectiveSubject)}',
    );
    try {
      if (await launchUrl(conciseMailtoUri, mode: LaunchMode.platformDefault)) {
        return ProfileLinkResult.opened;
      }
    } catch (_) {}

    // Fallback 1c: Bare mailto URI
    final bareMailtoUri = Uri(scheme: 'mailto', path: email);
    try {
      if (await launchUrl(bareMailtoUri, mode: LaunchMode.platformDefault)) {
        return ProfileLinkResult.opened;
      }
    } catch (_) {}

    // 2. iOS-specific alternate mail clients (Gmail, Outlook, Yahoo Mail, Spark)
    // Critical when Apple Mail app has no account configured or is uninstalled
    if (Platform.isIOS) {
      final encodedSubject = Uri.encodeComponent(effectiveSubject);
      final encodedBody = Uri.encodeComponent(effectiveBody);
      final alternateUris = [
        Uri.parse(
            'googlegmail:///co?to=$email&subject=$encodedSubject&body=$encodedBody'),
        Uri.parse('googlegmail:///co?to=$email'),
        Uri.parse(
            'ms-outlook://compose?to=$email&subject=$encodedSubject&body=$encodedBody'),
        Uri.parse('ms-outlook://compose?to=$email'),
        Uri.parse(
            'ymail://mail/compose?to=$email&subject=$encodedSubject&body=$encodedBody'),
        Uri.parse(
            'readdle-spark://compose?recipient=$email&subject=$encodedSubject&body=$encodedBody'),
      ];

      for (final altUri in alternateUris) {
        try {
          if (await canLaunchUrl(altUri)) {
            final launched = await launchUrl(
              altUri,
              mode: LaunchMode.externalApplication,
            );
            if (launched) return ProfileLinkResult.opened;
          }
        } catch (_) {}
      }
    }

    // 3. Webmail Compose Fallback (Browser-based Gmail compose)
    // Guarantees mail composition section opens even on simulators or devices with no local email app
    final webGmailUri = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1&to=$email'
      '&su=${Uri.encodeComponent(effectiveSubject)}'
      '&body=${Uri.encodeComponent(effectiveBody)}',
    );
    try {
      final launched = await launchUrl(
        webGmailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return ProfileLinkResult.opened;
    } catch (e) {
      debugPrint('⚠️ ProfileViewModel.openSupport webmail fallback error: $e');
    }

    // 4. Last safety resort: Copy email to clipboard so user is never stranded
    try {
      await Clipboard.setData(ClipboardData(text: email));
      return ProfileLinkResult.copied;
    } catch (e) {
      debugPrint(
          '⚠️ ProfileViewModel.openSupport clipboard fallback error: $e');
      return ProfileLinkResult.failed;
    }
  }

  void _setSavingProfile(bool value) {
    if (_isSavingProfile == value) return;
    _isSavingProfile = value;
    notifyListeners();
  }
}
