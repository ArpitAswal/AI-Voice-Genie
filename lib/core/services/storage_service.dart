import 'package:hive_flutter/hive_flutter.dart';

/// Local storage service wrapping Hive.
///
/// Single access point for all local key-value storage.
/// Must be initialized once at app startup before any reads/writes.
///
/// Usage:
/// ```dart
/// await StorageService().initialize(); // in main()
/// StorageService().setString(StorageKeys.themeMode, 'dark');
/// StorageService().getString(StorageKeys.themeMode); // → 'dark'
/// ```
class StorageService {
  // Singleton pattern — same instance throughout the app
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Hive box references — opened once, reused throughout the app lifecycle
  late Box _settingsBox;
  late Box _userBox;
  late Box _conversationCacheBox;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Initialize Hive and open all required boxes.
  ///
  /// Must be called in main() before runApp().
  Future<void> initialize() async {
    // Initialize Hive with Flutter path provider
    await Hive.initFlutter();

    // Open all boxes in parallel for faster startup
    await Future.wait([
      Hive.openBox('settings_box').then((box) => _settingsBox = box),
      Hive.openBox('user_box').then((box) => _userBox = box),
      Hive.openBox('conversation_cache_box').then((box) => _conversationCacheBox = box),
    ]);
  }

  // ── Settings Box Operations ───────────────────────────────────────────────

  /// Get a string value from settings box
  String? getString(String key) {
    return _settingsBox.get(key) as String?;
  }

  /// Save a string value to settings box
  Future<void> setString(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  /// Get a boolean value from settings box
  bool getBool(String key, {bool defaultValue = false}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as bool;
  }

  /// Save a boolean value to settings box
  Future<void> setBool(String key, bool value) async {
    await _settingsBox.put(key, value);
  }

  /// Get an integer value from settings box
  int getInt(String key, {int defaultValue = 0}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as int;
  }

  /// Save an integer value to settings box
  Future<void> setInt(String key, int value) async {
    await _settingsBox.put(key, value);
  }

  /// Get a double value from settings box
  double getDouble(String key, {double defaultValue = 0.0}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as double;
  }

  /// Save a double value to settings box
  Future<void> setDouble(String key, double value) async {
    await _settingsBox.put(key, value);
  }

  /// Remove a key from settings box
  Future<void> remove(String key) async {
    await _settingsBox.delete(key);
  }

  /// Check if a key exists in settings box
  bool containsKey(String key) {
    return _settingsBox.containsKey(key);
  }

  // ── User Box Operations ───────────────────────────────────────────────────

  /// Save user profile data to user box
  Future<void> setUserData(String key, dynamic value) async {
    await _userBox.put(key, value);
  }

  /// Get user profile data from user box
  T? getUserData<T>(String key) {
    return _userBox.get(key) as T?;
  }

  /// Clear all user data (called on logout)
  Future<void> clearUserData() async {
    await _userBox.clear();
  }

  // ── Conversation Cache Box Operations ─────────────────────────────────────

  /// Cache a value related to the active conversation
  Future<void> setConversationCache(String key, dynamic value) async {
    await _conversationCacheBox.put(key, value);
  }

  /// Read a value from the conversation cache
  T? getConversationCache<T>(String key) {
    return _conversationCacheBox.get(key) as T?;
  }

  /// Clear the conversation cache (called when user starts a new conversation)
  Future<void> clearConversationCache() async {
    await _conversationCacheBox.clear();
  }

  /// Remove a single conversation's cached messages by key.
  ///
  /// Use this on conversation delete to avoid wiping all cached conversations.
  Future<void> removeConversationCache(String key) async {
    await _conversationCacheBox.delete(key);
  }

  // ── Full Clear ────────────────────────────────────────────────────────────

  /// Clear all local storage (called on full logout or account deletion)
  Future<void> clearAll() async {
    await Future.wait([
      _settingsBox.clear(),
      _userBox.clear(),
      _conversationCacheBox.clear(),
    ]);
  }
}