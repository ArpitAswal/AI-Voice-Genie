import 'package:flutter/foundation.dart';

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
  })  : _repository = repository ?? VoiceRepositoryImpl(),
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
  /// Used to highlight the active TTS bubble in the chat list
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

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    // Check device capabilities
    _isSttAvailable = await _repository.isSttAvailable();
    _isTtsAvailable = await _repository.isTtsAvailable();

    // Load TTS speed preference from Hive
    _ttsSpeed = _storage.getString(StorageKeys.ttsSpeed) != null
        ? double.tryParse(_storage.getString(StorageKeys.ttsSpeed) ?? '1.0') ??
            1.0
        : 1.0;

    if (!_isSttAvailable) {
      _state = VoiceRecordingState.unavailable;
    }

    notifyListeners();
  }

  // ── STT — Voice Input ──────────────────────────────────────────────────────

  /// Start listening for voice input.
  ///
  /// [onTranscriptReady] — called with the final transcript when speech ends.
  ///   Use this to pre-fill the chat input field:
  ///   ```dart
  ///   voiceProvider.startListening(
  ///     onTranscriptReady: (text) => _controller.text = text,
  ///   );
  ///   ```
  Future<void> startListening({
    required void Function(String transcript) onTranscriptReady,
  }) async {
    // If TTS is currently playing, stop it first
    if (isPlaying) {
      await stopSpeaking();
    }

    if (!_isSttAvailable) {
      _setState(VoiceRecordingState.unavailable);
      return;
    }

    // Request microphone permission before listening
    final hasPermission = await _repository.requestMicrophonePermission();
    if (!hasPermission) {
      _setState(VoiceRecordingState.error);
      // Reset to idle after brief error display
      await Future.delayed(const Duration(seconds: 2));
      _setState(VoiceRecordingState.idle);
      return;
    }

    _partialTranscript = '';
    _setState(VoiceRecordingState.listening);

    await _repository.startListening(
      onPartialResult: (partial) {
        // Update live transcript display during speech
        _partialTranscript = partial;
        notifyListeners();
      },
      onFinalResult: (final_) {
        // Transcript ready — pre-fill the input field
        _partialTranscript = '';
        _setState(VoiceRecordingState.idle);
        onTranscriptReady(final_);
        _analytics.logFeatureUsed(AppFeature.voiceInput);
      },
      onError: (errorKey) {
        _partialTranscript = '';
        _setState(VoiceRecordingState.error);
        // Reset to idle after brief error display
        Future.delayed(const Duration(seconds: 2)).then((_) {
          if (_state == VoiceRecordingState.error) {
            _setState(VoiceRecordingState.idle);
          }
        });
      },
    );
  }

  /// Stop listening early (user taps mic button again to cancel).
  Future<void> stopListening() async {
    await _repository.stopListening();
    _partialTranscript = '';
    _setState(VoiceRecordingState.idle);
  }

  // ── TTS — Voice Output ─────────────────────────────────────────────────────

  /// Speak an AI response aloud.
  ///
  /// [messageId] — the message's ID, used to highlight the active TTS bubble.
  /// If [messageId] matches the currently playing message, stops playback.
  Future<void> speak(String text, {String? messageId}) async {
    if (!_isTtsAvailable) return;

    // Toggle: tapping the same message's speaker button stops playback
    if (isPlaying && _activeTtsMessageId == messageId) {
      await stopSpeaking();
      return;
    }

    // Stop any current playback before starting new
    if (isPlaying) {
      await _repository.stopSpeaking();
    }

    _activeTtsMessageId = messageId;
    _setState(VoiceRecordingState.playing);

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

  /// Update the TTS speed and persist to Hive.
  ///
  /// [speed] should be between 0.5 and 2.0.
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
