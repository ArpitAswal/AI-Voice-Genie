/// Abstract repository for voice input (STT) and output (TTS) operations.
///
/// Phase 7 uses device-native implementations:
///   STT → speech_to_text package
///   TTS → flutter_tts package
///
/// Phase 8 Settings will allow switching to AI-powered alternatives:
///   STT → OpenAI Whisper API
///   TTS → OpenAI TTS API
///
/// Implementation: VoiceRepositoryImpl
abstract class VoiceRepository {
  // ── STT — Speech To Text ──────────────────────────────────────────────────

  /// Check whether STT is available on this device.
  ///
  /// Returns false if the device has no microphone or STT engine.
  Future<bool> isSttAvailable();

  /// Request microphone permission from the OS.
  ///
  /// Returns true if granted, false if denied.
  Future<bool> requestMicrophonePermission();

  /// Start listening for speech input.
  ///
  /// [onPartialResult] — called during speech with intermediate transcription
  /// [onFinalResult]   — called when speech ends with the complete transcript
  /// [onError]         — called if listening fails
  ///
  /// Listening auto-stops after [AppConstants.silenceTimeout] of silence.
  Future<void> startListening({
    required void Function(String partialText) onPartialResult,
    required void Function(String finalText) onFinalResult,
    required void Function(String errorKey) onError,
  });

  /// Stop listening and finalize the current transcript.
  Future<void> stopListening();

  // ── TTS — Text To Speech ──────────────────────────────────────────────────

  /// Check whether TTS is available on this device.
  Future<bool> isTtsAvailable();

  /// Speak the given text aloud.
  ///
  /// If TTS is already speaking, stops current playback first.
  /// [onComplete] — called when TTS finishes naturally.
  Future<void> speak(
      String text, {
        double speed = 1.0,
        void Function()? onComplete,
      });

  /// Stop TTS playback immediately.
  Future<void> stopSpeaking();

  /// Whether TTS is currently active.
  bool get isSpeaking;

  /// Release all platform resources.
  ///
  /// Called when VoiceProvider is disposed.
  Future<void> dispose();
}

// =============================================================================
// VOICE EXCEPTION
// =============================================================================

class VoiceException implements Exception {
  final String code;
  const VoiceException(this.code);

  @override
  String toString() => 'VoiceException(code: $code)';
}

class VoiceErrorCodes {
  static const String permissionDenied = 'microphone_permission_denied';
  static const String sttUnavailable = 'voice_input_failed';
  static const String ttsUnavailable = 'voice_input_failed';
  static const String listenFailed = 'voice_input_failed';
  static const String speakFailed = 'voice_input_failed';
}