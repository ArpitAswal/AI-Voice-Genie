import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/constants/firebase_collections.dart';
import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/features/chat/domain/local_message_record.dart';
import 'package:ai_voice_genie/features/chat/domain/message_model.dart';

void main() {
  group('MessageModel & LocalMessageRecord Unit Tests', () {
    test('userMessage with attachments preserves imagePaths and pdfInfo', () {
      final message = MessageModel.userMessage(
        lastPrompt: 'Analyze this receipt',
        validProvider: AiProviderId.openAi,
        requestCapability: AiCapability.imageUnderstanding,
        imagePaths: ['/local/path/image1.jpg'],
        pdfInfo: const [
          PdfAttachmentInfo(
            path: '/local/path/doc.pdf',
            name: 'doc.pdf',
            fileSizeBytes: 1024,
          )
        ],
        visionDetailLevel: VisionDetailLevel.high,
      );

      expect(message.imageUrls, contains('/local/path/image1.jpg'));
      expect(message.pdfInfo?.first.name, equals('doc.pdf'));
      expect(message.visionDetailLevel, equals(VisionDetailLevel.high));
      expect(message.role, equals(MessageRole.user));
    });

    test('Claude model strictly enforces null for image generation fields and visionDetailLevel', () {
      final message = MessageModel.userMessage(
        lastPrompt: 'Generate a cat picture',
        validProvider: AiProviderId.claude,
        requestCapability: AiCapability.textGeneration,
        imageSize: null,
        imageQuality: null,
        generateImageRequest: null,
        imageBackground: null,
        visionDetailLevel: null,
      );

      expect(message.imageSize, isNull);
      expect(message.imageQuality, isNull);
      expect(message.generateImageRequest, isNull);
      expect(message.imageCount, isNull);
      expect(message.imageBackground, isNull);
      expect(message.visionDetailLevel, isNull);
    });

    test('OpenAI image generation maps generateImageRequest and imageBackground', () {
      final message = MessageModel.userMessage(
        lastPrompt: 'A glowing futuristic city',
        validProvider: AiProviderId.openAi,
        requestCapability: AiCapability.imageGeneration,
        imageSize: AiImageSize.landscape,
        imageQuality: ImageQuality.high,
        imageBackground: ImageGenerateBackground.opaque,
        generateImageRequest: 2,
      );

      expect(message.generateImageRequest, equals(2));
      expect(message.imageCount, equals(2));
      expect(message.imageBackground, equals(ImageGenerateBackground.opaque));
      expect(message.imageQuality, equals(ImageQuality.high));
      expect(message.imageSize, equals(AiImageSize.landscape));

      // Test Firestore serialization
      final firestoreData = message.toFirestore();
      expect(firestoreData[FirebaseCollections.fieldImageCount], equals(2));
      expect(firestoreData[FirebaseCollections.fieldImageBackground], equals('opaque'));
      expect(firestoreData[FirebaseCollections.fieldImageQuality], equals('high'));

      // Test Firestore deserialization
      final restored = MessageModel.fromFirestore(message.id, firestoreData);
      expect(restored.generateImageRequest, equals(2));
      expect(restored.imageBackground, equals(ImageGenerateBackground.opaque));
      expect(restored.imageQuality, equals(ImageQuality.high));
    });

    test('OpenAI image understanding maps visionDetailLevel', () {
      final message = MessageModel.userMessage(
        lastPrompt: 'What is in this image?',
        validProvider: AiProviderId.openAi,
        requestCapability: AiCapability.imageUnderstanding,
        imagePaths: ['/path/to/img.png'],
        visionDetailLevel: VisionDetailLevel.low,
      );

      expect(message.visionDetailLevel, equals(VisionDetailLevel.low));

      final firestoreData = message.toFirestore();
      expect(firestoreData[FirebaseCollections.fieldVisionDetailLevel], equals('low'));

      final restored = MessageModel.fromFirestore(message.id, firestoreData);
      expect(restored.visionDetailLevel, equals(VisionDetailLevel.low));
    });

    test('LocalMessageRecord round-trip preserves imageBackground and visionDetailLevel', () {
      final message = MessageModel.userMessage(
        lastPrompt: 'Generate with transparent background',
        validProvider: AiProviderId.openAi,
        requestCapability: AiCapability.imageGeneration,
        imageBackground: ImageGenerateBackground.transparent,
        visionDetailLevel: VisionDetailLevel.high,
        generateImageRequest: 3,
        imageSize: AiImageSize.portrait,
      );

      final record = LocalMessageRecord.fromMessageModel(
        message,
        uid: 'user_123',
        conversationId: 'conv_456',
      );

      expect(record.imageBackground, equals(ImageGenerateBackground.transparent));
      expect(record.visionDetailLevel, equals(VisionDetailLevel.high));
      expect(record.imageCount, equals(3));

      // Test Map serialization for Hive
      final map = record.toMap();
      expect(map['imageBackground'], equals('transparent'));
      expect(map['visionDetailLevel'], equals('high'));
      expect(map['imageCount'], equals(3));

      final restoredRecord = LocalMessageRecord.fromMap(map);
      expect(restoredRecord.imageBackground, equals(ImageGenerateBackground.transparent));
      expect(restoredRecord.visionDetailLevel, equals(VisionDetailLevel.high));
      expect(restoredRecord.imageCount, equals(3));

      final restoredMessage = restoredRecord.toMessageModel();
      expect(restoredMessage.imageBackground, equals(ImageGenerateBackground.transparent));
      expect(restoredMessage.visionDetailLevel, equals(VisionDetailLevel.high));
      expect(restoredMessage.generateImageRequest, equals(3));
    });
  });
}
