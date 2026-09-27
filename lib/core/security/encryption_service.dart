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
  ///
  /// SECURITY: In release mode, a missing key is a hard failure — the app
  /// refuses to start rather than silently falling back to an all-zero key,
  /// which would make every stored API key trivially decryptable.
  ///
  /// In debug/profile mode (e.g. unit tests, local runs without secrets.json)
  /// the same hard assertion fires — intentionally — so developers are never
  /// silently running with a weakened key.
  ///
  /// To configure, run/build with:
  ///   flutter run --dart-define-from-file=secrets.json
  ///   flutter build apk --dart-define-from-file=secrets.json
  static Key get _key {
    var keyString = AppConstants.encryptionKey;

    // ─── SECURITY GATE ────────────────────────────────────────────────────────
    // If the encryption key was not injected at build time, refuse to operate.
    // This prevents the silent all-zero-key fallback that would make
    // every API key stored in Firestore trivially decryptable.
    if (keyString.isEmpty) {
      throw StateError(
        '[EncryptionService] FATAL: encryptionKey is empty.\n'
        'Build with: flutter run --dart-define-from-file=secrets.json\n'
        'or: flutter build apk --dart-define-from-file=secrets.json\n'
        'Ensure secrets.json contains a non-empty "ENCRYPTION_KEY" value.',
      );
    }
    // ─────────────────────────────────────────────────────────────────────────

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
