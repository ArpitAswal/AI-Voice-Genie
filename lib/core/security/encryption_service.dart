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

  /// Builds the Encrypter on first use, using the key from AppConstants.
  /// AES-256 requires exactly 32 bytes (256 bits).
  static Encrypter get _encrypter =>
      Encrypter(AES(Key.fromUtf8(AppConstants.encryptionKey), mode: AESMode.cbc));

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
