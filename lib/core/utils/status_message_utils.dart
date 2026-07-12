import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../localization/app_localizations.dart';

// =============================================================================
// ENUMS & CONFIG
// =============================================================================

/// Message severity / type.
enum MessageType { success, error, warning }

/// Which screen edge the message occupies.
enum _Slot { top, bottom }

/// Which notification channel the message belongs to.
enum _Channel { snackbar, toast }

/// Message configuration.
class MessageConfig {
  final String message;
  final MessageType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MessageConfig({
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 2),
    this.actionLabel,
    this.onAction,
  });

  /// Success → bottom; error / warning → top.
  _Slot get _slot {
    switch (type) {
      case MessageType.success:
        return _Slot.bottom;
      case MessageType.error:
      case MessageType.warning:
        return _Slot.top;
    }
  }

  /// Higher number = higher priority.
  int get _priority {
    switch (type) {
      case MessageType.error:
        return 3;
      case MessageType.warning:
        return 2;
      case MessageType.success:
        return 1;
    }
  }
}

// =============================================================================
// ANIMATED OVERLAY WIDGET
// =============================================================================

/// A slide-in / slide-out overlay entry backed by an [AnimationController].
class _AnimatedMessageOverlay extends StatefulWidget {
  final _Slot slot;
  final MessageType type;
  final String displayMessage;
  final Duration displayDuration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  /// Extra vertical offset so two messages at the same edge don't overlap.
  final double stackOffset;

  const _AnimatedMessageOverlay({
    super.key,
    required this.slot,
    required this.type,
    required this.displayMessage,
    required this.displayDuration,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
    this.stackOffset = 0,
  });

  @override
  State<_AnimatedMessageOverlay> createState() =>
      _AnimatedMessageOverlayState();
}

