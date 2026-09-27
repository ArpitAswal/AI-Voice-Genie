import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/storage_service.dart';
import '../data/voice_speech_repository_impl.dart';
import '../domain/voice_speech_repository.dart';

/// State manager for all voice interactions in AI Voice Genie.
///
/// Manages:
///   - STT recording lifecycle (idle → listening → processing → idle)
///   - TTS playback lifecycle (idle → playing → idle)
///   - Live partial transcript display during recording
///   - Microphone and TTS availability checks
///   - TTS speed preference from Hive
///
/// ## STT backend
/// When [openAiKeyGetter] returns a non-empty key the repository uses
/// **OpenAI Whisper** for transcription (server-side, high accuracy).
/// Without a key it falls back to the **platform-native** STT engine.
/// After the user stops speaking, if Whisper is active the provider
/// transitions to [VoiceRecordingState.processing] to indicate the
/// brief upload/transcription delay before returning to idle.
///
/// Used by:
///   - VoiceInputButton  — reads recordingState, triggers startListening/stop
///   - TtsPlaybackButton — reads isPlaying, triggers speak/stop
///   - ChatInputBar       — receives onTranscriptReady callback
///
/// Usage:
/// ```dart
/// // Start listening
/// await voiceProvider.startListening(
///   onTranscriptReady: (text) => controller.text = text,
/// );
///
/// // Speak an AI response
/// await voiceProvider.speak(aiResponseText);
/// ```
class VoiceProvider extends ChangeNotifier {
  final VoiceRepository _repository;
  final AnalyticsService _analytics;
  final StorageService _storage;

  VoiceProvider({
    VoiceRepository? repository,
    AnalyticsService? analytics,
    StorageService? storage,
    /// Returns the current plain-text OpenAI API key, or null if not available.
    /// Evaluated lazily at each [startListening] call so key changes take effect
    /// without restarting the provider.
    String? Function()? openAiKeyGetter,
  })  : _repository = repository ??
            VoiceRepositoryImpl(openAiKeyGetter: openAiKeyGetter),
        _analytics = analytics ?? AnalyticsService.instance,
        _storage = storage ?? StorageService() {
    _initialize();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  VoiceRecordingState _state = VoiceRecordingState.idle;
  bool _isSttAvailable = false;
  bool _isTtsAvailable = false;

  /// Live partial transcript text shown in UI during recording
  String _partialTranscript = '';

  /// TTS playback speed read from Hive (default 1.0)
  double _ttsSpeed = 1.0;

  /// Which message ID is currently being played by TTS
  String? _activeTtsMessageId;

  VoiceRecordingState get state => _state;
  bool get isSttAvailable => _isSttAvailable;
  bool get isTtsAvailable => _isTtsAvailable;
  String get partialTranscript => _partialTranscript;
  double get ttsSpeed => _ttsSpeed;
  String? get activeTtsMessageId => _activeTtsMessageId;

  bool get isIdle => _state == VoiceRecordingState.idle;
  bool get isListening => _state == VoiceRecordingState.listening;
  bool get isProcessing => _state == VoiceRecordingState.processing;
  bool get isPlaying => _state == VoiceRecordingState.playing;
  bool get isUnavailable => _state == VoiceRecordingState.unavailable;

  /// Whether the Whisper backend is currently active.
  /// Exposed so the UI can optionally show a "Transcribing…" label.
  bool get isUsingWhisper => _repository.isUsingWhisper;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    _isSttAvailable = await _repository.isSttAvailable();
    _isTtsAvailable = await _repository.isTtsAvailable();

    _ttsSpeed = _storage.getString(StorageKeys.ttsSpeed) != null
        ? double.tryParse(_storage.getString(StorageKeys.ttsSpeed) ?? '1.0') ??
            1.0
        : 1.0;

    if (!_isSttAvailable) {
      _state = VoiceRecordingState.unavailable;
    }
  }

  // ── STT — Voice Input ──────────────────────────────────────────────────────

