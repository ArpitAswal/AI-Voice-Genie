import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';

/// Sends a recorded audio file to OpenAI Whisper for server-side transcription.
///
/// This is the same transcription engine used by the ChatGPT web voice mode.
/// It is dramatically more accurate than on-device platform STT engines because:
///   - Trained on 680,000 hours of multilingual audio
///   - Handles accents, technical jargon, and AI terminology
///   - Single-shot: transcribes the complete utterance, no segment seams
///
/// Supported audio formats: m4a, mp3, mp4, wav, webm (any format the `record`
/// package can write).  This service defaults to m4a (AudioEncoder.aacLc) which
/// is natively efficient on both Android and iOS.
///
/// Authentication: uses the user's existing OpenAI API key — no extra key is
/// needed beyond what they have already added in the app.
///
/// Cost: ~$0.006 per minute of audio — negligible for typical voice prompts.
class WhisperTranscriptionService {
  final http.Client _client;

  WhisperTranscriptionService({http.Client? client})
      : _client = client ?? http.Client();

  /// Transcribe [audioFile] using the OpenAI Whisper API.
  ///
  /// [audioFile]  — the recorded audio file (m4a / wav / mp3 etc.)
  /// [apiKey]     — the user's OpenAI API key (decrypted, plain text)
  /// [language]   — BCP-47 language hint (e.g. 'en'). Providing it is faster
  ///                than auto-detection and slightly improves accuracy.
  ///
  /// Returns the transcript text (may be empty if audio was silent).
  /// Throws on HTTP errors or network failures.
  Future<String> transcribe({
    required File audioFile,
    required String apiKey,
    String language = 'en',
  }) async {
    debugPrint(
        '🎙️ Whisper: uploading ${audioFile.path.split('/').last} '
        '(${(audioFile.lengthSync() / 1024).toStringAsFixed(1)} KB)');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.openAiBaseUrl}/audio/transcriptions'),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';

    // whisper-1 is the production Whisper model
    request.fields['model'] = AppConstants.openAiWhisperModel;
    // Language hint — avoids auto-detection overhead and improves accuracy
    request.fields['language'] = language;
    // json is the simplest response format: {"text": "..."}
    request.fields['response_format'] = 'json';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      audioFile.path,
    ));

    final streamedResponse = await _client
        .send(request)
        .timeout(AppConstants.aiRequestTimeout);

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['text'] as String? ?? '';
      debugPrint('🎙️ Whisper: transcript="${text.length > 80
          ? "${text.substring(0, 80)}…"
          : text}"');
      return text;
    }

    debugPrint(
        '⚠️ Whisper error ${response.statusCode}: ${response.body}');
    throw Exception(
        'Whisper transcription failed (HTTP ${response.statusCode})');
  }

  void dispose() {
    _client.close();
  }
}
