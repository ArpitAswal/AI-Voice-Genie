import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_provider.dart';

enum ProfileLinkResult { opened, missing, failed }

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

  void _setSavingProfile(bool value) {
    if (_isSavingProfile == value) return;
    _isSavingProfile = value;
    notifyListeners();
  }
}
