import 'dart:async';
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

  /// Active callbacks for continuous session management
  void Function(String partialText)? _activeOnPartialResult;
  void Function(String finalText)? _activeOnFinalResult;
  void Function(String errorKey)? _activeOnError;

  /// Continuous listening state & silence debounce timers
  Timer? _silenceTimer;
  Timer? _restartTimer;
  String _accumulatedTranscript = '';
  bool _isContinuousListening = false;

  /// Cached system locale matching the user's regional accent
  stt.LocaleName? _systemLocale;

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
      // Check if permissions are permanently denied or restricted by OS/MDM without triggering popups.
      // Calling _stt.initialize() here would immediately trigger system permission dialogs on app launch.
      final micStatus = await Permission.microphone.status;
      final speechStatus = await Permission.speech.status;
      if (micStatus.isPermanentlyDenied ||
          micStatus.isRestricted ||
          speechStatus.isPermanentlyDenied ||
          speechStatus.isRestricted) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ STT silent availability check failed: $e');
      return true;
    }
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
    _activeOnPartialResult = onPartialResult;
    _activeOnFinalResult = onFinalResult;
    _activeOnError = onError;
    _accumulatedTranscript = '';
    _isContinuousListening = true;
    _silenceTimer?.cancel();

    try {
      // Ensure STT is initialized before listening
      if (!_isInitialized) {
        final success = await _initStt();
        if (!success) {
          onError(VoiceErrorCodes.permissionDenied);
          return;
        }
      }

      await _startSttListenSession();
    } catch (e) {
      debugPrint('❌ STT.startListening error: $e');
      onError(VoiceErrorCodes.listenFailed);
    }
  }

  Future<void> _startSttListenSession() async {
    if (!_isContinuousListening) return;

    // Start or reset the silence debounce timer to wait for the full silenceTimeout
    _resetSilenceTimer();

    await _stt.listen(
      // Called continuously with partial transcription
      onResult: (result) {
        if (!_isContinuousListening) return;

        // Any recognized speech activity resets our 5-second silence timer
        _resetSilenceTimer();

        final currentWords = result.recognizedWords.trim();
        final combinedText = _accumulatedTranscript.isEmpty
            ? currentWords
            : '$_accumulatedTranscript $currentWords'.trim();

        if (currentWords.isNotEmpty) {
          _activeOnPartialResult?.call(combinedText);
        }

        // When the native OS recognizer stops early (e.g. 1.5s pause on Android/iOS),
        // it sends finalResult = true. Instead of closing right away, we store the text
        // and allow onStatus to automatically restart listening!
        if (result.finalResult) {
          debugPrint('🎤 STT intermediate sentence: "$currentWords"');
          if (currentWords.isNotEmpty) {
            _accumulatedTranscript = combinedText;
          }
        }
      },
      // Auto-stop after configured silence duration
      pauseFor: AppConstants.silenceTimeout,
      // Listen for long enough to capture complete sentences
      listenFor: AppConstants.maxRecordingSeconds,
      // SpeechListenOptions for deprecated properties
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        onDevice: false,
      ),
      // Use dynamically detected device locale instead of hardcoded American English
      localeId: _systemLocale?.localeId,
    );
    debugPrint('🎤 STT: listen session active');
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(AppConstants.silenceTimeout, () {
      debugPrint(
          '⏰ Full silence timeout (${AppConstants.silenceTimeout.inSeconds}s) elapsed. Finalizing speech.');
      _finishListening();
    });
  }

  /// Helper to cancel and clear all continuous listening debounce timers
  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _finishListening() {
    if (!_isContinuousListening) return;
    _isContinuousListening = false;
    _cancelTimers();
    _stt.stop();
    final finalText = _accumulatedTranscript.trim();
    _accumulatedTranscript = '';
    if (_activeOnFinalResult != null) {
      _activeOnFinalResult!(finalText);
    }
  }

  void _scheduleEngineRestart() {
    if (!_isContinuousListening) return;
    // Cancel any pending restart so we never trigger overlapping listen sessions
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 350), () async {
      if (_isContinuousListening && !_stt.isListening) {
        debugPrint('🔄 Native engine paused. Continuing listening session...');
        // Cleanly stop any leftover native engine state before restarting
        try {
          await _stt.stop();
        } catch (_) {}
        if (_isContinuousListening) {
          _startSttListenSession();
        }
      }
    });
  }

  @override
  Future<void> stopListening() async {
    try {
      _isContinuousListening = false;
      _cancelTimers();
      await _stt.stop();
      debugPrint('🎤 STT: stopped manually');
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
          debugPrint('❌ STT Engine Error: ${error.errorMsg}');
          if (_isContinuousListening) {
            final msg = error.errorMsg.toLowerCase();
            // Abort immediately only on actual fatal permission/access errors
            if (msg.contains('permission') || msg.contains('denied')) {
              _isContinuousListening = false;
              _cancelTimers();
              _activeOnError?.call(error.errorMsg);
              return;
            }
            // For all other native engine errors (error_client, error_no_match,
            // error_speech_timeout, error_busy), do NOT abort our session!
            // We are customly managing silence with our 5s timer.
            debugPrint(
                '🔄 Non-fatal native STT error during active pause ($msg). Auto-restarting...');
            _scheduleEngineRestart();
          }
        },
        onStatus: (status) {
          debugPrint('🎤 STT Engine Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isContinuousListening) {
              // Native engine stopped early (~1.5s pause) before our 5s silence timer!
              // Automatically restart to provide continuous dictation until 5s of true silence.
              _scheduleEngineRestart();
            } else {
              _onEngineStop?.call();
              _onEngineStop = null;
            }
          }
        },
        finalTimeout: const Duration(seconds: 10));
    if (_isInitialized) {
      try {
        _systemLocale = await _stt.systemLocale();
        debugPrint(
            '🎤 STT System Locale initialized: ${_systemLocale?.localeId}');
      } catch (e) {
        debugPrint('⚠️ Could not get system locale: $e');
      }
    }
    return _isInitialized;
  }

  @override
  Future<void> dispose() async {
    try {
      _cancelTimers();
      await _stt.cancel();
      await _tts.stop();
    } catch (e) {
      debugPrint('⚠️ VoiceRepository.dispose error: $e');
    }
  }
}
