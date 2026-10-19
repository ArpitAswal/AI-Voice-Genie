import 'dart:async';

import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../localization/app_localizations.dart';
import '../router/app_routes.dart';

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
  /// 3: Error (highest - critical failure)
  /// 2: Warning (medium - caution / quota)
  /// 1: Success (lowest - informational / completion)
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
  final void Function(_AnimatedMessageOverlayState state)? onStateAttached;

  /// Extra vertical offset so two messages at the same edge don't overlap.
  final double stackOffset;

  const _AnimatedMessageOverlay({
    required this.slot,
    required this.type,
    required this.displayMessage,
    required this.displayDuration,
    required this.onDismissed,
    this.onStateAttached,
    this.actionLabel,
    this.onAction,
    this.stackOffset = 0,
  });

  @override
  State<_AnimatedMessageOverlay> createState() => _AnimatedMessageOverlayState();
}

class _AnimatedMessageOverlayState extends State<_AnimatedMessageOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // Bottom slot → slide from below; Top slot → slide from above.
    final beginOffset =
        widget.slot == _Slot.bottom ? const Offset(0, 1) : const Offset(0, -1);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _startTimer();

    widget.onStateAttached?.call(this);
  }

  void _startTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(widget.displayDuration, dismiss);
  }

  /// Resets the auto-dismiss timer when an identical message is re-triggered.
  void resetTimer() {
    if (_isDismissing) return;
    _startTimer();
  }

  /// Triggers exit animation, then calls [onDismissed].
  void dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
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
    final backgroundColor = _getBackgroundColor(widget.type, context.isDark);
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
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (_) => dismiss(),
            onHorizontalDragEnd: (_) => dismiss(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_getIcon(widget.type), color: Colors.white, size: 24),
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

/// Vertical stack offset between concurrent messages (card height 56 + gap 8).
const double _kStackOffset = 64.0;

/// Holds a reference to a live overlay so we can synchronously check and manage it.
class _LiveMessage {
  final OverlayEntry entry;
  final MessageConfig config;
  final String displayMessage;
  final _Slot slot;
  _AnimatedMessageOverlayState? _state;
  bool _dismissRequested = false;

  _LiveMessage({
    required this.entry,
    required this.config,
    required this.displayMessage,
    required this.slot,
  });

  void attachState(_AnimatedMessageOverlayState state) {
    _state = state;
    if (_dismissRequested) {
      state.dismiss();
    }
  }

  void dismiss() {
    _dismissRequested = true;
    _state?.dismiss();
  }

  void extendDuration() {
    _state?.resetTimer();
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
      // 1. Content deduplication: If exact same message and type is already showing, extend visibility
      if (current.config.type == config.type &&
          current.displayMessage == displayMessage &&
          current.config.actionLabel == config.actionLabel) {
        current.extendDuration();
        return;
      }

      // 2. Priority check within the same channel:
      // Higher or equal priority wins (same type → last-wins replacement, or higher severity preempts)
      if (config._priority >= current.config._priority) {
        _dismissChannel(channel);
      } else {
        // Current has higher priority (e.g. error is showing, warning arrives).
        // Drop the incoming message — the user should see the critical error.
        return;
      }
    }

    // 3. Stacking offset check against the other channel:
    final otherChannel =
        channel == _Channel.snackbar ? _Channel.toast : _Channel.snackbar;
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
    late final OverlayEntry entry;
    late final _LiveMessage liveMessage;

    entry = OverlayEntry(
      builder: (_) => _AnimatedMessageOverlay(
        slot: slot,
        type: config.type,
        displayMessage: displayMessage,
        displayDuration: config.duration,
        actionLabel: config.actionLabel,
        onAction: config.onAction,
        stackOffset: stackOffset,
        onStateAttached: (state) {
          liveMessage.attachState(state);
        },
        onDismissed: () {
          if (entry.mounted) {
            try {
              entry.remove();
            } catch (_) {}
          }
          if (_channelMessage(channel)?.entry == entry) {
            _setChannel(channel, null);
          }
        },
      ),
    );

    // Register live message synchronously to eliminate frame race conditions
    liveMessage = _LiveMessage(
      entry: entry,
      config: config,
      displayMessage: displayMessage,
      slot: slot,
    );
    _setChannel(channel, liveMessage);

    overlay.insert(entry);
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
    // Look up the overlay from the given context, or fall back to the global
    // navigator key's overlay for out-of-context notifications (e.g. session expired).
    final overlay = Overlay.maybeOf(context) ??
        AppRoutes.navigatorKey.currentState?.overlay;
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

/// Get background color for a message type without dynamic map allocations.
Color _getBackgroundColor(MessageType type, bool isDark) {
  switch (type) {
    case MessageType.success:
      return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
    case MessageType.error:
      return isDark ? AppColors.darkError : AppColors.lightError;
    case MessageType.warning:
      return isDark ? AppColors.darkWarning : AppColors.lightWarning;
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
