import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure storage service wrapping flutter_secure_storage.
///
/// Used for sensitive session data (not API keys — those go to Firestore).
/// On iOS: uses Keychain. On Android: uses Keystore-backed EncryptedSharedPreferences.
///
/// Usage:
/// ```dart
/// await SecureStorageService.instance.write('session_token', value);
/// final token = await SecureStorageService.instance.read('session_token');
/// ```
class SecureStorageService {
  // Singleton
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  // Android-specific: use EncryptedSharedPreferences for maximum security
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Write a value securely
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('⚠️ SecureStorage write failed [$key]: $e');
    }
  }

  /// Read a value securely — returns null if key does not exist
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('⚠️ SecureStorage read failed [$key]: $e');
      return null;
    }
  }

  /// Delete a specific key
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('⚠️ SecureStorage delete failed [$key]: $e');
    }
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('⚠️ SecureStorage containsKey failed [$key]: $e');
      return false;
    }
  }

  /// Delete all secure storage keys (called on full logout)
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('⚠️ SecureStorage deleteAll failed: $e');
    }
  }
}