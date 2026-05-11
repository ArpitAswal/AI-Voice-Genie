import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  /// Callback triggered when the STT engine stops (for any reason)
  VoidCallback? _onEngineStop;

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
    // We assume STT is available on modern iOS/Android devices to avoid
    // calling _stt.initialize() on startup, which triggers permission dialogs (bad UX).
    // The actual availability check happens when the user first taps the mic.
    return true;
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    if (_isInitialized) return true;

    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return await _initStt();
    } else if (status.isPermanentlyDenied || status.isDenied) {
      debugPrint('🚫 Microphone permission denied. Routing to settings.');
      await openAppSettings();
      return false;
    }

    return false;
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
        final success = await _initStt();
        if (!success) {
          onError(VoiceErrorCodes.permissionDenied);
          return;
        }
      }

      await _stt.listen(
        // Called continuously with partial transcription
        onResult: (result) {
          onPartialResult(result.recognizedWords);
          if (result.finalResult) {
            final transcript = result.recognizedWords.trim();
            onFinalResult(transcript);
            _onEngineStop = null;
          }
        },
        // Auto-stop after configured silence duration
        pauseFor: AppConstants.silenceTimeout,
        // Listen for long enough to capture complete sentences
        listenFor: const Duration(seconds: AppConstants.maxRecordingSeconds),
        // Partial results drive the live transcript display
        partialResults: true,
        // Use dictation mode for better handling of silence gaps
        listenMode: stt.ListenMode.dictation,
        // onDevice recognition is often less aggressive with auto-stopping
        onDevice: true,
        // Use localeId matching the current device language
        localeId: 'en_US',
      );

      // Register the engine stop callback to handle timeouts where no result is returned
      _onEngineStop = () => onFinalResult("");

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

  Future<bool> _initStt() async {
    _isInitialized = await _stt.initialize(
      onError: (error) {
        _isInitialized = false;
        debugPrint('❌ STT Engine Error: ${error.errorMsg}');
      },
      onStatus: (status) {
        debugPrint('STT Status: $status');
        if (status == 'done' || status == 'notListening') {
          _onEngineStop?.call();
          _onEngineStop = null;
        }
      },
    );
    return _isInitialized;
  }

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