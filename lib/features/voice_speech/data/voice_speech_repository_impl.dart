import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/speech_grammar_formatter.dart';
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
  String _latestCombinedTranscript = '';
  bool _isContinuousListening = false;
  bool _isStartingListenSession = false;
  bool _isRestartingListenSession = false;
  DateTime? _lastSpeechActivityAt;
  int _restartAttemptCount = 0;

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
    _latestCombinedTranscript = '';
    _isContinuousListening = true;
    _lastSpeechActivityAt = DateTime.now();
    _scheduleSilenceTimeoutFromLastSpeech();

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
    if (!_isContinuousListening || _isStartingListenSession) return;

    _isStartingListenSession = true;
    try {
      await _stt.listen(
        // Called continuously with partial transcription
        onResult: (result) {
          if (!_isContinuousListening) return;

          final currentWords = result.recognizedWords.trim();
          final combinedText = _accumulatedTranscript.isEmpty
              ? currentWords
              : '$_accumulatedTranscript $currentWords'.trim();

          if (currentWords.isNotEmpty) {
            _markSpeechActivity();
            _restartAttemptCount = 0;
            final formattedPartial =
                SpeechGrammarFormatter.format(combinedText, isFinal: false);
            _latestCombinedTranscript = formattedPartial;
            _activeOnPartialResult?.call(formattedPartial);
          }

          // Native recognizers often emit finalResult before our desired silence
          // timeout. Commit that segment immediately so a fast restart cannot lose it.
          if (result.finalResult) {
            debugPrint('🎤 STT intermediate sentence: "$currentWords"');
            if (currentWords.isNotEmpty) {
              final formattedSegment =
                  SpeechGrammarFormatter.format(combinedText, isFinal: false);
              _accumulatedTranscript = formattedSegment;
              _latestCombinedTranscript = formattedSegment;
            }
          }
        },
        // Native engines may still stop earlier than this, so app code restarts
        // immediately and our own silence timer decides when the dictation ends.
        pauseFor: AppConstants.silenceTimeout,
        listenFor: AppConstants.maxRecordingSeconds,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          onDevice: false,
        ),
        // Use dynamically detected device locale instead of hardcoded American English.
        localeId: _systemLocale?.localeId,
      );

      debugPrint('🎤 STT: listen session active');
    } finally {
      _isStartingListenSession = false;
    }
  }

  void _markSpeechActivity() {
    _lastSpeechActivityAt = DateTime.now();
    _scheduleSilenceTimeoutFromLastSpeech();
  }

  bool _hasSilenceTimedOut() {
    final lastSpeech = _lastSpeechActivityAt;
    if (lastSpeech == null) return true;
    return DateTime.now().difference(lastSpeech) >= AppConstants.silenceTimeout;
  }

  void _scheduleSilenceTimeoutFromLastSpeech() {
    _silenceTimer?.cancel();
    final lastSpeech = _lastSpeechActivityAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(lastSpeech);
    final remaining = AppConstants.silenceTimeout - elapsed;

    if (remaining <= Duration.zero) {
      _finishListening();
      return;
    }

    _silenceTimer = Timer(remaining, () {
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
    _isStartingListenSession = false;
    _isRestartingListenSession = false;
    _lastSpeechActivityAt = null;
    _restartAttemptCount = 0;
  }

  void _finishListening() {
    if (!_isContinuousListening) return;
    _isContinuousListening = false;
    _cancelTimers();
    _stt.stop();
    // Use the latest visible partial text when the native engine has not emitted
    // finalResult yet; otherwise stopping after silence can erase the last phrase.
    final rawText = (_latestCombinedTranscript.isNotEmpty
            ? _latestCombinedTranscript
            : _accumulatedTranscript)
        .trim();
    final finalText = SpeechGrammarFormatter.format(rawText, isFinal: true);
    _accumulatedTranscript = '';
    _latestCombinedTranscript = '';
    if (_activeOnFinalResult != null) {
      _activeOnFinalResult!(finalText);
    }
  }

  void _scheduleEngineRestart({
    Duration delay = const Duration(milliseconds: 280),
    bool resetNativeSession = false,
  }) {
    if (!_isContinuousListening) return;
    if (_hasSilenceTimedOut()) {
      _finishListening();
      return;
    }
    if (_isStartingListenSession || _isRestartingListenSession) return;
    if (_restartTimer?.isActive ?? false) return;

    _restartTimer = Timer(delay, () async {
      if (!_isContinuousListening ||
          _stt.isListening ||
          _isStartingListenSession ||
          _isRestartingListenSession) {
        return;
      }

      if (_hasSilenceTimedOut()) {
        _finishListening();
        return;
      }

      _isRestartingListenSession = true;
      try {
        debugPrint('🔄 Native engine paused. Continuing listening session...');
        if (resetNativeSession) {
          // Android can report notListening/done while the recognizer is still
          // internally busy. Cancel gives it a clean session before relistening.
          await _stt.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        if (_hasSilenceTimedOut()) {
          _finishListening();
          return;
        }
        if (_isContinuousListening && !_stt.isListening) {
          await _startSttListenSession();
        }
      } finally {
        _isRestartingListenSession = false;
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
            // For transient native errors, keep the app-level dictation alive.
            // error_busy needs a longer cooldown because Android may still be
            // releasing the previous recognizer even after notListening/done.
            if (_hasSilenceTimedOut()) {
              _finishListening();
              return;
            }
            _restartAttemptCount++;
            final isBusy = msg.contains('busy');
            final isClient = msg.contains('client');
            final delay = isBusy
                ? Duration(
                    milliseconds:
                        (650 + (_restartAttemptCount * 250)).clamp(650, 1600),
                  )
                : const Duration(milliseconds: 420);
            debugPrint(
                '🔄 Transient native STT error ($msg). Retrying in ${delay.inMilliseconds}ms...');
            _scheduleEngineRestart(
              delay: delay,
              resetNativeSession: isBusy || isClient,
            );
          }
        },
        onStatus: (status) {
          debugPrint('🎤 STT Engine Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isContinuousListening) {
              if (_hasSilenceTimedOut()) {
                _finishListening();
                return;
              }
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
