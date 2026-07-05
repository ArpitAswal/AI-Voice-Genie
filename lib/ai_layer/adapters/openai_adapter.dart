import 'dart:convert';
import 'dart:io';

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
          'content': 'You are a helpful, accurate, and concise AI assistant. '
              'Format responses clearly using markdown where appropriate.',
        },
        // Include previous conversation messages for context
        ...request.conversationHistory,
        // The current user prompt
        {'role': 'user', 'content': request.prompt},
      ];

      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: {
          'model': AppConstants.openAiTextModel,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'OpenAI returned empty choices',
          provider: AiProviderId.openAi,
        );
      }

      final text = choices[0]['message']?['content'] as String? ?? '';
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.textGeneration,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post(
        endpoint: '/images/generations',
        apiKey: apiKey,
        body: {
          'model': AppConstants.openAiImageGenModel,
          'prompt': request.prompt,
          'n': request.imageCount,
          'size': request.imageSize.value,
          'quality': request.imageQuality.value,
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final imageBase64 = data['data']?[0]?['b64_json'] as String? ?? '';

      if (imageBase64.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      stopwatch.stop();
      return AiResponse.imageBase64(
        modelUsed: AiProviderId.openAi,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imageBase64: imageBase64,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e, request.requestId);
    }
  }

  // ── Image Understanding ────────────────────────────────────────────────────

  @override
  Future<AiResponse> analyzeImage({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Convert image bytes to base64 for the API
    final base64Image = base64Encode(request.imageBytes ?? []);
    final mimeType = request.imageMimeType ?? 'image/jpeg';

    try {
      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: {
          'model': AppConstants.openAiVisionModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                    'detail': 'auto',
                  },
                },
                {'type': 'text', 'text': request.prompt},
              ],
            },
          ],
          'max_tokens': 1024,
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'OpenAI returned empty choices for image analysis',
          provider: AiProviderId.openAi,
        );
      }

      final text = choices[0]['message']?['content'] as String? ?? '';
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.imageUnderstanding,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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

    // Inject PDF text as a system-level document context
    final systemPrompt =
        'You are a document analysis assistant. The following is the '
        'extracted text from a PDF document titled '
        '"${request.pdfFileName ?? "document"}".\n\n'
        'Document content:\n\n${request.pdfText ?? ""}\n\n'
        'Answer the user\'s questions based only on the document content above.';

    try {
      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: {
          'model': AppConstants.openAiTextModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': request.prompt},
          ],
          'max_tokens': 2048,
          'temperature': 0.3, // Lower temp for factual document Q&A
        },
      ).timeout(AppConstants.aiRequestTimeout);
      final data = _parseResponse(response, request.requestId);
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'OpenAI returned empty choices for PDF parsing',
          provider: AiProviderId.openAi,
        );
      }

      final text = choices[0]['message']?['content'] as String? ?? '';
      final tokenCount = data['usage']?['total_tokens'] as int? ?? 0;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.pdfParsing,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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
  Map<String, dynamic> _parseResponse(
    http.Response response,
    String requestId,
  ) {
    debugPrint(
      '🤖 OpenAI [${response.request?.url.path}]: ${response.statusCode}',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    debugPrint('🤖 OpenAI error body: ${response.body}');

    throw mapHttpErrorToAiException(
      statusCode: response.statusCode,
      provider: AiProviderId.openAi,
      rawMessage: response.body,
    );
  }

  /// Map non-HTTP errors (network, timeout, etc.) to AiException.
  AiException _mapError(Object error, String requestId) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'No internet connection',
        provider: AiProviderId.openAi,
      );
    }
    if (error is http.ClientException) {
      return AiTransientException(
        message: 'Network error: ${error.message}',
        provider: AiProviderId.openAi,
      );
    }
    return AiTransientException(
      message: 'Unexpected OpenAI error: $error',
      provider: AiProviderId.openAi,
    );
  }
}
