import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/constants/firebase_collections.dart';

void main() {
  group('FirebaseCollections Storage Paths', () {
    const uid = 'test-user-123';
    const conversationId = 'conv-456';
    const fileName = 'sample.png';

    test('storageConversationDir generates unified conversation path', () {
      final path =
          FirebaseCollections.storageConversationDir(uid, conversationId);
      expect(path, 'users/test-user-123/conversations/conv-456');
    });

    test('storageImagePath generates conversation-scoped image path', () {
      final path = FirebaseCollections.storageImagePath(
        uid,
        conversationId,
        fileName,
      );
      expect(
        path,
        'users/test-user-123/conversations/conv-456/images/sample.png',
      );
    });

    test('storagePdfPath generates conversation-scoped pdf path', () {
      final path = FirebaseCollections.storagePdfPath(
        uid,
        conversationId,
        'doc.pdf',
      );
      expect(
        path,
        'users/test-user-123/conversations/conv-456/pdfs/doc.pdf',
      );
    });

    test('storageGeneratedImagePath generates conversation-scoped generated image path', () {
      final path = FirebaseCollections.storageGeneratedImagePath(
        uid,
        conversationId,
        'gen_1.png',
      );
      expect(
        path,
        'users/test-user-123/conversations/conv-456/generated/gen_1.png',
      );
    });

    test('storage metadata keys are defined', () {
      expect(FirebaseCollections.storageMetaUploadedBy, 'uploadedBy');
      expect(FirebaseCollections.storageMetaGeneratedBy, 'generatedBy');
      expect(FirebaseCollections.storageMetaConversationId, 'conversationId');
      expect(FirebaseCollections.storageMetaOriginalName, 'originalName');
      expect(FirebaseCollections.storageMetaTypeAiGenerated, 'ai_generated');
    });
  });
}
