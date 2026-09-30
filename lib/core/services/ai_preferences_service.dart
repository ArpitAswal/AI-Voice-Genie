import '../constants/storage_keys.dart';
import '../enums/app_enums.dart';
import 'storage_service.dart';

/// Local preference access for AI-related defaults.
///
/// Keeps the persisted values in one place so chat screens, profile settings,
/// and AI request builders all read the same source of truth.
class AiPreferencesService {
  static final AiPreferencesService instance = AiPreferencesService._();

  AiPreferencesService._();

  final StorageService _storage = StorageService();

  bool get autoTextToSpeech {
    return _storage.getBool(StorageKeys.autoTextToSpeech, defaultValue: false);
  }

  Future<void> setAutoTextToSpeech(bool value) async {
    await _storage.setBool(StorageKeys.autoTextToSpeech, value);
  }

  AiProviderId get preferredProvider {
    final saved = _storage.getString(StorageKeys.preferredProviderId);
    return _providerFromId(saved) ?? AiProviderId.gemini;
  }

  ImageQuality preferredImageQuality(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageQuality, provider.id);
    final saved = _storage.getString(key);
    return saved == null ? ImageQuality.low : ImageQuality.fromValue(saved);
  }

  AiImageSize preferredImageSize(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageSize, provider.id);
    final saved = _storage.getString(key);
    return saved == null ? AiImageSize.square : AiImageSize.fromValue(saved);
  }

  ImageGenerateBackground preferredImageBackground(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageBackground, provider.id);
    final saved = _storage.getString(key);
    return saved == null
        ? ImageGenerateBackground.auto
        : ImageGenerateBackground.fromString(saved);
  }

  int preferredVisionImageCount(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionImageCount, provider.id);
    final count = _storage.getInt(key, defaultValue: 1);
    return count.clamp(1, 4).toInt();
  }

  int preferredVisionPdfCount(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionPdfCount, provider.id);
    final count = _storage.getInt(key, defaultValue: 1);
    return count.clamp(1, 4).toInt();
  }

  VisionDetailLevel preferredVisionDetailLevel(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionDetailLevel, provider.id);
    final saved = _storage.getString(key);
    return saved == null
        ? VisionDetailLevel.auto
        : VisionDetailLevel.fromValue(saved);
  }

  ResponseLength preferredResponseLength(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredResponseLength, provider.id);
    final name = _storage.getString(key);
    return name == null
        ? ResponseLength.balanced
        : ResponseLength.fromName(name);
  }

  GeminiThinkingLevel preferredGeminiThinkingLevel(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredGeminiThinkingLevel, provider.id);
    final saved = _storage.getString(key);
    return GeminiThinkingLevel.fromString(saved);
  }

  GeminiAspectRatio preferredGeminiAspectRatio(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredGeminiAspectRatio, provider.id);
    final saved = _storage.getString(key);
    return saved == null
        ? GeminiAspectRatio.square
        : GeminiAspectRatio.fromValue(saved);
  }

  int preferredImageCount(AiProviderId provider) {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageCount, provider.id);
    final count = _storage.getInt(key, defaultValue: 1);
    return count.clamp(1, 10).toInt();
  }

  Future<void> setPreferredProvider(AiProviderId provider) async {
    await _storage.setString(StorageKeys.preferredProviderId, provider.id);
  }

  Future<void> setPreferredImageQuality(
      AiProviderId provider, ImageQuality quality) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageQuality, provider.id);
    await _storage.setString(key, quality.value);
  }

  Future<void> setPreferredImageSize(
      AiProviderId provider, AiImageSize imageSize) async {
    // Write imageSize.name (e.g. 'square', 'landscape', 'portrait') as a string since Hive expects a String
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageSize, provider.id);
    await _storage.setString(key, imageSize.name);
  }

  Future<void> setPreferredImageBackground(
      AiProviderId provider, ImageGenerateBackground background) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageBackground, provider.id);
    await _storage.setString(key, background.name);
  }

  Future<void> setPreferredVisionImageCount(
      AiProviderId provider, int count) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionImageCount, provider.id);
    await _storage.setInt(
      key,
      count.clamp(1, 4).toInt(),
    );
  }

  Future<void> setPreferredVisionPdfCount(
      AiProviderId provider, int count) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionPdfCount, provider.id);
    await _storage.setInt(
      key,
      count.clamp(1, 4).toInt(),
    );
  }

  Future<void> setPreferredVisionDetailLevel(
      AiProviderId provider, VisionDetailLevel level) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredVisionDetailLevel, provider.id);
    await _storage.setString(
      key,
      level.apiValue,
    );
  }

  Future<void> setPreferredResponseLength(
      AiProviderId provider, ResponseLength length) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredResponseLength, provider.id);
    await _storage.setString(key, length.name);
  }

  Future<void> setPreferredGeminiThinkingLevel(
      AiProviderId provider, GeminiThinkingLevel level) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredGeminiThinkingLevel, provider.id);
    await _storage.setString(key, level.apiValue);
  }

  Future<void> setPreferredGeminiAspectRatio(
      AiProviderId provider, GeminiAspectRatio ratio) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredGeminiAspectRatio, provider.id);
    await _storage.setString(key, ratio.apiValue);
  }

  Future<void> setPreferredImageCount(AiProviderId provider, int count) async {
    final key = StorageKeys.providerPrefKey(
        StorageKeys.preferredImageCount, provider.id);
    await _storage.setInt(
      key,
      count.clamp(1, 10).toInt(),
    );
  }

  AiProviderId? _providerFromId(String? providerId) {
    if (providerId == null || providerId.isEmpty) return null;
    for (final provider in AiProviderId.values) {
      if (provider.id == providerId) return provider;
    }
    return null;
  }
}
