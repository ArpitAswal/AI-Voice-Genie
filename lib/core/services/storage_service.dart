import 'package:hive_flutter/hive_flutter.dart';

import '../constants/storage_keys.dart';
import '../../features/chat/data/chat_outbox_store.dart';
import '../../features/chat/data/chat_sync_service.dart';
import '../../features/chat/data/local_chat_store.dart';

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

  // New offline-first chat boxes (replacing the old single JSON-blob cache)
  late Box
      _chatConversationsBox; // per-conversation metadata, keyed {uid}_{conversationId}
  late Box
      _chatMessagesBox; // per-message records, keyed {uid}_{conversationId}_{messageId}
  late Box _chatOutboxBox; // durable outbox tasks for background Firestore sync
  late Box _chatSyncStateBox; // per-user sync timestamps and delete-all cutoff

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
      // Legacy JSON-blob cache — kept for backward compatibility during migration
      Hive.openBox('conversation_cache_box')
          .then((box) => _conversationCacheBox = box),
      // New offline-first boxes
      Hive.openBox('chat_conversations_box')
          .then((box) => _chatConversationsBox = box),
      Hive.openBox('chat_messages_box').then((box) => _chatMessagesBox = box),
      Hive.openBox('chat_outbox_box').then((box) => _chatOutboxBox = box),
      Hive.openBox('chat_sync_state_box')
          .then((box) => _chatSyncStateBox = box),
    ]);

    // Wire the store singletons with their respective Hive boxes.
    // These singletons are used throughout the chat layer without rebuilding.
    LocalChatStore.instance.init(_chatConversationsBox, _chatMessagesBox);
    ChatOutboxStore.instance.init(_chatOutboxBox);
    ChatSyncService.instance.initBox(_chatSyncStateBox);
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
    await _conversationCacheBox.clear();

    // Clear user-specific AI preferences and session settings from settings box
    // so they do not bleed over if a different user logs in.
    final keysToRemove = [
      StorageKeys.preferredProviderId,
      StorageKeys.preferredImageQuality,
      StorageKeys.preferredImageSize,
      StorageKeys.preferredImageCount,
      StorageKeys.preferredVisionImageCount,
      StorageKeys.preferredVisionPdfCount,
      StorageKeys.preferredVisionDetailLevel,
      StorageKeys.preferredResponseLength,
      StorageKeys.lastOpenConversationId,
      StorageKeys.useAiTts,
      StorageKeys.useAiStt,
      StorageKeys.ttsSpeed,
    ];

    for (final key in keysToRemove) {
      await _settingsBox.delete(key);
    }
  }

  /// Clear all offline-first Hive chat data for a specific user.
  ///
  /// Called on logout BEFORE starting the next user session.
  /// Uses the uid prefix to selectively remove only this user's records,
  /// which is critical for multi-user / same-device correctness.
  Future<void> clearChatBoxes(String uid) async {
    // Delegate to LocalChatStore which manages the prefix-keyed boxes
    await LocalChatStore.instance.clearAllForUser(uid);
    // Clear outbox tasks queued for this user
    await ChatOutboxStore.instance.clearForUser(uid);
    // Clear the user's sync state (lastSyncAt, deleteAllCutoff, etc.)
    await _chatSyncStateBox.delete(uid);
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
