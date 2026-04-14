import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
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

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        8,
        context.horizontalPadding,
        context.bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
                context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Attach Button (stubbed until Phase 5/6) ────────────────────────
          _ActionButton(
            icon: Icons.attach_file_rounded,
            onTap: widget.onAttachTap,
            tooltip: 'Attach',
            isTablet: widget.isTablet,
          ),

          const SizedBox(width: 8),

          // ── Text Input Field ───────────────────────────────────────────────
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.isTablet ? 160 : 120,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isGenerating,
                maxLines: null, // Expands with content
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: widget.isTablet ? 16 : 14,
                ),
                decoration: InputDecoration(
                  hintText: l10n.translate('type_message'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  // fillColor: context.isDark
                  //     ? AppColors.darkCardBackground
                  //     : AppColors.greyLight.withValues(alpha: 0.6),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.isTablet ? 20 : 16,
                    vertical: widget.isTablet ? 14 : 10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

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
      ),
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
            ? Padding(
                padding: const EdgeInsets.all(12),
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
    final iconColor = color ??
        (context.isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary);

    return IconButton(
      icon: Icon(icon,
          color: onTap != null ? iconColor : iconColor.withValues(alpha: 0.4)),
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: isTablet ? 26 : 22,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: isTablet ? 40 : 36,
        minHeight: isTablet ? 40 : 36,
      ),
    );
  }
}
