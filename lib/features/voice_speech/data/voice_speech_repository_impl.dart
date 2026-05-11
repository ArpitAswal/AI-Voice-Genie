import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/app_constants.dart';
import '../domain/voice_speech_repository.dart';

/// Device-native implementation of VoiceRepository.
///
/// STT — uses speech_to_text package (wraps platform STT engine).
///   Android: uses Google Speech Recognition (requires network on Android <5)
///   iOS:     uses Apple Speech Recognition (on-device, no network needed)
///
/// TTS — uses flutter_tts package (wraps platform TTS engine).
///   Android: uses Android TTS engine (pre-installed on most devices)
///   iOS:     uses AVSpeechSynthesizer
///
/// Platform configuration required (done in native project files):
///   Android — AndroidManifest.xml:
///     <uses-permission android:name="android.permission.RECORD_AUDIO"/>
///   iOS — Info.plist:
///     <key>NSSpeechRecognitionUsageDescription</key>
///     <key>NSMicrophoneUsageDescription</key>
class VoiceRepositoryImpl implements VoiceRepository {
  late final stt.SpeechToText _stt;
  late final FlutterTts _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  VoiceRepositoryImpl() {
    _stt = stt.SpeechToText();
    _tts = FlutterTts();
    _configureTts();
  }

  // ── TTS Configuration ──────────────────────────────────────────────────────

  void _configureTts() {
    // Listen for TTS completion
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint('🔊 TTS: playback complete');
    });

    // Listen for TTS errors
    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      debugPrint('⚠️ TTS error: $message');
    });

    // Default language — English
    _tts.setLanguage('en-US');
  }

  // ── STT ────────────────────────────────────────────────────────────────────

  @override
  Future<bool> isSttAvailable() async {
    try {
      return await _stt.initialize(
        onError: (error) =>
            debugPrint('⚠️ STT init error: ${error.errorMsg}'),
        onStatus: (status) => debugPrint('STT status: $status'),
      );
    } catch (e) {
      debugPrint('⚠️ STT availability check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    // speech_to_text handles permission internally on both platforms.
    // If permission was denied previously, initialize() returns false.
    // We rely on the initialize() result as the permission indicator.
    if (_isInitialized) return true;

    _isInitialized = await _stt.initialize(
      onError: (error) => debugPrint('STT init error: ${error.errorMsg}'),
    );

    return _isInitialized;
  }

  @override
  Future<void> startListening({
    required void Function(String partialText) onPartialResult,
    required void Function(String finalText) onFinalResult,
    required void Function(String errorKey) onError,
  }) async {
    try {
      // Ensure STT is initialized before listening
      if (!_isInitialized) {
        _isInitialized = await _stt.initialize();
        if (!_isInitialized) {
          onError(VoiceErrorCodes.permissionDenied);
          return;
        }
      }

      await _stt.listen(
        // Called continuously with partial transcription
        onResult: (result) {
          if (result.finalResult) {
            final transcript = result.recognizedWords.trim();
            if (transcript.isNotEmpty) {
              onFinalResult(transcript);
            }
          } else {
            onPartialResult(result.recognizedWords);
          }
        },
        // Auto-stop after configured silence duration
        pauseFor: AppConstants.silenceTimeout,
        // Listen for long enough to capture complete sentences
        listenFor: const Duration(seconds: AppConstants.maxRecordingSeconds),
        // Partial results drive the live transcript display
        partialResults: true,
        // Use localeId matching the current device language
        localeId: 'en_US',
      );

      debugPrint('🎤 STT: started listening');
    } catch (e) {
      debugPrint('❌ STT.startListening error: $e');
      onError(VoiceErrorCodes.listenFailed);
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _stt.stop();
      debugPrint('🎤 STT: stopped');
    } catch (e) {
      debugPrint('⚠️ STT.stopListening error: $e');
    }
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  @override
  Future<bool> isTtsAvailable() async {
    try {
      final engines = await _tts.getEngines;
      return engines != null && (engines as List).isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ TTS availability check failed: $e');
      return true; // Assume available — flutter_tts is widely supported
    }
  }

  @override
  Future<void> speak(
      String text, {
        double speed = 1.0,
        void Function()? onComplete,
      }) async {
    try {
      // Stop any current playback before starting new
      if (_isSpeaking) {
        await _tts.stop();
      }

      // Set speech rate — flutter_tts uses 0.0–1.0 scale
      // Convert our 0.5–2.0 range to 0.25–1.0 flutter_tts range
      final ttsRate = (speed / 2.0).clamp(0.25, 1.0);
      await _tts.setSpeechRate(ttsRate);

      // Register one-time completion callback
      if (onComplete != null) {
        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          onComplete();
          // Restore default completion handler
          _tts.setCompletionHandler(() => _isSpeaking = false);
        });
      }

      _isSpeaking = true;
      await _tts.speak(text);
      debugPrint('🔊 TTS: speaking ${text.length} chars');
    } catch (e) {
      _isSpeaking = false;
      debugPrint('❌ TTS.speak error: $e');
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
      debugPrint('🔊 TTS: stopped');
    } catch (e) {
      debugPrint('⚠️ TTS.stopSpeaking error: $e');
    }
  }

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> dispose() async {
    try {
      await _stt.cancel();
      await _tts.stop();
    } catch (e) {
      debugPrint('⚠️ VoiceRepository.dispose error: $e');
    }
  }
}