import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/security/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    test('encrypt and decrypt work cleanly without key length errors', () {
      const originalText = 'my_super_secret_gemini_api_key_12345';
      
      final encrypted = EncryptionService.encrypt(originalText);
      expect(encrypted, isNot(equals(originalText)));
      expect(encrypted, contains(':'));
      
      final decrypted = EncryptionService.decrypt(encrypted);
      expect(decrypted, equals(originalText));
    });

    test('decrypt handles unencrypted legacy text gracefully', () {
      const legacyText = 'unencrypted_legacy_key';
      
      final decrypted = EncryptionService.decrypt(legacyText);
      expect(decrypted, equals(legacyText));
    });
  });
}
