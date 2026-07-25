import 'package:encrypt/encrypt.dart';

import '../constants/app_constants.dart';

/// A simple, fast encryption service for securing sensitive data at rest
/// before saving to Firestore.
///
/// Uses AES-256-CBC with a key loaded from secrets.json (via AppConstants)
/// and a random IV per payload so every ciphertext is unique.
///
/// IMPORTANT: AppConstants.loadSecrets() must be called once before this
/// service is first used (typically in main.dart before runApp).
class EncryptionService {
  EncryptionService._();

  /// Guarantees a valid 32-byte (256-bit) key for AES-256 from [AppConstants.encryptionKey].
  /// If no key was injected via --dart-define (e.g., during unit tests or unconfigured
  /// dev runs), we use a zeroed-out 32-byte key so encryption never throws an error.
  /// Any injected key from secrets.json is automatically padded or truncated to 32 characters.
  static Key get _key {
    var keyString = AppConstants.encryptionKey;
    if (keyString.isEmpty) {
      return Key.fromUtf8('00000000000000000000000000000000');
    }
    if (keyString.length < 32) {
      keyString = keyString.padRight(32, '0');
    } else if (keyString.length > 32) {
      keyString = keyString.substring(0, 32);
    }
    return Key.fromUtf8(keyString);
  }

  /// Builds the Encrypter on first use, using the normalized 256-bit key.
  static Encrypter get _encrypter => Encrypter(AES(_key, mode: AESMode.cbc));

  /// Encrypts plain text into a base64 encoded string containing the IV and ciphertext.
  /// Format: Base64(IV) + ':' + Base64(Ciphertext)
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;

    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts the formatted string back into plain text.
  /// Expects the format: Base64(IV) + ':' + Base64(Ciphertext)
  static String decrypt(String encryptedData) {
    if (encryptedData.isEmpty || !encryptedData.contains(':')) {
      // Fallback: data was stored before encryption was introduced
      return encryptedData;
    }

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return encryptedData;

      final iv = IV.fromBase64(parts[0]);
      final cipherText = parts[1];

      return _encrypter.decrypt64(cipherText, iv: iv);
    } catch (e) {
      // If decryption fails, return original string (may be plain text legacy data)
      return encryptedData;
    }
  }
}
