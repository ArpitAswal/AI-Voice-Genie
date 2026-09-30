import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/ai_layer/registry/provider_registry.dart';
import 'package:ai_voice_genie/ai_layer/models/ai_request.dart';
import 'package:ai_voice_genie/features/chat/domain/message_model.dart';

void main() {
  group('GeminiThinkingLevel Enum Tests', () {
    test('api values match Google Gemini 3.8 Flash specifications', () {
      expect(GeminiThinkingLevel.low.apiValue, 'low');
      expect(GeminiThinkingLevel.medium.apiValue, 'medium');
      expect(GeminiThinkingLevel.high.apiValue, 'high');
    });

    test('fromString safely parses valid, uppercase, and unknown values', () {
      expect(GeminiThinkingLevel.fromString('low'), GeminiThinkingLevel.low);
      expect(GeminiThinkingLevel.fromString('LOW'), GeminiThinkingLevel.low);
      expect(GeminiThinkingLevel.fromString('medium'), GeminiThinkingLevel.medium);
      expect(GeminiThinkingLevel.fromString('HIGH'), GeminiThinkingLevel.high);
      expect(GeminiThinkingLevel.fromString('unknown'), GeminiThinkingLevel.medium);
      expect(GeminiThinkingLevel.fromString(null), GeminiThinkingLevel.medium);
      expect(GeminiThinkingLevel.fromString(''), GeminiThinkingLevel.medium);
    });
  });

  group('ProviderRegistry & GeminiThinkingLevel Tests', () {
    final registry = ProviderRegistry.instance;

    test('Gemini profile supports geminiThinkingLevel control', () {
      final geminiProfile = registry.profileFor(AiProviderId.gemini);
      expect(
        geminiProfile.supports(AiPreferenceControl.geminiThinkingLevel),
        isTrue,
      );
    });

    test('OpenAI and Claude profiles do not support geminiThinkingLevel control', () {
      final openAiProfile = registry.profileFor(AiProviderId.openAi);
      final claudeProfile = registry.profileFor(AiProviderId.claude);

      expect(
        openAiProfile.supports(AiPreferenceControl.geminiThinkingLevel),
        isFalse,
      );
      expect(
        claudeProfile.supports(AiPreferenceControl.geminiThinkingLevel),
        isFalse,
      );
    });

    test('sanitizePreferences retains geminiThinkingLevel for Gemini textGeneration', () {
      final effective = registry.sanitizePreferences(
        providerId: AiProviderId.gemini,
        capability: AiCapability.textGeneration,
        rawResponseLength: ResponseLength.balanced,
        rawImageSize: AiImageSize.square,
        rawImageQuality: ImageQuality.low,
        rawImageBackground: ImageGenerateBackground.auto,
        rawImageCount: 1,
        rawVisionDetailLevel: VisionDetailLevel.auto,
        rawGeminiThinkingLevel: GeminiThinkingLevel.high,
      );

      expect(effective.geminiThinkingLevel, GeminiThinkingLevel.high);
      expect(
        effective.droppedControls.contains(AiPreferenceControl.geminiThinkingLevel),
        isFalse,
      );
    });

    test('sanitizePreferences drops geminiThinkingLevel for OpenAI and Claude', () {
      final openAiEffective = registry.sanitizePreferences(
        providerId: AiProviderId.openAi,
        capability: AiCapability.textGeneration,
        rawResponseLength: ResponseLength.balanced,
        rawImageSize: AiImageSize.square,
        rawImageQuality: ImageQuality.low,
        rawImageBackground: ImageGenerateBackground.auto,
        rawImageCount: 1,
        rawVisionDetailLevel: VisionDetailLevel.auto,
        rawGeminiThinkingLevel: GeminiThinkingLevel.high,
      );

      expect(openAiEffective.geminiThinkingLevel, isNull);
      expect(
        openAiEffective.droppedControls.contains(AiPreferenceControl.geminiThinkingLevel),
        isTrue,
      );

      final claudeEffective = registry.sanitizePreferences(
        providerId: AiProviderId.claude,
        capability: AiCapability.textGeneration,
        rawResponseLength: ResponseLength.balanced,
        rawImageSize: AiImageSize.square,
        rawImageQuality: ImageQuality.low,
        rawImageBackground: ImageGenerateBackground.auto,
        rawImageCount: 1,
        rawVisionDetailLevel: VisionDetailLevel.auto,
        rawGeminiThinkingLevel: GeminiThinkingLevel.high,
      );

      expect(claudeEffective.geminiThinkingLevel, isNull);
      expect(
        claudeEffective.droppedControls.contains(AiPreferenceControl.geminiThinkingLevel),
        isTrue,
      );
    });
  });

  group('AiRequest ThinkingLevel Tests', () {
    test('defaults to GeminiThinkingLevel.medium', () {
      final request = AiRequest(
        capability: AiCapability.textGeneration,
        uid: 'test_uid',
        prompt: 'Hello AI',
      );

      expect(request.thinkingLevel, GeminiThinkingLevel.medium);
    });

    test('accepts custom thinkingLevel', () {
      final request = AiRequest(
        capability: AiCapability.textGeneration,
        uid: 'test_uid',
        prompt: 'Hello AI',
        thinkingLevel: GeminiThinkingLevel.high,
      );

      expect(request.thinkingLevel, GeminiThinkingLevel.high);
    });

    test('accepts custom geminiAspectRatio', () {
      final request = AiRequest(
        capability: AiCapability.imageGeneration,
        uid: 'test_uid',
        prompt: 'A sunset view',
        geminiAspectRatio: GeminiAspectRatio.landscape,
      );

      expect(request.geminiAspectRatio, GeminiAspectRatio.landscape);
    });
  });

  group('GeminiAspectRatio Tests', () {
    test('api values match expected Gemini image API ratios', () {
      expect(GeminiAspectRatio.square.apiValue, '1:1');
      expect(GeminiAspectRatio.landscape.apiValue, '16:9');
      expect(GeminiAspectRatio.portrait.apiValue, '9:16');
    });

    test('display names show ratio clearly', () {
      expect(GeminiAspectRatio.square.displayName, 'Square (1:1)');
      expect(GeminiAspectRatio.landscape.displayName, 'Landscape (16:9)');
      expect(GeminiAspectRatio.portrait.displayName, 'Portrait (9:16)');
    });

    test('sanitizePreferences preserves geminiAspectRatio for Gemini imageGeneration', () {
      final effective = ProviderRegistry.instance.sanitizePreferences(
        providerId: AiProviderId.gemini,
        capability: AiCapability.imageGeneration,
        rawResponseLength: ResponseLength.balanced,
        rawImageSize: AiImageSize.square,
        rawImageQuality: ImageQuality.low,
        rawImageBackground: ImageGenerateBackground.auto,
        rawImageCount: 1,
        rawVisionDetailLevel: VisionDetailLevel.auto,
        rawGeminiAspectRatio: GeminiAspectRatio.landscape,
      );

      expect(effective.geminiAspectRatio, GeminiAspectRatio.landscape);
    });

    test('sanitizePreferences drops geminiAspectRatio for OpenAI imageGeneration', () {
      final effective = ProviderRegistry.instance.sanitizePreferences(
        providerId: AiProviderId.openAi,
        capability: AiCapability.imageGeneration,
        rawResponseLength: ResponseLength.balanced,
        rawImageSize: AiImageSize.landscape,
        rawImageQuality: ImageQuality.low,
        rawImageBackground: ImageGenerateBackground.auto,
        rawImageCount: 1,
        rawVisionDetailLevel: VisionDetailLevel.auto,
        rawGeminiAspectRatio: GeminiAspectRatio.landscape,
      );

      expect(effective.geminiAspectRatio, isNull);
      expect(
        effective.droppedControls.contains(AiPreferenceControl.geminiAspectRatio),
        isTrue,
      );
    });

    test('AiImageSize.fromValue handles both Gemini aspect ratios and OpenAI sizes', () {
      expect(AiImageSize.fromValue('Square (1:1)'), AiImageSize.square);
      expect(AiImageSize.fromValue('1:1'), AiImageSize.square);
      expect(AiImageSize.fromValue('Landscape (16:9)'), AiImageSize.landscape);
      expect(AiImageSize.fromValue('16:9'), AiImageSize.landscape);
      expect(AiImageSize.fromValue('Portrait (9:16)'), AiImageSize.portrait);
      expect(AiImageSize.fromValue('9:16'), AiImageSize.portrait);

      expect(AiImageSize.fromValue('Square (1024x1024)'), AiImageSize.square);
      expect(AiImageSize.fromValue('Landscape (1536x1024)'), AiImageSize.landscape);
      expect(AiImageSize.fromValue('Portrait (1024x1536)'), AiImageSize.portrait);
    });

    test('MessageModel serialization outputs null imageQuality and Gemini aspect ratio for Gemini', () {
      final geminiMsg = MessageModel.aiResponse(
        content: '',
        modelUsed: AiProviderId.gemini,
        contentType: AiCapability.imageGeneration,
        imageSize: AiImageSize.landscape,
        imageQuality: null,
        mimeType: 'image/jpeg',
      );

      expect(geminiMsg.effectiveImageSizeString, 'Landscape (16:9)');
      final firestoreData = geminiMsg.toFirestore();
      expect(firestoreData['imageSize'], 'Landscape (16:9)');
      expect(firestoreData['imageQuality'], isNull);
      expect(firestoreData['mimeType'], 'image/jpeg');

      final openAiMsg = MessageModel.aiResponse(
        content: '',
        modelUsed: AiProviderId.openAi,
        contentType: AiCapability.imageGeneration,
        imageSize: AiImageSize.landscape,
        imageQuality: ImageQuality.low,
        mimeType: 'image/png',
      );

      expect(openAiMsg.effectiveImageSizeString, 'Landscape (1536x1024)');
      final openAiFirestore = openAiMsg.toFirestore();
      expect(openAiFirestore['imageSize'], 'Landscape (1536x1024)');
      expect(openAiFirestore['imageQuality'], 'low');
      expect(openAiFirestore['mimeType'], 'image/png');
    });
  });
}
