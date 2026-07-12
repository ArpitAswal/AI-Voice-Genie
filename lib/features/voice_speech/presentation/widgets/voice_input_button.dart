import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';
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
/// Usage in ChatInputBar:
/// ```dart
/// VoiceInputButton(
///   isTablet: isTablet,
///   onTranscriptReady: (text) => _controller.text = text,
/// )
/// ```
class VoiceInputButton extends StatefulWidget {
  final bool isTablet;
  final void Function(String transcript)? onTranscriptReady;
  final String? tooltip;

  const VoiceInputButton({
    super.key,
    required this.isTablet,
    required this.onTranscriptReady,
    this.tooltip,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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
      // Tap while listening → stop early
      voiceProvider.stopListening();
      _pulseController.stop();
      _pulseController.reset();
    } else if (voiceProvider.isIdle ||
        voiceProvider.isUnavailable ||
        voiceProvider.state == VoiceRecordingState.error) {
      // Tap while idle/unavailable → try to start listening
      _pulseController.repeat(reverse: true);
      voiceProvider.startListening(
        onTranscriptReady: (text) {
          _pulseController.stop();
          _pulseController.reset();
          widget.onTranscriptReady!(text);
        },
        onError: (errorKey) {
          _pulseController.stop();
          _pulseController.reset();
          if (mounted) {
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

        final buttonSize = widget.isTablet ? 44.0 : 36.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic button with pulse
            GestureDetector(
              onTap: isProcessing
                  ? null
                  : () => _handleTap(context, voiceProvider),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isListening ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.primaryColor.withValues(alpha: 0.18),
                    boxShadow: isListening
                        ? [
                            BoxShadow(
                              color: AppColors.lightError.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isProcessing
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.primaryColor.withValues(alpha: 0.18),
                          ),
                        )
                      : Icon(
                          isListening
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          color: isListening
                              ? AppColors.lightError
                              : AppColors.primaryLight),
                ),
              ),
            ),
            // "Listening..." label shown below button during recording
            if (isListening) ...[
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.translate('listening'),
                style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightError, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        );
      },
    );
  }
}
