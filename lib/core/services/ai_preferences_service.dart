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

  AiProviderId get preferredProvider {
    final saved = _storage.getString(StorageKeys.preferredProviderId);
    return _providerFromId(saved) ?? AiProviderId.gemini;
  }

  ImageQuality get preferredImageQuality {
    final saved = _storage.getString(StorageKeys.preferredImageQuality);
    return saved == null ? ImageQuality.low : ImageQuality.fromValue(saved);
  }

  AiImageSize get preferredImageSize {
    final saved = _storage.getString(StorageKeys.preferredImageSize);
    return saved == null ? AiImageSize.square : AiImageSize.fromValue(saved);
  }

  int get preferredImageCount {
    final count =
        _storage.getInt(StorageKeys.preferredImageCount, defaultValue: 1);
    return count.clamp(1, 10).toInt();
  }

  Future<void> setPreferredProvider(AiProviderId provider) async {
    await _storage.setString(StorageKeys.preferredProviderId, provider.id);
  }

  Future<void> setPreferredImageQuality(ImageQuality quality) async {
    await _storage.setString(StorageKeys.preferredImageQuality, quality.value);
  }

  Future<void> setPreferredImageSize(AiImageSize imageSize) async {
    // Write imageSize.name (e.g. 'square', 'landscape', 'portrait') as a string since Hive expects a String
    await _storage.setString(StorageKeys.preferredImageSize, imageSize.name);
  }

  Future<void> setPreferredImageCount(int count) async {
    await _storage.setInt(
      StorageKeys.preferredImageCount,
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
