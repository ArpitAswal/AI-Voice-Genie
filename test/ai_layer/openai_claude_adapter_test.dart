import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_voice_genie/ai_layer/adapters/claude_adapter.dart';
import 'package:ai_voice_genie/ai_layer/adapters/openai_adapter.dart';
import 'package:ai_voice_genie/ai_layer/models/ai_request.dart';
import 'package:ai_voice_genie/core/constants/app_constants.dart';
import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/error/ai_exception.dart';

class FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  group('OpenAiAdapter Tests', () {
    test('generateText sends max_completion_tokens and captures tokens', () async {
      http.BaseRequest? capturedRequest;
      String? capturedBody;

      final client = FakeHttpClient((request) async {
        capturedRequest = request;
        final req = request as http.Request;
        capturedBody = req.body;

        final responseJson = {
          'id': 'chatcmpl-123',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'Hello from GPT!'},
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 45,
            'completion_tokens': 120,
            'total_tokens': 165,
          },
        };

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responseJson))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final adapter = OpenAiAdapter(client: client);
      final response = await adapter.generateText(
        request: AiRequest(
          capability: AiCapability.textGeneration,
          uid: 'test-user',
          prompt: 'Hi',
          responseLength: ResponseLength.balanced,
        ),
        apiKey: 'sk-test-key',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedBody, isNotNull);
      final bodyMap = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(bodyMap['model'], equals(AppConstants.openAiTextModel));
      expect(bodyMap['max_completion_tokens'], equals(ResponseLength.balanced.openAiMaxTokens));
      expect(bodyMap.containsKey('max_tokens'), isFalse);

      expect(response.text, equals('Hello from GPT!'));
      expect(response.inputTokens, equals(45));
      expect(response.outputTokens, equals(120));
      expect(response.tokenCount, equals(165));
      expect(response.modelUsed, equals(AiProviderId.openAi));
    });

    test('generateImage assigns image/png mimeType and sets tokens', () async {
      http.BaseRequest? capturedRequest;
      String? capturedBody;

      final client = FakeHttpClient((request) async {
        capturedRequest = request;
        final req = request as http.Request;
        capturedBody = req.body;

        final responseJson = {
          'created': 1727788800,
          'data': [
            {
              'b64_json': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
              'revised_prompt': 'A scenic landscape',
            }
          ],
          'usage': {
            'input_tokens': 50,
            'output_tokens': 300,
            'total_tokens': 350,
          }
        };

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responseJson))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final adapter = OpenAiAdapter(client: client);
      final response = await adapter.generateImage(
        request: AiRequest(
          capability: AiCapability.imageGeneration,
          uid: 'test-user',
          prompt: 'A scenic landscape',
          imageSize: AiImageSize.square,
          imageQuality: ImageQuality.medium,
        ),
        apiKey: 'sk-test-key',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedBody, isNotNull);
      final bodyMap = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(bodyMap['model'], equals(AppConstants.openAiImageGenModel));
      expect(bodyMap['size'], equals(AiImageSize.square.apiValue));

      expect(response.generatedImages, isNotNull);
      expect(response.generatedImages!.first.mimeType, equals('image/png'));
      expect(response.inputTokens, equals(50));
      expect(response.outputTokens, equals(300));
      expect(response.tokenCount, equals(350));
    });
  });

  group('ClaudeAdapter Tests', () {
    test('generateImage throws AiCapabilityGapException', () async {
      final adapter = ClaudeAdapter();

      expect(
        () => adapter.generateImage(
          request: AiRequest(
            capability: AiCapability.imageGeneration,
            uid: 'test-user',
            prompt: 'Draw a cat',
          ),
          apiKey: 'test-key',
        ),
        throwsA(
          isA<AiCapabilityGapException>()
              .having((e) => e.provider, 'provider', equals(AiProviderId.claude))
              .having((e) => e.missingCapability, 'missingCapability', equals(AiCapability.imageGeneration))
              .having((e) => e.message, 'message', equals('error_selected_model_capability_gap')),
        ),
      );
    });

    test('parsePdf includes anthropic-beta header and captures tokens', () async {
      http.BaseRequest? capturedRequest;

      final client = FakeHttpClient((request) async {
        capturedRequest = request;

        final responseJson = {
          'id': 'msg_123',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Summary of document'}
          ],
          'stop_reason': 'end_turn',
          'usage': {
            'input_tokens': 1200,
            'output_tokens': 250,
          },
        };

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responseJson))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final adapter = ClaudeAdapter(client: client);
      final response = await adapter.parsePdf(
        request: AiRequest(
          capability: AiCapability.pdfParsing,
          uid: 'test-user',
          prompt: 'Summarize',
          pdfBytes: [Uint8List.fromList([1, 2, 3, 4])],
          pdfNames: ['doc.pdf'],
        ),
        apiKey: 'test-claude-key',
      );

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.headers['anthropic-beta'],
        equals('pdfs-2024-09-25'),
      );
      expect(response.text, equals('Summary of document'));
      expect(response.inputTokens, equals(1200));
      expect(response.outputTokens, equals(250));
      expect(response.tokenCount, equals(1450));
    });

    test('generateText sends system and calculates tokenCount accurately', () async {
      http.BaseRequest? capturedRequest;

      final client = FakeHttpClient((request) async {
        capturedRequest = request;

        final responseJson = {
          'id': 'msg_456',
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Claude response'}
          ],
          'stop_reason': 'end_turn',
          'usage': {
            'input_tokens': 60,
            'output_tokens': 90,
          },
        };

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responseJson))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final adapter = ClaudeAdapter(client: client);
      final response = await adapter.generateText(
        request: AiRequest(
          capability: AiCapability.textGeneration,
          uid: 'test-user',
          prompt: 'Hello Claude',
        ),
        apiKey: 'test-claude-key',
      );

      expect(capturedRequest, isNotNull);
      expect(response.text, equals('Claude response'));
      expect(response.inputTokens, equals(60));
      expect(response.outputTokens, equals(90));
      expect(response.tokenCount, equals(150));
    });
  });
}
