import 'package:flutter/foundation.dart';

import '../enums/app_enums.dart';
import '../services/ai_preferences_service.dart';
import '../../ai_layer/models/ai_request.dart';

/// Notifies the UI when AI defaults change.
///
/// This provider keeps the profile screen and chat composer in sync while
/// persisting every change to Hive through [AiPreferencesService].
class AiPreferencesProvider extends ChangeNotifier {
  AiPreferencesProvider({AiPreferencesService? service})
      : _service = service ?? AiPreferencesService.instance {
    _preferredProvider = _service.preferredProvider;
    _preferredImageQuality = _service.preferredImageQuality;
    _preferredImageSize = _service.preferredImageSize;
    _preferredImageCount = _service.preferredImageCount;
  }

  final AiPreferencesService _service;

  AiProviderId _preferredProvider = AiProviderId.gemini;
  ImageQuality _preferredImageQuality = ImageQuality.Low;
  AiImageSize _preferredImageSize = AiImageSize.square;
  int _preferredImageCount = 1;

  AiProviderId get preferredProvider => _preferredProvider;
  ImageQuality get preferredImageQuality => _preferredImageQuality;
  AiImageSize get preferredImageSize => _preferredImageSize;
  int get preferredImageCount => _preferredImageCount;

  Future<void> setPreferredProvider(AiProviderId provider) async {
    if (_preferredProvider == provider) return;
    _preferredProvider = provider;
    await _service.setPreferredProvider(provider);
    notifyListeners();
  }

  Future<void> setPreferredImageQuality(ImageQuality quality) async {
    if (_preferredImageQuality == quality) return;
    _preferredImageQuality = quality;
    await _service.setPreferredImageQuality(quality);
    notifyListeners();
  }

  Future<void> setPreferredImageSize(AiImageSize imageSize) async {
    if (_preferredImageSize == imageSize) return;
    _preferredImageSize = imageSize;
    await _service.setPreferredImageSize(imageSize);
    notifyListeners();
  }

  Future<void> setPreferredImageCount(int count) async {
    final clamped = count.clamp(1, 10).toInt();
    if (_preferredImageCount == clamped) return;
    _preferredImageCount = clamped;
    await _service.setPreferredImageCount(clamped);
    notifyListeners();
  }
}
