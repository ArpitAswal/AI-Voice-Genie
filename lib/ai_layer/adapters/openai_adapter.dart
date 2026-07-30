import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/ai_exception.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import 'ai_provider_adapter.dart';

/// OpenAI provider adapter for AI Voice Genie.
///
/// Implements all four capabilities using OpenAI's REST API:
///   textGeneration    → POST /v1/chat/completions (gpt-4o)
///   imageGeneration   → POST /v1/images/generations (gpt-image-1)
///   imageUnderstanding → POST /v1/chat/completions with image_url (gpt-4o)
///   pdfParsing        → POST /v1/chat/completions with PDF text in context
///
/// All errors are mapped to typed AiException subclasses.
/// Raw HTTP/provider errors never escape this class.
class OpenAiAdapter extends AiProviderAdapter {
  final http.Client _client;

  OpenAiAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  AiProviderId get providerId => AiProviderId.openAi;

  // ── Text Generation ────────────────────────────────────────────────────────

  @override
  Future<AiResponse> generateText({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build messages array with conversation history for context continuity
      final messages = [
        // System prompt — sets the assistant's behavior
        {
          'role': 'system',
          'content': AppConstants.aiTextSystemInstruction,
        },
        // Include previous conversation messages for context
        ...request.conversationHistory,
        // The current user prompt
        {'role': 'user', 'content': request.prompt},
      ];

      final requestBody = {
        'model': AppConstants.openAiTextModel,
        'max_tokens': request.responseLength.maxTokens,
        'temperature': 0.7,
        'messages': messages,
      };

      debugPrint(
          '📤 OpenAI Request (Text Generation): ${jsonEncode(requestBody)}');

      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      final text = choices[0]['message']?['content'] as String? ?? '';
      final inputTokens = data['usage']?['prompt_tokens'] as int? ?? 0;
      final outputTokens = data['usage']?['completion_tokens'] as int? ?? 0;
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;
      final finishReason = choices[0]['finish_reason'] as String?;

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (Text Generation): ${jsonEncode(data)}');
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.textGeneration,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        tokenCount: tokenCount,
        finishReason: finishReason,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e, request.requestId);
    }
  }

  // ── Image Generation ───────────────────────────────────────────────────────

  @override
  Future<AiResponse> generateImage({
    required AiRequest request,
    required String apiKey,
  }) async {
    // ── Real API ──────────────────────────────────────────────────────────────
    final stopwatch = Stopwatch()..start();

    try {
      final requestBody = {
        'model': AppConstants.openAiImageGenModel,
        'n': request.imageCount ?? 1,
        'size': request.imageSize?.apiValue ?? AiImageSize.square.apiValue,
        'quality': request.imageQuality?.name ?? ImageQuality.low.name,
        'background':
            request.imageBackground?.name ?? ImageGenerateBackground.auto,
        'prompt': request.prompt,
      };
      debugPrint(
          '📤 OpenAI Request (Image Generation): ${jsonEncode(requestBody)}');

      final response = await _post(
        endpoint: '/images/generations',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);

      // Parse all generated images and their attributes into AiImageData models
      final List<AiImageData> generatedImages = (data['data'] as List<dynamic>)
          .map((e) => AiImageData(
                b64Json: e['b64_json'] as String?,
                url: e['url'] as String?,
                revisedPrompt: e['revised_prompt'] as String?,
              ))
          .toList();

      if (generatedImages.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      // Extract the first image's base64 for legacy compatibility in other parts of the app
      final String? firstImageBase64 = generatedImages.first.b64Json;

      stopwatch.stop();
      final logData = Map<String, dynamic>.from(data);
      if (logData['data'] is List) {
        final List truncatedData = [];
        for (var item in (logData['data'] as List)) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['b64_json'] != null) {
            map['b64_json'] = '<base64_data_truncated>';
          }
          truncatedData.add(map);
        }
        logData['data'] = truncatedData;
      }
      final inputTokens = data['usage']?['input_tokens'] as int? ?? 0;
      final outputTokens = data['usage']?['output_tokens'] as int? ?? 0;
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;

      debugPrint(
          '📥 OpenAI Response (Image Generation): ${jsonEncode(logData)}');
      // Store all the valid response attributes that will be returned by image generations
      return AiResponse.imageBase64(
        modelUsed: AiProviderId.openAi,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imageBase64: firstImageBase64,
        generatedImages: generatedImages,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        tokenCount: tokenCount,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e, request.requestId);
    }
  }

  // ── Image Understanding (Vision) ─────────────────────────────────────────

  @override
  Future<AiResponse> analyzeImage({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final List<Map<String, dynamic>> contentParts = [
        // User's text prompt is the first content block
        {'type': 'text', 'text': request.prompt},
      ];

      if (request.imageBytes != null && request.imageBytes!.isNotEmpty) {
        // Preferred path: use the visionAttachments list (supports N images).
        // Each attachment is base64-encoded as a data-URI inside image_url.
        for (final att in request.imageBytes!) {
          final base64Data = base64Encode(att);
          final mimeType = request.imageMimeType ?? 'image/jpeg';
          contentParts.add({
            'type': 'image_url',
            'image_url': {
              // data-URI format: data:<mimeType>;base64,<encoded>
              'url': 'data:$mimeType;base64,$base64Data',
              // detail controls resolution — auto lets the model decide
              'detail': request.visionDetailLevel.apiValue,
            },
          });
        }
      }

      final requestBody = {
        // gpt-4o natively supports multi-image vision
        'model': AppConstants.openAiVisionModel,
        'max_tokens': request.responseLength.maxTokens,
        'temperature': 0.4,
        'messages': [
          {
            'role': 'system',
            'content': AppConstants.aiVisionSystemInstruction,
          },
          {
            'role': 'user',
            'content': contentParts,
          },
        ],
      };

      debugPrint(
          '📤 OpenAI Request (Image Analysis): ${jsonEncode(requestBody)}');

      // Use /v1/chat/completions — the standard, well-documented vision endpoint
      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);

      // Extract text from standard choices[0].message.content path
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      final text = choices[0]['message']?['content'] as String? ?? '';
      final inputTokens = data['usage']?['prompt_tokens'] as int? ?? 0;
      final outputTokens = data['usage']?['completion_tokens'] as int? ?? 0;
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;
      final finishReason = choices[0]['finish_reason'] as String?;

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (Image Analysis): ${jsonEncode(data)}');
      return AiResponse.analysis(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.imageUnderstanding,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        tokenCount: tokenCount,
        finishReason: finishReason,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e, request.requestId);
    }
  }

  // ── PDF Parsing ────────────────────────────────────────────────────────────

  @override
  Future<AiResponse> parsePdf({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final List<Map<String, dynamic>> contentParts = [
        // User's text prompt comes first in the content array
        {'type': 'input_text', 'text': request.prompt},
      ];

      if (request.pdfBytes != null && request.pdfBytes!.isNotEmpty) {
        // Build the content array: text prompt + one input_file per PDF

        for (int i = 0; i < request.pdfBytes!.length; i++) {
          final base64Data = base64Encode(request.pdfBytes![i]);
          final filename =
              (request.pdfNames != null && request.pdfNames!.length > i)
                  ? request.pdfNames![i]
                  : 'document.pdf';
          contentParts.add({
            'type': 'input_file',
            // Filename gives the model context about the document
            'filename': filename,
            // OpenAI expects: data:application/pdf;base64,<encoded>
            'file_data': 'data:application/pdf;base64,$base64Data',
          });
        }
      }
      final requestBody = {
        // gpt-4o supports native PDF reading in the Responses API
        'model': AppConstants.openAiVisionModel,
        'instructions': AppConstants.aiPdfSystemInstruction,
        'max_output_tokens': request.responseLength.maxTokens,
        'temperature': 0.3,
        'input': [
          {
            'role': 'user',
            'content': contentParts,
          },
        ],
      };

      debugPrint('📤 OpenAI Request (PDF Parsing): ${jsonEncode(requestBody)}');

      // POST to /v1/responses — the Responses API endpoint
      final response = await _post(
        endpoint: '/responses',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);

      // Responses API stores result in output[].content[].text
      final output = data['output'] as List?;
      String text = '';
      String? finishReason;
      if (output != null) {
        for (final item in output) {
          if (item['type'] == 'message') {
            final contentList = item['content'] as List?;
            if (contentList != null) {
              for (final c in contentList) {
                if (c['type'] == 'output_text') {
                  text += (c['text'] as String? ?? '');
                }
              }
            }
            // Responses API output item contains status like 'completed'
            finishReason = item['status'] as String?;
          }
        }
      }

      final inputTokens = data['usage']?['prompt_tokens'] as int? ??
          data['usage']?['input_tokens'] as int? ??
          0;
      final outputTokens = data['usage']?['completion_tokens'] as int? ??
          data['usage']?['output_tokens'] as int? ??
          0;
      final tokenCount = data['usage']?['total_tokens'] as int? ??
          (inputTokens + outputTokens);

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (PDF Parsing): ${jsonEncode(data)}');
      return AiResponse.analysis(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.pdfParsing,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        tokenCount: tokenCount,
        finishReason: finishReason,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e, request.requestId);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Make an authenticated POST request to the OpenAI API.
  Future<http.Response> _post({
    required String endpoint,
    required String apiKey,
    required Map<String, dynamic> body,
  }) {
    return _client.post(
      Uri.parse('${AppConstants.openAiBaseUrl}$endpoint'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  /// Parse HTTP response and map status codes to typed AiExceptions.
  Future<Map<String, dynamic>> _parseResponse(
    http.Response response,
    String requestId,
  ) async {
    debugPrint(
      '🤖 OpenAI [${response.request?.url.path}]: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      final bodyString = response.body;
      // Offload heavy JSON parsing to a background isolate.
      // For large responses (like multiple base64 images), decoding on the
      // main thread would cause severe UI stuttering and frozen frames.
      return await Isolate.run(
          () => jsonDecode(bodyString) as Map<String, dynamic>);
    }

    debugPrint('🤖 OpenAI error body: ${response.body}');

    throw mapHttpErrorToAiException(
      statusCode: response.statusCode,
      provider: AiProviderId.openAi,
      rawMessage: response.body,
    );
  }

  /// Map non-HTTP errors (network, timeout, etc.) to typed AiException.
  AiException _mapError(Object error, String requestId) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'no_internet_connection',
        provider: AiProviderId.openAi,
      );
    }
    if (error is http.ClientException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
        provider: AiProviderId.openAi,
      );
    }
    return const AiTransientException(
      message: 'error_unexpected_ai',
      provider: AiProviderId.openAi,
    );
  }
}