  /// Start listening for voice input.
  ///
  /// [onTranscriptReady] — called with the final transcript when speech ends.
  ///
  /// **Whisper mode**: transcript arrives after a short upload delay.
  ///   The state transitions to [VoiceRecordingState.processing] during this
  ///   delay so the UI can show a spinner instead of the idle mic button.
  ///
  /// [onPartialTranscript] — optional callback for live partial text during
  ///   native STT recording. Not used in Whisper mode (no live words).
  Future<void> startListening({
    required void Function(String transcript) onTranscriptReady,
    required void Function(String errorKey) onError,
    void Function(String partial)? onPartialTranscript,
  }) async {
    if (isPlaying) await stopSpeaking();

    if (!_isSttAvailable) {
      _setState(VoiceRecordingState.unavailable);
      onError('speech_text_unavailable');
      return;
    }

    _partialTranscript = '';
    // Move to processing immediately so users see feedback while mic opens
    _setState(VoiceRecordingState.processing);

    final success = await _repository.requestMicrophonePermission();
    if (!success) {
      _setState(VoiceRecordingState.unavailable);
      final status = await Permission.microphone.status;
      onError(status.isGranted ? 'voice_input_failed' : 'microphone_permission_denied');
      return;
    }

    await _repository.startListening(
      onPartialResult: (partial) {
        _partialTranscript = partial;
        onPartialTranscript?.call(partial);
        notifyListeners();
      },
      onFinalResult: (finalText) {
        // Clear partials — final result replaces everything
        _partialTranscript = '';
        _setState(VoiceRecordingState.idle);
        onTranscriptReady(finalText);
        _analytics.logFeatureUsed(AppFeature.voiceInput);
        notifyListeners();
      },
      onError: (errorKey) {
        _partialTranscript = '';
        _setState(VoiceRecordingState.error);
        onError(errorKey);
        Future.delayed(const Duration(seconds: 2)).then((_) {
          if (_state == VoiceRecordingState.error) {
            _setState(VoiceRecordingState.idle);
          }
        });
      },
    );

    // Transition to listening once the backend session is open
    if (_state == VoiceRecordingState.processing) {
      _setState(VoiceRecordingState.listening);
    }
  }

  /// Stop listening early (user taps mic button again).
  ///
  /// In Whisper mode: transitions to [processing] immediately (spinner visible
  /// to the user) then awaits the Whisper API call; state → idle when done.
  ///
  /// In native STT mode: state → idle immediately (text already in input field
  /// from partial results).
  Future<void> stopListening() async {
    _partialTranscript = '';

    if (_repository.isUsingWhisper) {
      // Show spinner while Whisper upload is in flight
      _setState(VoiceRecordingState.processing);
      notifyListeners();
    }

    await _repository.stopListening();

    // For Whisper: onFinalResult callback already set state to idle.
    // For native STT: we need to set it explicitly.
    if (_state != VoiceRecordingState.idle) {
      _setState(VoiceRecordingState.idle);
    }
  }

  // ── TTS — Voice Output ─────────────────────────────────────────────────────

  /// Speak an AI response aloud.
  Future<void> speak(String text, {String? messageId}) async {
    if (!_isTtsAvailable) return;

    // Toggle: tapping the same message's speaker button stops playback
    if (isPlaying && _activeTtsMessageId == messageId) {
      await stopSpeaking();
      return;
    }

    if (isPlaying) await _repository.stopSpeaking();

    final idChanged = _activeTtsMessageId != messageId;
    _activeTtsMessageId = messageId;

    if (_state != VoiceRecordingState.playing || idChanged) {
      _state = VoiceRecordingState.playing;
      notifyListeners();
    }

    await _repository.speak(
      text,
      speed: _ttsSpeed,
      onComplete: () {
        _activeTtsMessageId = null;
        _setState(VoiceRecordingState.idle);
        _analytics.logFeatureUsed(AppFeature.voiceOutput);
      },
    );
  }

  /// Stop TTS playback immediately.
  Future<void> stopSpeaking() async {
    await _repository.stopSpeaking();
    _activeTtsMessageId = null;
    _setState(VoiceRecordingState.idle);
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> setTtsSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    _ttsSpeed = clamped;
    await _storage.setString(StorageKeys.ttsSpeed, clamped.toString());
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _setState(VoiceRecordingState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }
}
