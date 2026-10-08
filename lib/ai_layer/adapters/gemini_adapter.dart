import 'dart:async';
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
///   textGeneration     → POST /v1beta/models/gemini-3.5-flash-lite:generateContent
///   imageGeneration    → POST /v1beta/models/gemini-3.1-flash-lite-image:generateContent
///   imageUnderstanding → POST /v1beta/models/gemini-3.5-flash-lite:generateContent (multimodal)
///   pdfParsing         → POST /v1beta/models/gemini-3.5-flash-lite:generateContent (inline PDF)
///
/// Authentication: API key passed as x-goog-api-key header.
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

      final thinkingLevel = request.thinkingLevel?.apiValue ??
          (request.disableSearchGrounding
              ? GeminiThinkingLevel.low.apiValue
              : GeminiThinkingLevel.medium.apiValue);

      final requestBody = {
        // System instruction — only attach default persona if not a specialized/internal prompt
        if (!request.disableSearchGrounding)
          'systemInstruction': {
            'parts': [
              {
                'text': AppConstants.aiTextSystemInstruction,
              }
            ]
          },
        'contents': contents,
        // Google Search Grounding: provides real-time web access and live citations
        if (!request.disableSearchGrounding)
          'tools': [
            {'googleSearch': {}}
          ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.geminiMaxTokens,
          // Gemini 3.8 Flash replaces temperature/thinking_budget with thinkingLevel:
          // 'low', 'medium', or 'high'. Note: 'minimal' is not supported on 3.8 Flash.
          'thinkingConfig': {
            'thinkingLevel': thinkingLevel,
          },
        },
      };

      debugPrint('📤 Gemini Request (Text Generation): ${jsonEncode({
            'model': AppConstants.geminiTextModel,
            'capability': request.capability.displayName,
            'message_count': contents.length,
            'maxOutputTokens': request.responseLength.geminiMaxTokens,
            'thinkingLevel': thinkingLevel,
            'grounding': !request.disableSearchGrounding,
            'prompt': request.prompt,
          })}');

      final response = await _postWithFallback(
        primaryModel: AppConstants.geminiTextModel,
        fallbackModel: AppConstants.geminiFlashLiteModel,
        apiKey: apiKey,
        body: requestBody,
      );

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Text Generation): ${jsonEncode(data)}');

      final finishReason = data['candidates']?[0]?['finishReason'] as String?;

      final text = _extractTextFromResponse(data);
      if (text.isEmpty) {
        if (finishReason == 'SAFETY') {
          throw const AiHardErrorException(
            message: 'error_safety_violation',
            provider: AiProviderId.gemini,
          );
        }
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      final tokens = _extractTokenUsage(data);
      debugPrint(
          '📊 Gemini Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');

      stopwatch.stop();
      return AiResponse.text(
        requestId: request.requestId,
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.textGeneration,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
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
      // gemini-3.1-flash-lite-image is the dedicated image generation model.
      // It uses responseModalities to request both TEXT and IMAGE parts in the response.
      // imageConfig specifies the desired shape (aspectRatio) — e.g. 1:1, 16:9, 9:16.
      final aspectRatio = request.geminiAspectRatio?.apiValue ?? '1:1';

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
          'imageConfig': {
            'aspectRatio': aspectRatio,
          },
        },
      };

      debugPrint('📤 Gemini Request (Image Generation): ${jsonEncode({
            'model': AppConstants.geminiImageGenModel,
            'capability': request.capability.displayName,
            'message_count': request.conversationHistory.length + 1,
            'prompt': request.prompt,
            'aspectRatio': aspectRatio,
          })}');

      var response = await _post(
        model: AppConstants.geminiImageGenModel,
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      // Defensive fallback: If imageConfig is rejected by a tier or regional endpoint, retry without it
      if (response.statusCode == 400 &&
          (requestBody['generationConfig'] as Map<String, dynamic>?)
                  ?.containsKey('imageConfig') ==
              true) {
        final bodyStr = response.body.toLowerCase();
        if (bodyStr.contains('imageconfig') ||
            bodyStr.contains('aspectratio')) {
          debugPrint(
              '⚠️ Gemini: imageConfig rejected by endpoint, retrying without imageConfig');
          final genConfig = Map<String, dynamic>.from(
              requestBody['generationConfig'] as Map<String, dynamic>)
            ..remove('imageConfig');
          final fallbackBody = Map<String, dynamic>.from(requestBody)
            ..['generationConfig'] = genConfig;
          response = await _post(
            model: AppConstants.geminiImageGenModel,
            apiKey: apiKey,
            body: fallbackBody,
          ).timeout(AppConstants.aiRequestTimeout);
        }
      }

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Image Generation): ${jsonEncode(data)}');

      final finishReason = data['candidates']?[0]?['finishReason'] as String?;

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
      for (final part in parts) {
        if (part['inlineData'] != null) {
          base64Image = part['inlineData']['data'] as String?;
          break;
        }
      }

      if (base64Image == null || base64Image.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      // debugPrint('📥 Gemini: Image received, mimeType=$mimeType, '
      //     'base64Length=${base64Image.length}');

      final tokens = _extractTokenUsage(data);

      debugPrint(
          '📊 Gemini Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');

      stopwatch.stop();
      return AiResponse.image(
        modelUsed: AiProviderId.gemini,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imageBase64: base64Image,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
        finishReason: finishReason ?? 'STOP',
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

      int totalImageBytes = 0;
      if (request.imageBytes != null && request.imageBytes!.isNotEmpty) {
        // Add each image as an inlineData block
        for (final att in request.imageBytes!) {
          if (att.lengthInBytes > AppConstants.maxImageSizeBytes) {
            throw const AiHardErrorException(
              provider: AiProviderId.gemini,
              message: 'error_image_too_large',
            );
          }
          totalImageBytes += att.lengthInBytes;
          parts.add({
            'inlineData': {
              'mimeType': request.imageMimeType ?? 'image/jpeg',
              'data': base64Encode(att),
            },
          });
        }
      }

      if (totalImageBytes > AppConstants.maxImageCombinedSizeBytes) {
        throw const AiHardErrorException(
          provider: AiProviderId.gemini,
          message: 'image_payload_too_large',
        );
      }

      // Add the user's text prompt as the last part
      parts.add({'text': request.prompt});

      final thinkingLevel = request.thinkingLevel?.apiValue ??
          GeminiThinkingLevel.medium.apiValue;

      final requestBody = {
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiVisionSystemInstruction,
            }
          ]
        },
        'contents': [
          // Include previous conversation turns for multi-turn visual context
          ...request.conversationHistory.map((msg) => {
                'role': msg['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': msg['content'] ?? ''},
                ],
              }),
          // Current user turn with attached image(s) and prompt
          {
            'role': 'user',
            'parts': parts,
          },
        ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.geminiMaxTokens,
          'thinkingConfig': {
            'thinkingLevel': thinkingLevel,
          },
        },
      };

      debugPrint('📤 Gemini Request (Image Analysis): ${jsonEncode({
            'model': AppConstants.geminiVisionModel,
            'request_capability': request.capability.displayName,
            'image_count': request.imageBytes?.length ?? 0,
            'message_count': request.conversationHistory.length + 1,
            'mimeType': request.imageMimeType,
            'maxOutputTokens': request.responseLength.geminiMaxTokens,
            'thinkingLevel': thinkingLevel,
            'prompt': request.prompt,
          })}');

      final response = await _postWithFallback(
        primaryModel: AppConstants.geminiVisionModel,
        fallbackModel: AppConstants.geminiFlashLiteModel,
        apiKey: apiKey,
        body: requestBody,
      );

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (Image Analysis): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;
      final tokens = _extractTokenUsage(data);
      debugPrint(
          '📊 Gemini Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.imageUnderstanding,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
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
      // Gemini natively supports inline PDF via inlineData blocks.
      // PDFs are passed as base64-encoded application/pdf mime type.
      final List<Map<String, dynamic>> parts = [];

      final hasPdfs = request.pdfBytes != null && request.pdfBytes!.isNotEmpty;
      int totalPdfBytes = 0;
      if (hasPdfs) {
        for (int i = 0; i < request.pdfBytes!.length; i++) {
          final fileBytes = request.pdfBytes![i];
          totalPdfBytes += fileBytes.lengthInBytes;
          if (fileBytes.lengthInBytes > AppConstants.maxPdfSizeBytes) {
            throw const AiHardErrorException(
              message: 'pdf_too_large',
              provider: AiProviderId.gemini,
            );
          }
          final base64Data = base64Encode(fileBytes);
          parts.add({
            'inlineData': {
              'mimeType': 'application/pdf',
              'data': base64Data,
            },
          });
        }
      }

      if (totalPdfBytes > AppConstants.maxPdfCombinedSizeBytes) {
        throw const AiHardErrorException(
          message: 'pdf_payload_too_large',
          provider: AiProviderId.gemini,
        );
      }

      // Text prompt comes after the PDF attachments
      parts.add({'text': request.prompt});

      final thinkingLevel = request.thinkingLevel?.apiValue ??
          GeminiThinkingLevel.medium.apiValue;

      final requestBody = {
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiPdfSystemInstruction,
            }
          ]
        },
        'contents': [
          // Include previous conversation history for multi-turn PDF context
          ...request.conversationHistory.map((msg) => {
                'role': msg['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': msg['content'] ?? ''},
                ],
              }),
          // Current user turn with attached PDF(s) and prompt
          {
            'role': 'user',
            'parts': parts,
          },
        ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.geminiMaxTokens,
          'thinkingConfig': {
            'thinkingLevel': thinkingLevel,
          },
        },
      };

      debugPrint('📤 Gemini Request (PDF Parsing): ${jsonEncode({
            'model': AppConstants.geminiVisionModel,
            'pdf_count': request.pdfBytes?.length ?? 0,
            'pdf_names': request.pdfNames,
            'message_count': request.conversationHistory.length + 1,
            'maxOutputTokens': request.responseLength.geminiMaxTokens,
            'thinkingLevel': thinkingLevel,
            'prompt': request.prompt,
          })}');

      // Use vision model for PDF (gemini-3.8-flash has the 1M multimodal context window)
      final response = await _postWithFallback(
        primaryModel: AppConstants.geminiVisionModel,
        fallbackModel: AppConstants.geminiFlashLiteModel,
        apiKey: apiKey,
        body: requestBody,
      );

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Gemini Response (PDF Parsing): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final tokens = _extractTokenUsage(data);
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;
      debugPrint(
          '📊 Gemini Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.pdfParsing,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
        finishReason: finishReason,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AiResponse> generatePdf({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final List<Map<String, dynamic>> contents = [
        ...request.conversationHistory.map((msg) => {
              'role': msg['role'] == 'user' ? 'user' : 'model',
              'parts': [
                {'text': msg['content'] ?? ''},
              ],
            }),
        {
          'role': 'user',
          'parts': [
            {'text': request.prompt},
          ],
        },
      ];

      final thinkingLevel = request.thinkingLevel?.apiValue ??
          GeminiThinkingLevel.medium.apiValue;

      final requestBody = {
        'systemInstruction': {
          'parts': [
            {
              'text': AppConstants.aiPdfGenerationSystemInstruction,
            }
          ]
        },
        'contents': contents,
        if (!request.disableSearchGrounding)
          'tools': [
            {'googleSearch': {}}
          ],
        'generationConfig': {
          'maxOutputTokens': request.responseLength.geminiMaxTokens,
          'thinkingConfig': {
            'thinkingLevel': thinkingLevel,
          },
        },
      };

      debugPrint('📤 Gemini Request (PDF Generation): ${jsonEncode({
            'model': AppConstants.geminiTextModel,
            'capability': request.capability.displayName,
            'message_count': contents.length,
            'maxOutputTokens': request.responseLength.geminiMaxTokens,
            'thinkingLevel': thinkingLevel,
            'grounding': !request.disableSearchGrounding,
            'prompt': request.prompt,
          })}');

      final response = await _postWithFallback(
        primaryModel: AppConstants.geminiTextModel,
        fallbackModel: AppConstants.geminiFlashLiteModel,
        apiKey: apiKey,
        body: requestBody,
      );

      final data = await _parseResponse(response, request.requestId);
      // debugPrint('📥 Gemini Response (PDF Generation): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      if (text.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.gemini,
        );
      }

      final tokens = _extractTokenUsage(data);
      final finishReason = data['candidates']?[0]?['finishReason'] as String?;
      debugPrint(
          '📊 Gemini Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.gemini,
        capability: AiCapability.pdfGeneration,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
        finishReason: finishReason,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// POSTs a request with automatic fallbacks:
  /// 1. 404 Fallback: Tries [fallbackModel] if [primaryModel] is not found.
  /// 2. Parameter Sanitization Fallbacks (HTTP 400):
  ///    - If 'tools' (Google Search) is unsupported on the key tier/region, strips 'tools' and retries.
  ///    - If 'thinkingConfig' is unsupported on the endpoint, strips 'thinkingConfig' and retries.
  Future<http.Response> _postWithFallback({
    required String primaryModel,
    String? fallbackModel,
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    Map<String, dynamic> currentBody = Map<String, dynamic>.from(body);

    http.Response response = await _sendWithModelFallback(
      primaryModel: primaryModel,
      fallbackModel: fallbackModel,
      apiKey: apiKey,
      body: currentBody,
    );

    // Parameter Fallback 1: Retry without 'tools' if rejected by key tier or endpoint
    if (response.statusCode == 400 && currentBody.containsKey('tools')) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('tool') ||
          bodyLower.contains('search') ||
          bodyLower.contains('googlesearch')) {
        debugPrint(
            '⚠️ Gemini: tools unsupported on this key tier, retrying without tools');
        currentBody = Map<String, dynamic>.from(currentBody)..remove('tools');
        response = await _sendWithModelFallback(
          primaryModel: primaryModel,
          fallbackModel: fallbackModel,
          apiKey: apiKey,
          body: currentBody,
        );
      }
    }

    // Parameter Fallback 2: Retry without 'thinkingConfig' if rejected by endpoint
    if (response.statusCode == 400 &&
        currentBody['generationConfig'] is Map &&
        (currentBody['generationConfig'] as Map)
            .containsKey('thinkingConfig')) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('thinking') ||
          bodyLower.contains('thinkinglevel')) {
        debugPrint(
            '⚠️ Gemini: thinkingConfig rejected by endpoint, retrying without thinkingConfig');
        final genConfig = Map<String, dynamic>.from(
            currentBody['generationConfig'] as Map<String, dynamic>)
          ..remove('thinkingConfig');
        currentBody = Map<String, dynamic>.from(currentBody)
          ..['generationConfig'] = genConfig;
        response = await _sendWithModelFallback(
          primaryModel: primaryModel,
          fallbackModel: fallbackModel,
          apiKey: apiKey,
          body: currentBody,
        );
      }
    }

    return response;
  }

  /// Sends a POST request, falling back to [fallbackModel] if [primaryModel] returns 404.
  Future<http.Response> _sendWithModelFallback({
    required String primaryModel,
    String? fallbackModel,
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    final response = await _post(
      model: primaryModel,
      apiKey: apiKey,
      body: body,
    ).timeout(AppConstants.aiRequestTimeout);

    if (response.statusCode == 404 &&
        fallbackModel != null &&
        fallbackModel.isNotEmpty &&
        fallbackModel != primaryModel) {
      debugPrint(
          '⚠️ Gemini: Primary model $primaryModel returned 404. Falling back to $fallbackModel.');
      return await _post(
        model: fallbackModel,
        apiKey: apiKey,
        body: body,
      ).timeout(AppConstants.aiRequestTimeout);
    }

    return response;
  }

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
    if (response.statusCode == 200) {
      final bodyString = response.body;
      // Offload heavy JSON parsing to a background isolate.
      // For large responses (like base64 images), decoding on the
      // main thread would cause severe UI stuttering and frozen frames.
      return await Isolate.run(
          () => jsonDecode(bodyString) as Map<String, dynamic>);
    }

    // Gemini returns 413 or 400 when payload limits are exceeded.
    if (response.statusCode == 413) {
      throw const AiHardErrorException(
        message: 'pdf_payload_too_large',
        provider: AiProviderId.gemini,
        statusCode: 413,
      );
    }

    // Gemini returns 400 for invalid API keys, malformed requests, and payload size errors.
    // Inspect the body to differentiate between them without risking unhandled FormatException.
    if (response.statusCode == 400) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('api key') ||
          bodyLower.contains('api_key') ||
          bodyLower.contains('invalid')) {
        throw const AiHardErrorException(
          message: 'error_invalid_key',
          provider: AiProviderId.gemini,
          statusCode: 400,
        );
      }
      if (bodyLower.contains('payload size') ||
          bodyLower.contains('request entity too large') ||
          bodyLower.contains('exceeds the limit')) {
        throw const AiHardErrorException(
          message: 'pdf_payload_too_large',
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
  /// Automatically parses and appends Google Search Grounding sources if present.
  String _extractTextFromResponse(Map<String, dynamic> data) {
    final candidate = data['candidates']?[0];
    final parts = candidate?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    String text = parts
        .whereType<Map>()
        .map((part) => part['text'] as String? ?? '')
        .join('');

    // If Google Search Grounding was triggered, extract and append web sources
    final groundingMetadata =
        candidate?['groundingMetadata'] as Map<String, dynamic>?;
    if (groundingMetadata != null && text.isNotEmpty) {
      final chunks = groundingMetadata['groundingChunks'] as List?;
      if (chunks != null && chunks.isNotEmpty) {
        final sources = <String>[];
        for (final chunk in chunks) {
          if (chunk is Map && chunk['web'] is Map) {
            final web = chunk['web'] as Map;
            final title = web['title'] as String? ?? 'Source';
            final uri = web['uri'] as String? ?? '';
            if (uri.isNotEmpty && !sources.any((s) => s.contains(uri))) {
              sources.add('* [$title]($uri)');
            }
          }
        }
        if (sources.isNotEmpty) {
          text += '\n\n**Sources:**\n${sources.take(3).join('\n')}';
        }
      }
    }

    return text;
  }

  /// Extracts token usage from Gemini's usageMetadata object.
  ///
  /// Flow and calculation:
  /// - [promptTokenCount]: Input tokens consumed by prompt, history, and media attachments.
  /// - [candidatesTokenCount]: Output tokens produced in the model's textual response.
  /// - [thoughtsTokenCount]: Output tokens produced during chain-of-thought thinking (Gemini 3.8).
  /// - Total output tokens = candidatesTokenCount + thoughtsTokenCount.
  /// - If [totalTokenCount] is omitted in response metadata, computes inputTokens + outputTokens.
  _GeminiTokenUsage _extractTokenUsage(Map<String, dynamic> data) {
    final metadata = data['usageMetadata'] as Map<String, dynamic>?;
    final inputTokens = metadata?['promptTokenCount'] as int? ?? 0;
    final candidatesTokens = metadata?['candidatesTokenCount'] as int? ?? 0;
    final thoughtsTokens = metadata?['thoughtsTokenCount'] as int? ?? 0;
    final outputTokens = candidatesTokens + thoughtsTokens;
    final rawTotalTokens = metadata?['totalTokenCount'] as int? ?? 0;
    final totalTokens =
        rawTotalTokens > 0 ? rawTotalTokens : (inputTokens + outputTokens);

    return _GeminiTokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
    );
  }

  /// Maps non-HTTP runtime errors (network disconnections, HTTP timeouts) to typed [AiException].
  ///
  /// Flow:
  /// - [SocketException]: Device disconnected or network unreachable -> 'no_internet_connection'.
  /// - [TimeoutException]: Exceeded 90s request timeout -> transient retryable.
  /// - [http.ClientException] / generic -> transient 'error_unexpected_ai'.
  AiException _mapError(Object error) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'no_internet_connection',
        provider: AiProviderId.gemini,
      );
    }
    if (error is TimeoutException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
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

/// Internal immutable value object holding normalized token usage counters for Gemini.
class _GeminiTokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const _GeminiTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });
}
