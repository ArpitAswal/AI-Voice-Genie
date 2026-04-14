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

/// Claude provider adapter for AI Voice Genie.
///
/// Implements three capabilities using Anthropic's Messages API:
///   textGeneration     → POST /v1/messages (claude-sonnet-4-5)
///   imageUnderstanding → POST /v1/messages with base64 image content block
///   pdfParsing         → POST /v1/messages with PDF text in system prompt
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

      final response = await _post(
        apiKey: apiKey,
        body: {
          'model': AppConstants.claudeTextModel,
          'max_tokens': 2048,
          'system': 'You are a helpful, accurate, and concise AI assistant. '
              'Format responses clearly using markdown where appropriate.',
          'messages': messages,
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = data['content']?[0]?['text'] as String? ?? '';
      final tokenCount = (data['usage']?['input_tokens'] as int? ?? 0) +
          (data['usage']?['output_tokens'] as int? ?? 0);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
        capability: AiCapability.textGeneration,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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
    // This should never be called — ProviderRegistry excludes Claude
    // from imageGeneration, so ModelSelector never routes here.
    // Defensive guard in case of incorrect direct instantiation.
    throw UnsupportedError(
      'Claude does not support image generation. '
      'This method should never be called — check ProviderRegistry.',
    );
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
      // Claude's multimodal format uses content blocks within a message
      final response = await _post(
        apiKey: apiKey,
        body: {
          'model': AppConstants.claudeVisionModel,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mimeType,
                    'data': base64Image,
                  },
                },
                {'type': 'text', 'text': request.prompt},
              ],
            },
          ],
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = data['content']?[0]?['text'] as String? ?? '';
      final tokenCount = (data['usage']?['input_tokens'] as int? ?? 0) +
          (data['usage']?['output_tokens'] as int? ?? 0);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
        capability: AiCapability.imageUnderstanding,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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

    final systemPrompt = 'You are a document analysis assistant. '
        'The following is extracted text from a PDF titled '
        '"${request.pdfFileName ?? "document"}".\n\n'
        'Document content:\n\n${request.pdfText ?? ""}\n\n'
        'Answer questions based only on the document content above. '
        'Be precise and cite relevant sections when possible.';

    try {
      final response = await _post(
        apiKey: apiKey,
        body: {
          'model': AppConstants.claudeTextModel,
          'max_tokens': 2048,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': request.prompt},
          ],
        },
      ).timeout(AppConstants.aiRequestTimeout);

      final data = _parseResponse(response, request.requestId);
      final text = data['content']?[0]?['text'] as String? ?? '';
      final tokenCount = (data['usage']?['input_tokens'] as int? ?? 0) +
          (data['usage']?['output_tokens'] as int? ?? 0);

      stopwatch.stop();
      return AiResponse.text(
        modelUsed: AiProviderId.claude,
        capability: AiCapability.pdfParsing,
        requestId: request.requestId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        text: text,
        tokenCount: tokenCount,
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
  }) {
    return _client.post(
      Uri.parse('${AppConstants.claudeBaseUrl}/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': AppConstants.claudeApiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  /// Parse HTTP response and map to typed AiExceptions.
  Map<String, dynamic> _parseResponse(
    http.Response response,
    String requestId,
  ) {
    debugPrint('🟠 Claude: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw mapHttpErrorToAiException(
      statusCode: response.statusCode,
      provider: AiProviderId.claude,
      rawMessage: response.body,
    );
  }

  AiException _mapError(Object error) {
    if (error is SocketException) {
      return const AiTransientException(
        message: 'No internet connection',
        provider: AiProviderId.claude,
      );
    }
    if (error is http.ClientException) {
      return AiTransientException(
        message: 'Network error: ${error.message}',
        provider: AiProviderId.claude,
      );
    }
    return AiTransientException(
      message: 'Unexpected Claude error: $error',
      provider: AiProviderId.claude,
    );
  }
}
