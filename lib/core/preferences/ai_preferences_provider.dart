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
    _preferredImageQuality = _service.preferredImageQuality;
    _preferredImageSize = _service.preferredImageSize;
    _preferredVisionImageCount = _service.preferredVisionImageCount;
    _preferredVisionPdfCount = _service.preferredVisionPdfCount;
    _preferredVisionDetailLevel = _service.preferredVisionDetailLevel;
    _preferredResponseLength = _service.preferredResponseLength;
    _preferredImageCount = _service.preferredImageCount;
  }

  final AiPreferencesService _service;

  AiProviderId _preferredProvider = AiProviderId.gemini;
  ImageQuality _preferredImageQuality = ImageQuality.low;
  AiImageSize _preferredImageSize = AiImageSize.square;
  int _preferredImageCount = 1;

  AiProviderId get preferredProvider => _preferredProvider;
  ImageQuality get preferredImageQuality => _preferredImageQuality;
  AiImageSize get preferredImageSize => _preferredImageSize;
  int get preferredImageCount => _preferredImageCount;

  int _preferredVisionImageCount = 1;
  int _preferredVisionPdfCount = 1;
  VisionDetailLevel _preferredVisionDetailLevel = VisionDetailLevel.auto;
  ResponseLength _preferredResponseLength = ResponseLength.balanced;

  int get preferredVisionImageCount => _preferredVisionImageCount;
  int get preferredVisionPdfCount => _preferredVisionPdfCount;
  VisionDetailLevel get preferredVisionDetailLevel => _preferredVisionDetailLevel;
  ResponseLength get preferredResponseLength => _preferredResponseLength;


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

  Future<void> setPreferredVisionImageCount(int count) async {
    final clamped = count.clamp(1, 4).toInt();
    if (_preferredVisionImageCount == clamped) return;
    _preferredVisionImageCount = clamped;
    await _service.setPreferredVisionImageCount(clamped);
    notifyListeners();
  }

  Future<void> setPreferredVisionPdfCount(int count) async {
    final clamped = count.clamp(1, 4).toInt();
    if (_preferredVisionPdfCount == clamped) return;
    _preferredVisionPdfCount = clamped;
    await _service.setPreferredVisionPdfCount(clamped);
    notifyListeners();
  }

  Future<void> setPreferredVisionDetailLevel(VisionDetailLevel level) async {
    if (_preferredVisionDetailLevel == level) return;
    _preferredVisionDetailLevel = level;
    await _service.setPreferredVisionDetailLevel(level);
    notifyListeners();
  }

  Future<void> setPreferredResponseLength(ResponseLength length) async {
    if (_preferredResponseLength == length) return;
    _preferredResponseLength = length;
    await _service.setPreferredResponseLength(length);
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
