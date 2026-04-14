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

/// Gemini provider adapter for AI Voice Genie.
///
/// Implements all four capabilities using Google's Generative Language API:
///   textGeneration     → POST /v1beta/models/{model}:generateContent
///   imageGeneration    → POST /v1beta/models/{imageModel}:generateContent
///   imageUnderstanding → POST /v1beta/models/{model}:generateContent (multimodal)
///   pdfParsing         → POST /v1beta/models/{model}:generateContent (text context)
///
/// Authentication: API key passed as query parameter (?key=...)
/// All errors are mapped to typed AiException subclasses.
class GeminiAdapter extends AiProviderAdapter {
  final http.Client _client;

  GeminiAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  AiProviderId get providerId => AiProviderId.gemini;

  // ── Text Generation ────────────────────────────────────────────────────────

  @override
  Future<AiResponse> generateText({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build contents array — Gemini uses 'user' / 'model' roles
      final contents = [
        // Previous conversation history
        ...request.conversationHistory.map((msg) => {
              'role': msg['role'] == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': msg['content'] ?? ''},
              ],
            }),
        // Current user prompt
        {
          'role': 'user',
          'parts': [
            {'text': request.prompt},
          ],
        },
      ];

      final response = await _post(
        model: AppConstants.geminiTextModel,
        apiKey: apiKey,
        body: {
          'contents': contents,
          'generationConfig': {
            'maxOutputTokens': 2048,
            'temperature': 0.7,
          },
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = _extractTextFromResponse(data);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.textGeneration,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
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
      // Gemini image generation uses a specific experimental model
      // Response contains inline_data with base64-encoded PNG
      final response = await _post(
        model: AppConstants.geminiImageGenModel,
        apiKey: apiKey,
        body: {
          'contents': [
            {
              'parts': [
                {'text': request.prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['IMAGE', 'TEXT']
          },
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);

      // Extract base64 image from Gemini's inline_data format
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const AiTransientException(
          message: 'Gemini returned empty response for image generation',
          provider: AiProviderId.gemini,
        );
      }

      // Find the image part — Gemini may return both text and image parts
      String? base64Image;
      for (final part in parts) {
        if (part['inlineData'] != null) {
          base64Image = part['inlineData']['data'] as String?;
          break;
        }
      }

      if (base64Image == null || base64Image.isEmpty) {
        throw const AiTransientException(
          message: 'Gemini image generation returned no image data',
          provider: AiProviderId.gemini,
        );
      }

      stopwatch.stop();
      return AiResponse.imageBase64(
        modelUsed: AiProviderId.gemini,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imageBase64: base64Image,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ── Image Understanding ────────────────────────────────────────────────────

  @override
  Future<AiResponse> analyzeImage({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    final base64Image = base64Encode(request.imageBytes ?? []);
    final mimeType = request.imageMimeType ?? 'image/jpeg';

    try {
      // Gemini multimodal: image and text in same parts array
      final response = await _post(
        model: AppConstants.geminiVisionModel,
        apiKey: apiKey,
        body: {
          'contents': [
            {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Image,
                  },
                },
                {'text': request.prompt},
              ],
            },
          ],
          'generationConfig': {'maxOutputTokens': 1024},
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = _extractTextFromResponse(data);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.imageUnderstanding,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ── PDF Parsing ────────────────────────────────────────────────────────────

  @override
  Future<AiResponse> parsePdf({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    final systemContext = 'You are a document analysis assistant. '
        'The following is extracted text from a PDF titled '
        '"${request.pdfFileName ?? "document"}".\n\n'
        'Document:\n${request.pdfText ?? ""}\n\n'
        'Answer questions based only on this document.';

    try {
      final response = await _post(
        model: AppConstants.geminiTextModel,
        apiKey: apiKey,
        body: {
          'contents': [
            {
              'parts': [
                {'text': '$systemContext\n\nQuestion: ${request.prompt}'},
              ],
            },
          ],
          'generationConfig': {
            'maxOutputTokens': 2048,
            'temperature': 0.3,
          },
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = _extractTextFromResponse(data);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.pdfParsing,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Make an authenticated POST request to the Gemini API.
  /// Gemini uses query param authentication (?key=...)
  Future<http.Response> _post({
    required String model,
    required String apiKey,
    required Map<String, dynamic> body,
  }) {
    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$model:generateContent?key=$apiKey',
    );
    return _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  /// Parse HTTP response and map to typed AiExceptions.
  Map<String, dynamic> _parseResponse(
    http.Response response,
    String requestId,
  ) {
    debugPrint('🔷 Gemini: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // Gemini uses 400 for invalid API key (not 401)
    if (response.statusCode == 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = body?['error']?['message'] as String? ?? '';
      if (message.toLowerCase().contains('api key')) {
        throw const AiHardErrorException(
          message: 'Invalid Gemini API key',
          provider: AiProviderId.gemini,
          statusCode: 400,
        );
      }
    }

    throw mapHttpErrorToAiException(
      statusCode: response.statusCode,
      provider: AiProviderId.gemini,
      rawMessage: response.body,
    );
  }

  /// Extract text from Gemini's nested response structure.
  String _extractTextFromResponse(Map<String, dynamic> data) {
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    return parts
        .whereType<Map>()
        .map((part) => part['text'] as String? ?? '')
        .join('');
  }

  AiException _mapError(Object error) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'No internet connection',
        provider: AiProviderId.gemini,
      );
    }
    if (error is http.ClientException) {
      return AiTransientException(
        message: 'Network error: ${error.message}',
        provider: AiProviderId.gemini,
      );
    }
    return AiTransientException(
      message: 'Unexpected Gemini error: $error',
      provider: AiProviderId.gemini,
    );
  }
}