class _AnimatedMessageOverlayState extends State<_AnimatedMessageOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Bottom slot → slide from below; Top slot → slide from above.
    final beginOffset = widget.slot == _Slot.bottom
        ? const Offset(0, 1)
        : const Offset(0, -1);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _autoDismissTimer = Timer(widget.displayDuration, dismiss);
  }

  /// Triggers exit animation, then calls [onDismissed].
  void dismiss() {
    _autoDismissTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(widget.type);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Base edge inset + stacking offset.
    final double topInset = topPadding + 16 + widget.stackOffset;
    final double bottomInset = bottomPadding + 16 + widget.stackOffset;

    return Positioned(
      top: widget.slot == _Slot.top ? topInset : null,
      bottom: widget.slot == _Slot.bottom ? bottomInset : null,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragEnd: (_) => dismiss(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors['background'],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_getIcon(widget.type), color: colors['icon'], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.displayMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null && widget.onAction != null)
                    TextButton(
                      onPressed: () {
                        widget.onAction!();
                        dismiss();
                      },
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MESSAGE MANAGER (singleton – channel-based dedup & priority)
// =============================================================================

/// Height of one message card + gap between stacked messages.
const double _kMessageHeight = 56;
const double _kStackGap = 8;
const double _kStackOffset = _kMessageHeight + _kStackGap;

/// Holds a reference to a live overlay so we can dismiss / replace it.
class _LiveMessage {
  final OverlayEntry entry;
  final _AnimatedMessageOverlayState state;
  final MessageConfig config;
  final _Slot slot;

  _LiveMessage(this.entry, this.state, this.config, this.slot);

  void dismiss() {
    state.dismiss();
  }
}

class _MessageManager {
  _MessageManager._();
  static final instance = _MessageManager._();

  /// One live message per channel.
  _LiveMessage? _snackbar;
  _LiveMessage? _toast;

  // ---------------------------------------------------------------------------
  // Public entry-point
  // ---------------------------------------------------------------------------

  /// Show a message respecting channel-based dedup & priority.
  ///
  /// Dedup/priority rules apply *within* the same [channel] only.
  /// Two different channels can show simultaneously — if they share the same
  /// screen edge, the later one is stacked with an offset.
  void show({
    required OverlayState overlay,
    required MessageConfig config,
    required String displayMessage,
    required _Channel channel,
  }) {
    if (!overlay.mounted) return;

    final targetSlot = config._slot;
    final current = _channelMessage(channel);

    if (current != null) {
      // ── Same channel already has a message ──
      if (config._priority >= current.config._priority) {
        // Incoming wins (same type → last-wins dedup, or higher priority).
        _dismissChannel(channel);
      } else {
        // Current has higher priority (e.g. error is showing, warning arrives).
        // Drop the incoming message — the user should see the error.
        return;
      }
    }

    // Check whether the OTHER channel already occupies the same slot.
    final otherChannel = channel == _Channel.snackbar
        ? _Channel.toast
        : _Channel.snackbar;
    final otherMsg = _channelMessage(otherChannel);
    final bool needsStack = otherMsg != null && otherMsg.slot == targetSlot;

    _insert(
      overlay,
      config,
      displayMessage,
      targetSlot,
      channel,
      stackOffset: needsStack ? _kStackOffset : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  _LiveMessage? _channelMessage(_Channel ch) =>
      ch == _Channel.snackbar ? _snackbar : _toast;

  void _setChannel(_Channel ch, _LiveMessage? msg) {
    if (ch == _Channel.snackbar) {
      _snackbar = msg;
    } else {
      _toast = msg;
    }
  }

  void _dismissChannel(_Channel ch) {
    final msg = _channelMessage(ch);
    if (msg != null) {
      msg.dismiss();
      _setChannel(ch, null);
    }
  }

  void _insert(
      OverlayState overlay,
      MessageConfig config,
      String displayMessage,
      _Slot slot,
      _Channel channel, {
        double stackOffset = 0,
      }) {
    late OverlayEntry entry;
    final key = GlobalKey<_AnimatedMessageOverlayState>();

    entry = OverlayEntry(
      builder: (_) => _AnimatedMessageOverlay(
        key: key,
        slot: slot,
        type: config.type,
        displayMessage: displayMessage,
        displayDuration: config.duration,
        actionLabel: config.actionLabel,
        onAction: config.onAction,
        stackOffset: stackOffset,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_channelMessage(channel)?.entry == entry) {
            _setChannel(channel, null);
          }
        },
      ),
    );

    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = key.currentState;
      if (state != null) {
        _setChannel(channel, _LiveMessage(entry, state, config, slot));
      }
    });
  }
}

// =============================================================================
// PUBLIC API — MessageUtils
// =============================================================================

class MessageUtils {
  // --------------------------------------------------------------------------
  // SNACKBAR-STYLE METHODS
  // --------------------------------------------------------------------------

  /// Show a success message (appears at the bottom, slides up).
  static void showSuccess(
      BuildContext context,
      String message, {
        Duration? duration,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.success,
        duration: duration ?? const Duration(seconds: 2),
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      _Channel.snackbar,
    );
  }

  /// Show an error message (appears at the top, slides down).
  static void showError(
      BuildContext context,
      String message, {
        Duration? duration,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.error,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      _Channel.snackbar,
    );
  }

  /// Show a warning message (appears at the top, slides down).
  static void showWarning(
      BuildContext context,
      String message, {
        Duration? duration,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.warning,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      _Channel.snackbar,
    );
  }

  // --------------------------------------------------------------------------
  // TOAST-STYLE METHODS
  // --------------------------------------------------------------------------

  /// Show a success toast message (bottom, slides up).
  static void showSuccessToast(
      BuildContext context,
      String message, {
        Duration? duration,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.success,
        duration: duration ?? const Duration(seconds: 2),
      ),
      _Channel.toast,
    );
  }

  /// Show an error toast message (top, slides down).
  static void showErrorToast(
      BuildContext context,
      String message, {
        Duration? duration,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.error,
        duration: duration ?? const Duration(seconds: 4),
      ),
      _Channel.toast,
    );
  }

  /// Show a warning toast message (top, slides down).
  static void showWarningToast(
      BuildContext context,
      String message, {
        Duration? duration,
      }) {
    _showMessage(
      context,
      MessageConfig(
        message: message,
        type: MessageType.warning,
        duration: duration ?? const Duration(seconds: 4),
      ),
      _Channel.toast,
    );
  }

  /// Show a success toast using a pre-captured [OverlayState].
  ///
  /// Safe to call after async gaps. [resolvedMessage] should already be
  /// translated.
  static void showSuccessToastWithOverlay(
      OverlayState overlay,
      String resolvedMessage, {
        Duration? duration,
      }) {
    _MessageManager.instance.show(
      overlay: overlay,
      config: MessageConfig(
        message: resolvedMessage,
        type: MessageType.success,
        duration: duration ?? const Duration(seconds: 2),
      ),
      displayMessage: resolvedMessage,
      channel: _Channel.toast,
    );
  }

  // --------------------------------------------------------------------------
  // INTERNAL
  // --------------------------------------------------------------------------

  /// Unified entry-point: resolve localisation, then delegate to the manager.
  static void _showMessage(
      BuildContext context,
      MessageConfig config,
      _Channel channel,
      ) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null || !overlay.mounted) return;

    final loc = AppLocalizations.of(context);
    final displayMessage = loc?.translate(config.message) ?? config.message;

    _MessageManager.instance.show(
      overlay: overlay,
      config: config,
      displayMessage: displayMessage,
      channel: channel,
    );
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Get colours for a message type.
Map<String, Color> _getColors(MessageType type) {
  switch (type) {
    case MessageType.success:
      return {'background': AppColors.success, 'icon': Colors.white};
    case MessageType.error:
      return {'background': AppColors.lightError, 'icon': Colors.white};
    case MessageType.warning:
      return {'background': AppColors.warning, 'icon': Colors.white};
  }
}

/// Get icon for a message type.
IconData _getIcon(MessageType type) {
  switch (type) {
    case MessageType.success:
      return Icons.check_circle;
    case MessageType.error:
      return Icons.error;
    case MessageType.warning:
      return Icons.warning;
  }
}

// =============================================================================
// CONTEXT EXTENSIONS
// =============================================================================

/// Extension methods for easy access from [BuildContext].
extension MessageExtensions on BuildContext {
  // ---------- Snackbar-style ----------

  /// Show success snackbar
  void showSuccess(
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
        Duration? dur,
      }) {
    MessageUtils.showSuccess(
      this,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: dur,
    );
  }

  /// Show error snackbar
  void showError(
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
        Duration? dur,
      }) {
    MessageUtils.showError(
      this,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: dur,
    );
  }

  /// Show warning snackbar
  void showWarning(
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
        Duration? dur,
      }) {
    MessageUtils.showWarning(
      this,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: dur,
    );
  }

  // ---------- Toast-style ----------

  /// Show success toast
  void showSuccessToast(String message) {
    MessageUtils.showSuccessToast(this, message);
  }

  /// Show error toast
  void showErrorToast(String message) {
    MessageUtils.showErrorToast(this, message);
  }

  /// Show warning toast
  void showWarningToast(String message) {
    MessageUtils.showWarningToast(this, message);
  }
}
