import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../shared/widgets/chat_action_button.dart';
import '../voice_speech_provider.dart';

/// Microphone button with pulse animation for voice input.
///
/// States:
///   idle        → mic icon, normal color
///   listening   → mic icon, red + pulse animation + live transcript
///   processing  → small spinner
///   unavailable → mic icon, muted color, disabled
///   error       → mic icon, error color, briefly shown
///
/// The [onTranscriptReady] callback is passed to VoiceProvider.startListening()
/// and called when the final transcript is ready — typically used to
/// pre-fill the chat input field.
///
/// The optional [onPartialTranscript] callback is called on every partial
/// speech recognition result so the chat composer can update in real time
/// as the user speaks.
///
/// Usage in ChatInputBar:
/// ```dart
/// VoiceInputButton(
///   isTablet: isTablet,
///   onTranscriptReady: (text) => _controller.text = text,
///   onPartialTranscript: (partial) => _controller.text = partial,
/// )
/// ```
class VoiceInputButton extends StatefulWidget {
  final bool isTablet;
  final void Function(String transcript)? onTranscriptReady;

  /// Called on every intermediate result while the user is still speaking.
  /// Allows the parent to update the text field in real time.
  final void Function(String partial)? onPartialTranscript;
  final String? tooltip;

  const VoiceInputButton({
    super.key,
    required this.isTablet,
    required this.onTranscriptReady,
    this.onPartialTranscript,
    this.tooltip,
  });

  @override
  State<VoiceInputButton> createState() => VoiceInputButtonState();
}

class VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  /// Programmatically trigger voice listening (e.g. when opened from Home mic button).
  void triggerTap() {
    if (!mounted) return;
    final voiceProvider = context.read<VoiceProvider>();
    if (voiceProvider.isIdle ||
        voiceProvider.state == VoiceRecordingState.unavailable) {
      _handleTap(context, voiceProvider);
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context, VoiceProvider voiceProvider) {
    if (voiceProvider.isListening) {
      // Tap while listening → stop early and reset the pulse animation
      voiceProvider.stopListening();
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    } else if (voiceProvider.isIdle ||
        voiceProvider.isUnavailable ||
        voiceProvider.state == VoiceRecordingState.error) {
      // Tap while idle/unavailable → try to start listening
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
      voiceProvider.startListening(
        // Forward partial results to the parent widget (e.g. ChatInputBar)
        // so the text field updates continuously as the user speaks.
        onPartialTranscript: widget.onPartialTranscript,
        onTranscriptReady: (text) {
          if (mounted) {
            _pulseController.stop();
            _pulseController.reset();
          }
          widget.onTranscriptReady?.call(text);
        },
        onError: (errorKey) {
          if (mounted) {
            _pulseController.stop();
            _pulseController.reset();
            context.showError(
              AppLocalizations.of(context)!.translate(errorKey),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, _) {
        final state = voiceProvider.state;
        final isListening = state == VoiceRecordingState.listening;
        final isProcessing = state == VoiceRecordingState.processing;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic button with pulse
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isListening ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: ChatActionButton(
                icon: isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                onTap: isProcessing
                    ? null
                    : () => _handleTap(context, voiceProvider),
                isTablet: widget.isTablet,
                isLoading: isProcessing,
                tooltip: widget.tooltip,
                color: isListening
                    ? (context.isDark
                        ? AppColors.darkError
                        : AppColors.lightError)
                    : (context.isDark
                        ? AppColors.primaryDark
                        : AppColors.primaryLight),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: (context.isDark
                                  ? AppColors.darkError
                                  : AppColors.lightError)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            // "Listening..." label shown below button during recording
            if (isListening) ...[
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.translate('listening'),
                style: context.textTheme.labelSmall?.copyWith(
                    color: context.isDark
                        ? AppColors.darkError
                        : AppColors.lightError,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        );
      },
    );
  }
}
