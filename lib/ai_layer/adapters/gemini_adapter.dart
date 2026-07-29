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

/// Gemini provider adapter for AI Voice Genie.
///
/// Implements all four capabilities using Google's Generative Language REST API:
///   textGeneration     → POST /v1beta/models/gemini-2.5-flash:generateContent
///   imageGeneration    → POST /v1beta/models/gemini-2.5-flash-image:generateContent
///   imageUnderstanding → POST /v1beta/models/gemini-2.5-flash:generateContent (multimodal)
///   pdfParsing         → POST /v1beta/models/gemini-2.5-flash:generateContent (inline PDF)
///
/// Authentication: API key passed as query parameter (?key=...) AND as x-goog-api-key header.
/// All errors are mapped to typed AiException subclasses.
/// Raw HTTP/provider errors never escape this class.
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
      // Build contents array — Gemini uses 'user' / 'model' roles (not 'assistant')
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

      final requestBody = {
        // System instruction — equivalent to OpenAI's system message
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiTextSystemInstruction,
            }
          ]
        },
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': request.responseLength.maxTokens,
          'temperature': 0.7,
        },
      };

      debugPrint(
          '📤 Gemini Request (Text Generation): ${jsonEncode(requestBody)}');

      final response = await _post(
        model: AppConstants.geminiTextModel,
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Text Generation): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      if (text.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      final inputTokens =
          data['usageMetadata']?['promptTokenCount'] as int? ?? 0;
      final outputTokens =
          data['usageMetadata']?['candidatesTokenCount'] as int? ?? 0;
      final tokenCount = data['usageMetadata']?['totalTokenCount'] as int? ?? 0;
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
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
      // Gemini 2.5 Flash Image (gemini-2.5-flash-image) is the dedicated image
      // generation model. It uses responseModalities to request both TEXT and IMAGE
      // parts in the response.
      //
      // Note: The Gemini REST API does not currently support `response_format`
      // or `aspect_ratio`/`image_size` directly in the payload for this endpoint.
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': request.prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['TEXT', 'IMAGE'],
        },
      };

      debugPrint(
          '📤 Gemini Request (Image Generation): ${jsonEncode(requestBody)}');

      final response = await _post(
        model: AppConstants.geminiImageGenModel,
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Image Generation): ${jsonEncode({
            'status': response.statusCode,
            'candidates_count': (data['candidates'] as List?)?.length,
          })}');

      // Extract base64 image from Gemini's inline_data format
      final parts = data['candidates']?[0]?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      // Find the image part — Gemini may return both text and image parts
      String? base64Image;
      String? mimeType;
      for (final part in parts) {
        if (part['inlineData'] != null) {
          base64Image = part['inlineData']['data'] as String?;
          mimeType = part['inlineData']['mimeType'] as String?;
          break;
        }
      }

      if (base64Image == null || base64Image.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      debugPrint('📥 Gemini: Image received, mimeType=$mimeType, '
          'base64Length=${base64Image.length}');

      stopwatch.stop();
      // Wrap the single base64 image in an AiImageData list for API consistency with OpenAI
      return AiResponse.imageBase64(
        modelUsed: AiProviderId.gemini,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imageBase64: base64Image,
        generatedImages: [AiImageData(b64Json: base64Image)],
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
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
      // Build the parts array for Gemini's multimodal format.
      // Images must come BEFORE the text prompt in the parts list.
      final List<Map<String, dynamic>> parts = [];

      if (request.imageBytes != null && request.imageBytes!.isNotEmpty) {
        // Add each image as an inlineData block
        for (final att in request.imageBytes!) {
          parts.add({
            'inlineData': {
              'mimeType': request.imageMimeType ?? 'image/jpeg',
              'data': base64Encode(att),
            },
          });
        }
      }

      // Add the user's text prompt as the last part
      parts.add({'text': request.prompt});

      final requestBody = {
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiVisionSystemInstruction,
            }
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.maxTokens,
          'temperature': 0.4,
        },
      };

      debugPrint('📤 Gemini Request (Image Analysis): ${jsonEncode({
            'model': AppConstants.geminiVisionModel,
            'systemInstruction': AppConstants.aiVisionSystemInstruction,
            'prompt': request.prompt,
            'image_count': request.imageBytes?.length ?? 0,
            'mimeType': request.imageMimeType,
          })}');

      final response = await _post(
        model: AppConstants.geminiVisionModel,
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Image Analysis): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final inputTokens =
          data['usageMetadata']?['promptTokenCount'] as int? ?? 0;
      final outputTokens =
          data['usageMetadata']?['candidatesTokenCount'] as int? ?? 0;
      final tokenCount = data['usageMetadata']?['totalTokenCount'] as int? ?? 0;
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;

      stopwatch.stop();
      return AiResponse.analysis(
        modelUsed: AiProviderId.gemini,
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

    try {
      // Gemini 2.5 Flash natively supports inline PDF via inlineData blocks.
      // PDFs are passed as base64-encoded application/pdf mime type.
      final List<Map<String, dynamic>> parts = [];

      final hasPdfs = request.pdfBytes != null && request.pdfBytes!.isNotEmpty;
      if (hasPdfs) {
        for (int i = 0; i < request.pdfBytes!.length; i++) {
          final base64Data = base64Encode(request.pdfBytes![i]);
          parts.add({
            'inlineData': {
              'mimeType': 'application/pdf',
              'data': base64Data,
            },
          });
        }
      }
      // Text prompt comes after the PDF attachments
      parts.add({'text': request.prompt});

      final requestBody = {
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiPdfSystemInstruction,
            }
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.maxTokens,
          'temperature': 0.3,
        },
      };

      debugPrint('📤 Gemini Request (PDF Parsing): ${jsonEncode({
            'model': AppConstants.geminiVisionModel,
            'systemInstruction': AppConstants.aiPdfSystemInstruction,
            'prompt': request.prompt,
            'pdf_count': request.pdfBytes?.length ?? 0,
            'pdf_names': request.pdfNames,
          })}');

      // Use vision model for PDF (it has the multimodal context window)
      final response = await _post(
        model: AppConstants.geminiVisionModel,
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (PDF Parsing): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final inputTokens =
          data['usageMetadata']?['promptTokenCount'] as int? ?? 0;
      final outputTokens =
          data['usageMetadata']?['candidatesTokenCount'] as int? ?? 0;
      final tokenCount = data['usageMetadata']?['totalTokenCount'] as int? ?? 0;
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;

      stopwatch.stop();
      return AiResponse.analysis(
        modelUsed: AiProviderId.gemini,
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
      throw _mapError(e);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Make an authenticated POST request to the Gemini Generative Language API.
  ///
  /// Gemini supports two authentication methods simultaneously:
  /// - `?key=` query parameter (required)
  /// - `x-goog-api-key` header (recommended for security)
  Future<http.Response> _post({
    required String model,
    required String apiKey,
    required Map<String, dynamic> body,
  }) {
    debugPrint('🔷 Gemini request: $model');
    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$model:generateContent',
    );
    return _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
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
        '🔷 Gemini [${response.request?.url.path}]: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bodyString = response.body;
      // Offload heavy JSON parsing to a background isolate.
      // For large responses (like base64 images), decoding on the
      // main thread would cause severe UI stuttering and frozen frames.
      return await Isolate.run(
          () => jsonDecode(bodyString) as Map<String, dynamic>);
    }

    debugPrint('🔷 Gemini error body: ${response.body}');

    // Gemini returns 400 for both invalid API keys and malformed requests.
    // Inspect the body to differentiate between them.
    if (response.statusCode == 400) {
      final bodyString = response.body;
      final body = await Isolate.run(
          () => jsonDecode(bodyString) as Map<String, dynamic>?);
      final message = body?['error']?['message'] as String? ?? '';
      if (message.toLowerCase().contains('api key') ||
          message.toLowerCase().contains('invalid')) {
        throw const AiHardErrorException(
          message: 'error_invalid_key',
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
  ///
  /// Gemini response: candidates[0].content.parts[].text
  String _extractTextFromResponse(Map<String, dynamic> data) {
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    return parts
        .whereType<Map>()
        .map((part) => part['text'] as String? ?? '')
        .join('');
  }

  /// Map non-HTTP errors (network, timeout, etc.) to typed AiException.
  AiException _mapError(Object error) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'no_internet_connection',
        provider: AiProviderId.gemini,
      );
    }
    if (error is http.ClientException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
        provider: AiProviderId.gemini,
      );
    }
    return const AiTransientException(
      message: 'error_unexpected_ai',
      provider: AiProviderId.gemini,
    );
  }
}
