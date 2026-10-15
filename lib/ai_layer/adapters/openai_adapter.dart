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

/// OpenAI provider adapter for AI Voice Genie.
///
/// Implements all four capabilities using OpenAI's REST API:
///   textGeneration    → POST /v1/chat/completions (gpt-6-luna)
///   imageGeneration   → POST /v1/images/generations (gpt-image-2.5-flare)
///   imageUnderstanding → POST /v1/chat/completions with image_url (gpt-6-luna)
///   pdfParsing        → POST /v1/responses with inline PDF (gpt-6-luna)
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
        // System prompt — only attach default persona if not a specialized/internal prompt
        if (!request.disableSearchGrounding)
          {
            'role': 'system',
            'content': AppConstants.aiTextSystemInstruction,
          },
        // Include previous conversation messages for context
        ...request.conversationHistory,
        // The current user prompt
        {'role': 'user', 'content': request.prompt},
      ];

      final requestBody = <String, dynamic>{
        'model': AppConstants.openAiTextModel,
        'max_completion_tokens': request.responseLength.openAiMaxTokens,
        'messages': messages,
        // Web Search Grounding: provides real-time web access and live citations
        if (!request.disableSearchGrounding) 'web_search_options': {},
      };

      debugPrint('📤 OpenAI Request (Text Generation): ${jsonEncode({
            'model': AppConstants.openAiTextModel,
            'capability': request.capability.displayName,
            'message_count': messages.length,
            'max_completion_tokens': request.responseLength.openAiMaxTokens,
            'grounding': !request.disableSearchGrounding,
            'prompt': request.prompt,
          })}');

      final response = await _postWithFallback(
        apiKey: apiKey,
        body: requestBody,
      );

      final data = await _parseResponse(response, request.requestId);

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      final messageContent = choices[0]['message']?['content'];
      String text = '';
      if (messageContent is String) {
        text = messageContent;
      } else if (messageContent is List) {
        text = messageContent
            .map((part) => part is Map ? (part['text'] ?? '') : part.toString())
            .join('');
      }
      final finishReason = choices[0]['finish_reason'] as String?;

      if (text.isEmpty) {
        if (finishReason == 'content_filter') {
          throw const AiHardErrorException(
            message: 'error_safety_violation',
            provider: AiProviderId.openAi,
          );
        }
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      final tokens = _extractTokenUsage(data);

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (Text Generation): ${jsonEncode(data)}');
      debugPrint(
          '📊 OpenAI Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
        capability: AiCapability.textGeneration,
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
            (request.imageBackground ?? ImageGenerateBackground.auto).apiValue,
        'prompt': request.prompt,
      };
      debugPrint('📤 OpenAI Request (Image Generation): ${jsonEncode({
            'model': AppConstants.openAiImageGenModel,
            'capability': request.capability.displayName,
            'size': request.imageSize?.apiValue ?? AiImageSize.square.apiValue,
            'quality': request.imageQuality?.name ?? ImageQuality.low.name,
            'n': request.imageCount ?? 1,
            'background':
                (request.imageBackground ?? ImageGenerateBackground.auto)
                    .apiValue,
            'prompt': request.prompt,
          })}');

      final response = await _post(
        endpoint: '/images/generations',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);

      final List<String> imagesBase64 = (data['data'] as List<dynamic>? ?? [])
          .map((e) =>
              (e is Map<String, dynamic>) ? e['b64_json'] as String? : null)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();

      if (imagesBase64.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

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
      final tokens = _extractTokenUsage(data);

      debugPrint(
          '📥 OpenAI Response (Image Generation): ${jsonEncode(logData)}');
      debugPrint(
          '📊 OpenAI Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');
      return AiResponse.image(
        modelUsed: AiProviderId.openAi,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        imagesBase64: imagesBase64,
        inputTokens: tokens.inputTokens,
        outputTokens: tokens.outputTokens,
        tokenCount: tokens.totalTokens,
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
              'detail': request.visionDetailLevel?.apiValue ??
                  VisionDetailLevel.auto.apiValue,
            },
          });
        }
      }

      final requestBody = {
        // gpt-6-luna natively supports multi-image vision
        'model': AppConstants.openAiVisionModel,
        'max_completion_tokens': request.responseLength.openAiMaxTokens,
        'messages': [
          {
            'role': 'system',
            'content': AppConstants.aiVisionSystemInstruction,
          },
          // Include previous conversation history for multi-turn visual discussions
          ...request.conversationHistory,
          {
            'role': 'user',
            'content': contentParts,
          },
        ],
      };

      debugPrint('📤 OpenAI Request (Image Analysis): ${jsonEncode({
            'model': AppConstants.openAiVisionModel,
            'capability': request.capability.displayName,
            'image_count': request.imageBytes?.length ?? 0,
            'detail': request.visionDetailLevel?.apiValue ??
                VisionDetailLevel.auto.apiValue,
            'message_count': request.conversationHistory.length + 1,
            'prompt': request.prompt,
          })}');

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
      final tokens = _extractTokenUsage(data);
      final finishReason = choices[0]['finish_reason'] as String?;

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (Image Analysis): ${jsonEncode(data)}');
      debugPrint(
          '📊 OpenAI Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');
      return AiResponse.analysis(
        modelUsed: AiProviderId.openAi,
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
        // gpt-6-luna supports native PDF reading in the Responses API
        'model': AppConstants.openAiVisionModel,
        'instructions': AppConstants.aiPdfSystemInstruction,
        'max_output_tokens': request.responseLength.openAiMaxTokens,
        'input': [
          // Include previous conversation history for multi-turn PDF context
          ...request.conversationHistory,
          {
            'role': 'user',
            'content': contentParts,
          },
        ],
      };

      debugPrint('📤 OpenAI Request (PDF Parsing): ${jsonEncode({
            'model': AppConstants.openAiVisionModel,
            'capability': request.capability.displayName,
            'pdf_count': request.pdfBytes?.length ?? 1,
            'prompt': request.prompt,
          })}');

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

      final tokens = _extractTokenUsage(data);

      stopwatch.stop();
      debugPrint('📥 OpenAI Response (PDF Parsing): ${jsonEncode(data)}');
      debugPrint(
          '📊 OpenAI Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');
      return AiResponse.analysis(
        modelUsed: AiProviderId.openAi,
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
      throw _mapError(e, request.requestId);
    }
  }

  @override
  Future<AiResponse> generatePdf({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final messages = [
        {
          'role': 'system',
          'content': AppConstants.aiPdfGenerationSystemInstruction,
        },
        ...request.conversationHistory,
        {
          'role': 'user',
          'content': request.prompt,
        },
      ];

      final requestBody = {
        'model': AppConstants.openAiTextModel,
        'messages': messages,
        'max_completion_tokens': request.responseLength.openAiMaxTokens,
      };

      debugPrint('📤 OpenAI Request (PDF Generation): ${jsonEncode({
            'model': AppConstants.openAiTextModel,
            'max_completion_tokens': request.responseLength.openAiMaxTokens,
            'prompt': request.prompt,
          })}');

      final response = await _post(
        endpoint: '/chat/completions',
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 OpenAI Response (PDF Generation): ${jsonEncode(data)}');

      final text = data['choices']?[0]?['message']?['content'] as String? ?? '';
      if (text.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.openAi,
        );
      }

      final tokens = _extractTokenUsage(data);
      final finishReason = data['choices']?[0]?['finish_reason'] as String?;

      stopwatch.stop();
      debugPrint(
          '📊 OpenAI Tokens: input=${tokens.inputTokens}, output=${tokens.outputTokens}, total=${tokens.totalTokens}');
      return AiResponse.text(
        modelUsed: AiProviderId.openAi,
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
      throw _mapError(e, request.requestId);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Sends a POST request for text generation with intelligent parameter fallbacks.
  ///
  /// Flow:
  /// 1. Attempts request with 'web_search_options' for real-time web search grounding.
  /// 2. If rejected with 400 (parameter unsupported), retries with 'tools: [{"type": "web_search"}]'.
  /// 3. If tools web search is also rejected by the API tier or model, retries clean without web search
  ///    so the chat interaction never fails or crashes for the user.
  Future<http.Response> _postWithFallback({
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    Map<String, dynamic> currentBody = Map<String, dynamic>.from(body);

    http.Response response = await _post(
      endpoint: '/chat/completions',
      apiKey: apiKey,
      body: currentBody,
    ).timeout(AppConstants.aiRequestTimeout);

    // Parameter Fallback 1: Retry with 'tools: [{"type": "web_search"}]' if 'web_search_options' is rejected
    if (response.statusCode == 400 &&
        currentBody.containsKey('web_search_options')) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('web_search') ||
          bodyLower.contains('search') ||
          bodyLower.contains('unknown parameter') ||
          bodyLower.contains('unrecognized') ||
          bodyLower.contains('invalid') ||
          bodyLower.contains('tool')) {
        debugPrint(
            '⚠️ OpenAI: web_search_options rejected by endpoint, retrying with tools web_search');
        currentBody = Map<String, dynamic>.from(currentBody)
          ..remove('web_search_options')
          ..['tools'] = [
            {'type': 'web_search'}
          ];

        response = await _post(
          endpoint: '/chat/completions',
          apiKey: apiKey,
          body: currentBody,
        ).timeout(AppConstants.aiRequestTimeout);

        // Parameter Fallback 2: Retry without web search tools if also rejected by key tier or model
        if (response.statusCode == 400 && currentBody.containsKey('tools')) {
          final secondBodyLower = response.body.toLowerCase();
          if (secondBodyLower.contains('tool') ||
              secondBodyLower.contains('search') ||
              secondBodyLower.contains('web_search') ||
              secondBodyLower.contains('unknown parameter') ||
              secondBodyLower.contains('unrecognized') ||
              secondBodyLower.contains('invalid')) {
            debugPrint(
                '⚠️ OpenAI: web search tools unsupported on this key tier/model, retrying without web search');
            currentBody = Map<String, dynamic>.from(currentBody)
              ..remove('tools');
            response = await _post(
              endpoint: '/chat/completions',
              apiKey: apiKey,
              body: currentBody,
            ).timeout(AppConstants.aiRequestTimeout);
          }
        }
      }
    } else if (response.statusCode == 400 && currentBody.containsKey('tools')) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('tool') ||
          bodyLower.contains('search') ||
          bodyLower.contains('web_search') ||
          bodyLower.contains('unknown parameter') ||
          bodyLower.contains('unrecognized') ||
          bodyLower.contains('invalid')) {
        debugPrint(
            '⚠️ OpenAI: web search tools unsupported on this key tier/model, retrying without web search');
        currentBody = Map<String, dynamic>.from(currentBody)..remove('tools');
        response = await _post(
          endpoint: '/chat/completions',
          apiKey: apiKey,
          body: currentBody,
        ).timeout(AppConstants.aiRequestTimeout);
      }
    }

    return response;
  }

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

  /// Extracts token usage from OpenAI's usage metadata.
  ///
  /// Flow and compatibility:
  /// Handles Chat Completions API naming conventions (prompt_tokens / completion_tokens)
  /// as well as Images/Responses API naming conventions (input_tokens / output_tokens).
  /// If total_tokens is omitted, computes inputTokens + outputTokens dynamically.
  _OpenAiTokenUsage _extractTokenUsage(Map<String, dynamic> data) {
    final usage = data['usage'] as Map<String, dynamic>?;
    final inputTokens =
        usage?['prompt_tokens'] as int? ?? usage?['input_tokens'] as int? ?? 0;
    final outputTokens = usage?['completion_tokens'] as int? ??
        usage?['output_tokens'] as int? ??
        0;
    final totalTokens =
        usage?['total_tokens'] as int? ?? (inputTokens + outputTokens);

    return _OpenAiTokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
    );
  }

  /// Maps non-HTTP runtime errors (network drops, HTTP timeouts, socket issues) to typed [AiException].
  ///
  /// Flow:
  /// - [SocketException]: Device offline or network routing severed -> 'no_internet_connection'.
  /// - [TimeoutException]: Request exceeded [AppConstants.aiRequestTimeout] (e.g. 90s) -> transient retryable.
  /// - [http.ClientException] or other unexpected errors -> generic transient 'error_unexpected_ai'.
  AiException _mapError(Object error, String requestId) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'no_internet_connection',
        provider: AiProviderId.openAi,
      );
    }
    if (error is TimeoutException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
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

/// Internal immutable value object holding normalized token usage counters for OpenAI.
class _OpenAiTokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const _OpenAiTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });
}
