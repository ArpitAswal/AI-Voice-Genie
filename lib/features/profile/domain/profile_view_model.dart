import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';

enum ProfileLinkResult { opened, missing, failed }

class ProfileViewModel extends ChangeNotifier {
  bool _isSigningOut = false;
  bool _isSavingProfile = false;
  String _versionLabel = AppConstants.appVersion;

  bool get isSigningOut => _isSigningOut;
  bool get isSavingProfile => _isSavingProfile;
  String get versionLabel => _versionLabel;

  Future<void> loadApiKeys({
    required AuthProvider authProvider,
    required ApiKeyProvider apiKeyProvider,
  }) async {
    final uid = authProvider.currentUser?.uid;
    if (uid == null) return;

    await apiKeyProvider.loadExistingKeys(uid);
  }

  Future<bool> signOut(AuthProvider authProvider) async {
    _setSigningOut(true);
    try {
      await authProvider.signOut();
      return true;
    } finally {
      _setSigningOut(false);
    }
  }

  Future<bool> updateProfile({
    required AuthProvider authProvider,
    required String displayName,
    required String photoUrl,
    DateTime? dateOfBirth,
    int? age,
    String? preferredAiModel,
    File? photoFile,
  }) async {
    _setSavingProfile(true);
    try {
      return authProvider.updateProfile(
        displayName: displayName,
        photoUrl: photoUrl,
        dateOfBirth: dateOfBirth,
        age: age,
        preferredAiModel: preferredAiModel,
        photoFile: photoFile,
      );
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

  Future<ProfileLinkResult> openSupport(String subject) async {
    if (AppConstants.helpCenterUrl.trim().isNotEmpty) {
      return openUrl(AppConstants.helpCenterUrl);
    }

    if (AppConstants.supportEmail.trim().isEmpty) {
      return ProfileLinkResult.missing;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail.trim(),
      queryParameters: {'subject': subject},
    );
    final opened = await launchUrl(uri);
    return opened ? ProfileLinkResult.opened : ProfileLinkResult.failed;
  }

  void _setSigningOut(bool value) {
    if (_isSigningOut == value) return;
    _isSigningOut = value;
    notifyListeners();
  }

  void _setSavingProfile(bool value) {
    if (_isSavingProfile == value) return;
    _isSavingProfile = value;
    notifyListeners();
  }
}
