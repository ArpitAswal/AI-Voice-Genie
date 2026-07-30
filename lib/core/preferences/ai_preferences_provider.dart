import 'package:flutter/foundation.dart';

import '../enums/app_enums.dart';
import '../services/ai_preferences_service.dart';

/// Notifies the UI when AI defaults change.
///
/// This provider keeps the profile screen and chat composer in sync while
/// persisting every change to Hive through [AiPreferencesService].
class AiPreferencesProvider extends ChangeNotifier {
  AiPreferencesProvider({AiPreferencesService? service})
      : _service = service ?? AiPreferencesService.instance {
    _preferredProvider = _service.preferredProvider;
  }

  final AiPreferencesService _service;

  late AiProviderId _preferredProvider;

  AiProviderId get preferredProvider => _preferredProvider;
  ImageQuality get preferredImageQuality => _service.preferredImageQuality(_preferredProvider);
  AiImageSize get preferredImageSize => _service.preferredImageSize(_preferredProvider);
  int get preferredImageCount => _service.preferredImageCount(_preferredProvider);
  ImageGenerateBackground get preferredImageBackground =>
      _service.preferredImageBackground(_preferredProvider);

  int get preferredVisionImageCount => _service.preferredVisionImageCount(_preferredProvider);
  int get preferredVisionPdfCount => _service.preferredVisionPdfCount(_preferredProvider);
  VisionDetailLevel get preferredVisionDetailLevel =>
      _service.preferredVisionDetailLevel(_preferredProvider);
  ResponseLength get preferredResponseLength => _service.preferredResponseLength(_preferredProvider);

  Future<void> setPreferredProvider(AiProviderId provider) async {
    if (_preferredProvider == provider) return;
    _preferredProvider = provider;
    await _service.setPreferredProvider(provider);
    notifyListeners();
  }

  Future<void> setPreferredImageQuality(ImageQuality quality) async {
    if (preferredImageQuality == quality) return;
    await _service.setPreferredImageQuality(_preferredProvider, quality);
    notifyListeners();
  }

  Future<void> setPreferredImageSize(AiImageSize imageSize) async {
    if (preferredImageSize == imageSize) return;
    await _service.setPreferredImageSize(_preferredProvider, imageSize);
    notifyListeners();
  }

  Future<void> setPreferredImageBackground(
      ImageGenerateBackground background) async {
    if (preferredImageBackground == background) return;
    await _service.setPreferredImageBackground(_preferredProvider, background);
    notifyListeners();
  }

  Future<void> setPreferredVisionImageCount(int count) async {
    final clamped = count.clamp(1, 4).toInt();
    if (preferredVisionImageCount == clamped) return;
    await _service.setPreferredVisionImageCount(_preferredProvider, clamped);
    notifyListeners();
  }

  Future<void> setPreferredVisionPdfCount(int count) async {
    final clamped = count.clamp(1, 4).toInt();
    if (preferredVisionPdfCount == clamped) return;
    await _service.setPreferredVisionPdfCount(_preferredProvider, clamped);
    notifyListeners();
  }

  Future<void> setPreferredVisionDetailLevel(VisionDetailLevel level) async {
    if (preferredVisionDetailLevel == level) return;
    await _service.setPreferredVisionDetailLevel(_preferredProvider, level);
    notifyListeners();
  }

  Future<void> setPreferredResponseLength(ResponseLength length) async {
    if (preferredResponseLength == length) return;
    await _service.setPreferredResponseLength(_preferredProvider, length);
    notifyListeners();
  }

  Future<void> setPreferredImageCount(int count) async {
    final clamped = count.clamp(1, 10).toInt();
    if (preferredImageCount == clamped) return;
    await _service.setPreferredImageCount(_preferredProvider, clamped);
    notifyListeners();
  }
}
