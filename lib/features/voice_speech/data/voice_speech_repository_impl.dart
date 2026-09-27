import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/speech_grammar_formatter.dart';
import '../domain/voice_speech_repository.dart';
import 'whisper_transcription_service.dart';

/// Device-native + Whisper implementation of [VoiceRepository].
///
/// ## STT backend selection (automatic, at call time)
///
/// Whisper mode  — when [_openAiKeyGetter] returns a non-empty key:
///   1. Records audio to a temp .m4a file via the `record` package.
///   2. Uses amplitude monitoring for silence detection.
///   3. On stop: uploads the file to OpenAI Whisper → returns accurate text.
///   4. [isUsingWhisper] → true.
///
/// Native STT mode — fallback when no OpenAI key is available:
///   Android: Google Speech Recognition (requires network on Android <5)
///   iOS:     Apple Speech Recognition (on-device, no network needed)
///   [isUsingWhisper] → false.
///
/// ## TTS
///   flutter_tts package wrapping the platform TTS engine.
///   Android: Android TTS  iOS: AVSpeechSynthesizer
///
/// Platform permissions (already declared in native project files):
///   Android — AndroidManifest.xml:
///     <uses-permission android:name="android.permission.RECORD_AUDIO"/>
///   iOS — Info.plist:
///     <key>NSMicrophoneUsageDescription</key>
///     <key>NSSpeechRecognitionUsageDescription</key>  ← native STT only
class VoiceRepositoryImpl implements VoiceRepository {
  // ── Dependencies ──────────────────────────────────────────────────────────

  /// Returns the current plain-text OpenAI API key, or null if not configured.
  /// Evaluated lazily at each [startListening] call so key changes take effect
  /// without restarting the provider.
  final String? Function()? _openAiKeyGetter;

  late final stt.SpeechToText _stt;
  late final FlutterTts _tts;
  final AudioRecorder _audioRecorder = AudioRecorder();
  WhisperTranscriptionService? _whisperService;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isInitialized = false; // native STT initialized
  bool _isSpeaking = false;

  // Continuous listening session state
  bool _isContinuousListening = false;
  bool _isStartingListenSession = false;
  bool _isRestartingListenSession = false;
  bool _isWhisperRecording = false; // true while AudioRecorder is active

  // Native STT accumulated transcript
  String _accumulatedTranscript = '';
  String _latestCombinedTranscript = '';

  // Silence detection timers (shared by both backends)
  Timer? _silenceTimer;
  Timer? _restartTimer; // native STT restart only
  DateTime? _lastSpeechActivityAt;
  int _restartAttemptCount = 0;

  // Amplitude subscription (Whisper mode)
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // Active callbacks set by startListening
  void Function(String partialText)? _activeOnPartialResult;
  void Function(String finalText)? _activeOnFinalResult;
  void Function(String errorKey)? _activeOnError;

  // Callback triggered when native STT engine stops
  VoidCallback? _onEngineStop;

  // Cached device locale for native STT
  stt.LocaleName? _systemLocale;

  // ── Constructor ────────────────────────────────────────────────────────────

  VoiceRepositoryImpl({String? Function()? openAiKeyGetter})
      : _openAiKeyGetter = openAiKeyGetter {
    _stt = stt.SpeechToText();
    _tts = FlutterTts();
    _configureTts();
  }

  // ── VoiceRepository: isUsingWhisper ───────────────────────────────────────

  @override
  bool get isUsingWhisper {
    final key = _openAiKeyGetter?.call();
    return key != null && key.isNotEmpty;
  }

  // ── TTS Configuration ──────────────────────────────────────────────────────

