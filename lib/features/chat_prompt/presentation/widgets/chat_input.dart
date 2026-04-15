import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_validators.dart';

/// Chat input bar with text field, send button, and stubbed action buttons.
///
/// Voice button stub → wired in Phase 7
/// Attach button stub → wired in Phase 5 (image) and Phase 6 (PDF)
///
/// Calls [onSend] with the trimmed prompt when the send button is tapped
/// or when the user submits the text field (keyboard action).
class ChatInputBar extends StatefulWidget {
  final bool isGenerating;
  final bool isTablet;
  final Future<void> Function(String prompt) onSend;

  /// Optional callback for voice input — null until Phase 7
  final VoidCallback? onVoiceTap;

  /// Optional callback for attach (image/PDF) — null until Phase 5/6
  final VoidCallback? onAttachTap;

  const ChatInputBar({
    super.key,
    required this.isGenerating,
    required this.isTablet,
    required this.onSend,
    this.onVoiceTap,
    this.onAttachTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final canSend = _controller.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final prompt = _controller.text.trim();
    final error = Validators.validatePrompt(prompt, context: context);
    if (error != null) return;

    _controller.clear();
    setState(() => _canSend = false);

    await widget.onSend(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false, // Show when scrolling
            child: context.themedTextField(
                controller: _controller,
                scrollController: _scrollController,
                // focusNode: _focusNode,
                enabled: !widget.isGenerating,
                maxLines: null, // Expands with content
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                hint: l10n.translate('type_message'),
                border: InputBorder.none,
                contentPad: EdgeInsets.all(8.0)), // Add subtle padding
          ),
        ),

        // ── Voice or Send Button ───────────────────────────────────────────
        // When text is empty: show voice button (stub)
        // When text has content: show send button
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _canSend
              ? _SendButton(
                  key: const ValueKey('send'),
                  onTap: widget.isGenerating ? null : _handleSend,
                  isGenerating: widget.isGenerating,
                  isTablet: widget.isTablet,
                )
              : _ActionButton(
                  key: const ValueKey('voice'),
                  icon: Icons.mic_rounded,
                  onTap: widget.onVoiceTap,
                  tooltip: l10n.translate('tap_to_speak'),
                  isTablet: widget.isTablet,
                  color: AppColors.primaryLight,
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// SEND BUTTON
// =============================================================================

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isGenerating;
  final bool isTablet;

  const _SendButton({
    super.key,
    required this.onTap,
    required this.isGenerating,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 48.0 : 42.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isGenerating
              ? AppColors.primaryLight.withValues(alpha: 0.5)
              : AppColors.primaryLight,
        ),
        child: isGenerating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Icon(
                Icons.send_rounded,
                color: AppColors.white,
                size: isTablet ? 22 : 18,
              ),
      ),
    );
  }
}

// =============================================================================
// ACTION BUTTON — for attach and voice
// =============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isTablet;
  final Color? color;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.isTablet,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 48.0 : 42.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withValues(alpha: 0.5)),
        child: Icon(icon),
      ),
    );
  }
}
