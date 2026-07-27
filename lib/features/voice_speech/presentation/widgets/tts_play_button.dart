import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../voice_speech_provider.dart';

/// Speaker icon button shown below AI message bubbles.
///
/// Tapping it plays the message content via TTS.
/// Tapping again (while the same message is playing) stops playback.
///
/// The button changes appearance based on whether THIS specific message
/// is currently playing — not just whether TTS is active globally.
///
/// States:
///   idle (this message)    → speaker icon, muted color
///   playing (this message) → stop icon, primary color, pulse animation
///   playing (other msg)    → speaker icon, disabled — another msg plays
///
/// Usage inside MessageBubble (AI responses only):
/// ```dart
/// TtsPlaybackButton(
///   messageId: message.id,
///   messageContent: message.content,
///   isTablet: isTablet,
/// )
/// ```
class TtsPlaybackButton extends StatefulWidget {
  /// Unique ID of the message this button belongs to
  final String messageId;

  /// The full text content to be spoken
  final String messageContent;

  final bool isTablet;

  const TtsPlaybackButton({
    super.key,
    required this.messageId,
    required this.messageContent,
    required this.isTablet,
  });

  @override
  State<TtsPlaybackButton> createState() => _TtsPlaybackButtonState();
}

class _TtsPlaybackButtonState extends State<TtsPlaybackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<VoiceProvider, (VoiceRecordingState, String?)>(
      // Only rebuild when state or active message ID changes
      selector: (_, p) => (p.state, p.activeTtsMessageId),
      builder: (context, data, _) {
        final state = data.$1;
        final activeMsgId = data.$2;

        final isThisMessagePlaying = state == VoiceRecordingState.playing &&
            activeMsgId == widget.messageId;

        // Drive pulse animation from playing state
        if (isThisMessagePlaying && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!isThisMessagePlaying && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = isThisMessagePlaying
                ? 1.0 + (_pulseController.value * 0.1)
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: _buildButton(
                context,
                isThisMessagePlaying: isThisMessagePlaying,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required bool isThisMessagePlaying,
  }) {
    final size = widget.isTablet ? 32.0 : 24.0;
    final iconSize = widget.isTablet ? 20.0 : 16.0;

    // Color logic
    Color bgColor;
    Color iconColor;
    if (isThisMessagePlaying) {
      bgColor = context.primaryColor.withValues(alpha: 0.15);
      iconColor = context.primaryColor;
    } else {
      bgColor = Colors.transparent;
      iconColor = context.textTheme.bodySmall?.color ?? context.primaryColor;
    }

    return GestureDetector(
      onTap: () => context.read<VoiceProvider>().speak(
            widget.messageContent,
            messageId: widget.messageId,
          ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
        ),
        child: Icon(
          isThisMessagePlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
