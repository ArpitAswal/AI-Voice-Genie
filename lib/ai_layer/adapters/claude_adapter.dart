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

/// Claude provider adapter for AI Voice Genie.
///
/// Implements three capabilities using Anthropic's Messages API:
///   textGeneration     → POST /v1/messages (claude-haiku-4-5-20251001)
///   imageUnderstanding → POST /v1/messages with base64 image content block
///   pdfParsing         → POST /v1/messages with PDF document content blocks
///
/// imageGeneration is NOT supported by Claude.
/// Calling generateImage() throws UnsupportedError — this should never
/// happen because ProviderRegistry excludes Claude for imageGeneration
/// and ModelSelector filters it out before the orchestrator even reaches
/// this adapter.
///
/// Authentication: x-api-key header + anthropic-version header
/// All errors are mapped to typed AiException subclasses.
class ClaudeAdapter extends AiProviderAdapter {
  final http.Client _client;

  ClaudeAdapter({http.Client? client}) : _client = client ?? http.Client();

  @override
  AiProviderId get providerId => AiProviderId.claude;

  // ── Text Generation ────────────────────────────────────────────────────────

  @override
  Future<AiResponse> generateText({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Claude uses 'user' / 'assistant' roles — same as our MessageRole values
      final messages = [
        ...request.conversationHistory.map((msg) => {
              'role': msg['role'],
              'content': msg['content'] ?? '',
            }),
        {'role': 'user', 'content': request.prompt},
      ];

      final requestBody = {
        'model': AppConstants.claudeTextModel,
        'max_tokens': request.responseLength.claudeMaxTokens,
        'system': AppConstants.aiTextSystemInstruction,
        'messages': messages,
      };

      debugPrint(
          '📤 Claude Request (Text Generation): ${jsonEncode(requestBody)}');

      final response = await _post(
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Claude Response (Text Generation): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final tokens = _extractTokenUsage(data);
      final finishReason = data['stop_reason'] as String?;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
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
      throw _mapError(e);
    }
  }

  // ── Image Generation — NOT SUPPORTED ──────────────────────────────────────

  @override
  Future<AiResponse> generateImage({
    required AiRequest request,
    required String apiKey,
  }) {
    throw const AiCapabilityGapException(
      message: 'error_selected_model_capability_gap',
      provider: AiProviderId.claude,
      missingCapability: AiCapability.imageGeneration,
    );
  }

  // ── Image Understanding (Vision) ─────────────────────────────────────────

  @override
  Future<AiResponse> analyzeImage({
    required AiRequest request,
    required String apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Claude's multimodal format uses content blocks within a message.
      // Build the content array:
      final List<Map<String, dynamic>> contentParts = [];

      if (request.imageBytes != null) {
        // Preferred path: multi-image support
        for (final att in request.imageBytes!) {
          contentParts.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': request.imageMimeType,
              'data': base64Encode(att),
            },
          });
        }
      } else if (request.imageBytes != null && request.imageBytes!.isNotEmpty) {
        // Legacy single-image fallback
        final mimeType = request.imageMimeType ?? 'image/jpeg';
        contentParts.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mimeType,
            'data': base64Encode(request.imageBytes!.first),
          },
        });
      }

      // Add the user's text prompt
      contentParts.add({'type': 'text', 'text': request.prompt});

      final requestBody = {
        'model': AppConstants.claudeVisionModel,
        'max_tokens': request.responseLength.claudeMaxTokens,
        'system': AppConstants.aiVisionSystemInstruction,
        'messages': [
          {
            'role': 'user',
            'content': contentParts,
          },
        ],
      };

      debugPrint('📤 Claude Request (Image Analysis): ${jsonEncode({
            'model': AppConstants.claudeVisionModel,
            'system': AppConstants.aiVisionSystemInstruction,
            'prompt': request.prompt,
            'image_count': request.imageBytes?.length ?? 0,
            'max_tokens': request.responseLength.claudeMaxTokens,
          })}');

      final response = await _post(
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Claude Response (Image Analysis): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final tokens = _extractTokenUsage(data);
      final finishReason = data['stop_reason'] as String?;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
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
      final List<Map<String, dynamic>> contentParts = [];

      // 1. Native PDF support via document blocks
      if (request.pdfBytes != null && request.pdfBytes!.isNotEmpty) {
        for (final b64 in request.pdfBytes!) {
          contentParts.add({
            'type': 'document',
            'source': {
              'type': 'base64',
              'media_type': 'application/pdf',
              'data': base64Encode(b64),
            },
          });
        }
      }
      contentParts.add({'type': 'text', 'text': request.prompt});

      final body = <String, dynamic>{
        'model': AppConstants.claudeVisionModel,
        'max_tokens': request.responseLength.claudeMaxTokens,
        'system': AppConstants.aiPdfSystemInstruction,
        'messages': [
          {'role': 'user', 'content': contentParts},
        ],
      };

      debugPrint('📤 Claude Request (PDF Parsing): ${jsonEncode({
            'model': AppConstants.claudeVisionModel,
            'system': AppConstants.aiPdfSystemInstruction,
            'prompt': request.prompt,
            'pdf_count': request.pdfBytes?.length ?? 0,
            'max_tokens': request.responseLength.claudeMaxTokens,
          })}');

      final response = await _post(
        apiKey: apiKey,
        body: body,
        extraHeaders: const {'anthropic-beta': 'pdfs-2024-09-25'},
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Claude Response (PDF Parsing): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      final tokens = _extractTokenUsage(data);
      final finishReason = data['stop_reason'] as String?;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
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
      final messages = [
        ...request.conversationHistory.map((msg) => {
              'role': msg['role'],
              'content': msg['content'] ?? '',
            }),
        {
          'role': 'user',
          'content': request.prompt,
        },
      ];

      final requestBody = {
        'model': AppConstants.claudeTextModel,
        'max_tokens': request.responseLength.claudeMaxTokens,
        'system': AppConstants.aiPdfGenerationSystemInstruction,
        'messages': messages,
      };

      debugPrint('📤 Claude Request (PDF Generation): ${jsonEncode({
            'model': AppConstants.claudeTextModel,
            'max_tokens': request.responseLength.claudeMaxTokens,
            'prompt': request.prompt,
          })}');

      final response = await _post(
        apiKey: apiKey,
        body: requestBody,
      ).timeout(AppConstants.aiRequestTimeout);

      final data = await _parseResponse(response, request.requestId);
      debugPrint('📥 Claude Response (PDF Generation): ${jsonEncode(data)}');

      final text = _extractTextFromResponse(data);
      if (text.isEmpty) {
        throw const AiTransientException(
          message: 'error_unexpected_ai',
          provider: AiProviderId.claude,
        );
      }

      final tokens = _extractTokenUsage(data);
      final finishReason = data['stop_reason'] as String?;

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
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

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Make an authenticated POST request to the Claude Messages API.
  Future<http.Response> _post({
    required String apiKey,
    required Map<String, dynamic> body,
    Map<String, String>? extraHeaders,
  }) {
    return _client.post(
      Uri.parse('${AppConstants.claudeBaseUrl}/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': AppConstants.claudeApiVersion,
        'content-type': 'application/json',
        if (extraHeaders != null) ...extraHeaders,
      },
      body: jsonEncode(body),
    );
  }

  /// Parse HTTP response and map to typed AiExceptions.
  Future<Map<String, dynamic>> _parseResponse(
    http.Response response,
    String requestId,
  ) async {
    debugPrint('🟠 Claude: ${response.statusCode}');

    if (response.statusCode == 200) {
      final bodyString = response.body;
      // Offload heavy JSON parsing to a background isolate.
      // For large responses (like multiple base64 images), decoding on the
      // main thread would cause severe UI stuttering and frozen frames.
      return await Isolate.run(
          () => jsonDecode(bodyString) as Map<String, dynamic>);
    }

    throw mapHttpErrorToAiException(
      statusCode: response.statusCode,
      provider: AiProviderId.claude,
      rawMessage: response.body,
    );
  }

  /// Extracts text content blocks from Claude's Messages API response.
  ///
  /// Flow:
  /// Claude returns an array of content blocks: [{'type': 'text', 'text': '...'}].
  /// Filters for text blocks and concatenates their strings into a unified output.
  String _extractTextFromResponse(Map<String, dynamic> data) {
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) return '';
    return content
        .whereType<Map>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String? ?? '')
        .join('');
  }

  /// Extracts input, output, and total token usage from Claude's usage metadata.
  _ClaudeTokenUsage _extractTokenUsage(Map<String, dynamic> data) {
    final usage = data['usage'] as Map<String, dynamic>?;
    final inputTokens = usage?['input_tokens'] as int? ?? 0;
    final outputTokens = usage?['output_tokens'] as int? ?? 0;
    return _ClaudeTokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
    );
  }

  /// Maps non-HTTP runtime errors (network connection drops, HTTP timeouts) to typed [AiException].
  ///
  /// Flow:
  /// - [SocketException]: Device disconnected or network unreachable -> 'no_internet_connection'.
  /// - [TimeoutException]: Exceeded 90s timeout -> transient retryable.
  /// - [http.ClientException] / generic -> transient 'error_unexpected_ai'.
  AiException _mapError(Object error) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'no_internet_connection',
        provider: AiProviderId.claude,
      );
    }
    if (error is TimeoutException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
        provider: AiProviderId.claude,
      );
    }
    if (error is http.ClientException) {
      return const AiTransientException(
        message: 'error_unexpected_ai',
        provider: AiProviderId.claude,
      );
    }
    return const AiTransientException(
      message: 'error_unexpected_ai',
      provider: AiProviderId.claude,
    );
  }
}

/// Internal immutable value object holding normalized token usage counters for Claude.
class _ClaudeTokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const _ClaudeTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });
}