  void _configureTts() {
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint('🔊 TTS: playback complete');
    });
    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      debugPrint('⚠️ TTS error: $message');
    });
    _tts.setLanguage('en-US');
  }

  // ── STT: availability & permissions ───────────────────────────────────────

  @override
  Future<bool> isSttAvailable() async {
    try {
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
    if (isUsingWhisper) {
      // Whisper mode: only needs microphone permission (no speech recognition)
      if (await _audioRecorder.hasPermission()) return true;
      final status = await Permission.microphone.request();
      if (!status.isGranted && !status.isPermanentlyDenied) {
        // Status might be limited/restricted; open settings on hard denial
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return await _audioRecorder.hasPermission();
    }

    // Native STT mode: needs microphone + speech recognition permission
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

  // ── STT: start listening ───────────────────────────────────────────────────

  @override
  Future<void> startListening({
    required void Function(String partialText) onPartialResult,
    required void Function(String finalText) onFinalResult,
    required void Function(String errorKey) onError,
  }) async {
    _activeOnPartialResult = onPartialResult;
    _activeOnFinalResult = onFinalResult;
    _activeOnError = onError;
    _isContinuousListening = true;
    _lastSpeechActivityAt = DateTime.now();
    _scheduleSilenceTimeoutFromLastSpeech();

    try {
      if (isUsingWhisper) {
        await _startWhisperRecordingSession();
      } else {
        // Native STT path — initialize if not done yet
        if (!_isInitialized) {
          final success = await _initStt();
          if (!success) {
            onError(VoiceErrorCodes.permissionDenied);
            return;
          }
        }
        await _startSttListenSession();
      }
    } catch (e) {
      debugPrint('❌ STT.startListening error: $e');
      onError(VoiceErrorCodes.listenFailed);
    }
  }

  // ── Whisper backend ────────────────────────────────────────────────────────

  /// Start recording audio to a temp file for later Whisper transcription.
  ///
  /// Uses AAC-LC (m4a) at 16 kHz — the optimal format for Whisper:
  ///   - 16 kHz matches Whisper's internal sample rate → no resampling needed
  ///   - AAC provides good quality at ~32 kbps → small upload size
  ///
  /// Amplitude is monitored via [AppConstants.whisperAmplitudePollInterval]
  /// to drive the same silence detection used by the native STT path.
  Future<void> _startWhisperRecordingSession() async {
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1, // mono — sufficient for speech
      ),
      path: filePath,
    );

    _isWhisperRecording = true;
    debugPrint('🎙️ Whisper: recording started → $filePath');

    // Show a placeholder partial so the UI shows the "listening" animation
    _activeOnPartialResult?.call('');

    // Monitor amplitude for silence detection
    _amplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(AppConstants.whisperAmplitudePollInterval)
        .listen((amp) {
      if (!_isContinuousListening) return;
      // Treat any amplitude above threshold as active speech
      if (amp.current > AppConstants.whisperSpeechAmplitudeThreshold) {
        _markSpeechActivity();
      }
    });
  }

  /// Stop the AudioRecorder, upload the file to Whisper, and emit the result.
  ///
  /// Called by both [_finishListening] (auto-silence) and [stopListening]
  /// (manual user tap).  Always awaited — the provider shows a "processing"
  /// spinner while this is in flight.
  Future<void> _stopWhisperAndTranscribe() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isWhisperRecording = false;

    final path = await _audioRecorder.stop();
    debugPrint('🎙️ Whisper: recording stopped → path=$path');

    if (path == null || path.isEmpty) {
      debugPrint('⚠️ Whisper: no audio file path returned');
      _activeOnError?.call(VoiceErrorCodes.listenFailed);
      return;
    }

    final openAiKey = _openAiKeyGetter?.call();
    if (openAiKey == null || openAiKey.isEmpty) {
      debugPrint('⚠️ Whisper: OpenAI key became unavailable after recording');
      _activeOnError?.call(VoiceErrorCodes.listenFailed);
      try { File(path).deleteSync(); } catch (_) {}
      return;
    }

    try {
      _whisperService ??= WhisperTranscriptionService();
      final transcript = await _whisperService!.transcribe(
        audioFile: File(path),
        apiKey: openAiKey,
      );
      final finalText =
          SpeechGrammarFormatter.format(transcript, isFinal: true);
      debugPrint('🎙️ Whisper: final transcript="${finalText.length > 80
          ? "${finalText.substring(0, 80)}…"
          : finalText}"');
      _activeOnFinalResult?.call(finalText);
    } catch (e) {
      debugPrint('❌ Whisper transcription error: $e');
      _activeOnError?.call(VoiceErrorCodes.listenFailed);
    } finally {
      // Clean up temp audio file to avoid storage accumulation
      try { File(path).deleteSync(); } catch (_) {}
    }
  }

  // ── Native STT backend ────────────────────────────────────────────────────

  Future<void> _startSttListenSession() async {
    if (!_isContinuousListening || _isStartingListenSession) return;
    _isStartingListenSession = true;
    try {
      await _stt.listen(
        onResult: (result) {
          if (!_isContinuousListening) return;

          final currentWords = result.recognizedWords.trim();
          final combinedText = _accumulatedTranscript.isEmpty
              ? currentWords
              : '$_accumulatedTranscript $currentWords'.trim();

          if (currentWords.isNotEmpty) {
            _markSpeechActivity();
            _restartAttemptCount = 0;
            final formatted =
                SpeechGrammarFormatter.format(combinedText, isFinal: false);
            _latestCombinedTranscript = formatted;
            _activeOnPartialResult?.call(formatted);
          }

          // Commit intermediate sentences so restart gaps don't drop words
          if (result.finalResult && currentWords.isNotEmpty) {
            debugPrint('🎤 STT intermediate sentence: "$currentWords"');
            final formatted =
                SpeechGrammarFormatter.format(combinedText, isFinal: false);
            _accumulatedTranscript = formatted;
            _latestCombinedTranscript = formatted;
          }
        },
        pauseFor: AppConstants.silenceTimeout,
        listenFor: AppConstants.maxRecordingSeconds,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          onDevice: false,
        ),
        localeId: _systemLocale?.localeId,
      );
      debugPrint('🎤 STT: listen session active');
    } finally {
      _isStartingListenSession = false;
    }
  }

  // ── Shared silence detection ───────────────────────────────────────────────

  void _markSpeechActivity() {
    _lastSpeechActivityAt = DateTime.now();
    _scheduleSilenceTimeoutFromLastSpeech();
  }

  bool _hasSilenceTimedOut() {
    final last = _lastSpeechActivityAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= AppConstants.silenceTimeout;
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
          '⏰ Silence timeout (${AppConstants.silenceTimeout.inSeconds}s) elapsed. Finalizing speech.');
      _finishListening();
    });
  }

  // ── Session finalization ───────────────────────────────────────────────────

  /// Called when speech is done — either by silence timeout or manual stop.
  ///
  /// In Whisper mode: kicks off the async Whisper upload (fire-and-forget here;
  /// awaited in [stopListening] for the manual-stop path).
  ///
  /// In native STT mode: immediately finalizes the accumulated transcript.
  void _finishListening() {
    if (!_isContinuousListening) return;
    _isContinuousListening = false;
    _cancelTimers();

    if (_isWhisperRecording) {
      // Whisper: async upload. We fire-and-forget here (silence timeout path).
      // The provider shows processing state until onFinalResult fires.
      _stopWhisperAndTranscribe().catchError((e) {
        debugPrint('❌ Whisper error in auto-stop: $e');
        _activeOnError?.call(VoiceErrorCodes.listenFailed);
      });
    } else {
      // Native STT: commit whatever we have accumulated
      _stt.stop();
      final rawText = (_latestCombinedTranscript.isNotEmpty
              ? _latestCombinedTranscript
              : _accumulatedTranscript)
          .trim();
      final finalText = SpeechGrammarFormatter.format(rawText, isFinal: true);
      _accumulatedTranscript = '';
      _latestCombinedTranscript = '';
      _activeOnFinalResult?.call(finalText);
    }
  }

  @override
  Future<void> stopListening() async {
    _isContinuousListening = false;
    _cancelTimers();

    if (_isWhisperRecording) {
      // Whisper: await the full upload so the provider can display processing
      // state until we have the actual transcript ready.
      debugPrint('🎙️ Whisper: manual stop — uploading to Whisper API…');
      await _stopWhisperAndTranscribe();
    } else {
      // Native STT: just stop the engine; partials are already in the input field
      try {
        await _stt.stop();
        debugPrint('🎤 STT: stopped manually');
      } catch (e) {
        debugPrint('⚠️ STT.stopListening error: $e');
      }
    }
  }

  // ── Native STT: engine restart (segment-boundary continuity) ──────────────

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
        debugPrint('🔄 Native engine paused — continuing listening session…');
        if (resetNativeSession) {
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

  Future<bool> _initStt() async {
    _isInitialized = await _stt.initialize(
      onError: (error) {
        debugPrint('❌ STT Engine Error: ${error.errorMsg}');
        if (!_isContinuousListening) return;
        final msg = error.errorMsg.toLowerCase();
        if (msg.contains('permission') || msg.contains('denied')) {
          _isContinuousListening = false;
          _cancelTimers();
          _activeOnError?.call(error.errorMsg);
          return;
        }
        if (_hasSilenceTimedOut()) { _finishListening(); return; }
        _restartAttemptCount++;
        final isBusy = msg.contains('busy');
        final isClient = msg.contains('client');
        final delay = isBusy
            ? Duration(
                milliseconds:
                    (650 + (_restartAttemptCount * 250)).clamp(650, 1600))
            : const Duration(milliseconds: 420);
        debugPrint(
            '🔄 Transient native STT error ($msg). Retrying in ${delay.inMilliseconds}ms…');
        _scheduleEngineRestart(
          delay: delay,
          resetNativeSession: isBusy || isClient,
        );
      },
      onStatus: (status) {
        debugPrint('🎤 STT Engine Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_isContinuousListening) {
          if (_hasSilenceTimedOut()) {
            _finishListening();
            return;
          }
            _scheduleEngineRestart();
          } else {
            _onEngineStop?.call();
            _onEngineStop = null;
          }
        }
      },
      finalTimeout: const Duration(seconds: 10),
    );

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

  // ── TTS ────────────────────────────────────────────────────────────────────

  @override
  Future<bool> isTtsAvailable() async {
    try {
      final engines = await _tts.getEngines;
      return engines != null && (engines as List).isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ TTS availability check failed: $e');
      return true;
    }
  }

  @override
  Future<void> speak(
    String text, {
    double speed = 1.0,
    void Function()? onComplete,
  }) async {
    try {
      if (_isSpeaking) await _tts.stop();

      // Convert 0.5–2.0 speed range to 0.25–1.0 flutter_tts range
      final ttsRate = (speed / 2.0).clamp(0.25, 1.0);
      await _tts.setSpeechRate(ttsRate);

      if (onComplete != null) {
        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          onComplete();
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    try {
      _cancelTimers();
      _amplitudeSubscription?.cancel();
      if (_isWhisperRecording) await _audioRecorder.stop();
      await _audioRecorder.dispose();
      await _stt.cancel();
      await _tts.stop();
      _whisperService?.dispose();
    } catch (e) {
      debugPrint('⚠️ VoiceRepository.dispose error: $e');
    }
  }
}
