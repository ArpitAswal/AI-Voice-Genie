import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';

/// Displays text with a smooth typewriter reveal animation.
///
/// The animation runs at ~25 characters/second (40ms per character),
/// matching the feel of GPT-4 web responses.
///
/// **Behaviour:**
///   - If [animate] is true  → reveals text character-by-character from empty
///   - If [animate] is false → renders the full [text] instantly as plain Text
///   - Once the animation completes the widget becomes a static Text, so it
///     produces zero ongoing overhead for messages that have already animated.
class TypewriterText extends StatefulWidget {
  final String text;

  /// Whether to run the typewriter animation.
  /// Pass true only for the most recent AI message.
  final bool animate;

  /// Text style applied to both the animating and static states.
  final TextStyle? style;

  /// Characters revealed per tick. Default: 1
  final int charsPerTick;

  /// Duration of each animation tick. Default: 40ms (≈25 chars/sec like GPT-4)
  final Duration tickDuration;

  const TypewriterText({
    super.key,
    required this.text,
    required this.animate,
    this.style,
    this.charsPerTick = 1,
    this.tickDuration = const Duration(milliseconds: 40),
    this.onTick,
  });

  /// Called on every animation tick (each character reveal).
  /// Use this to trigger auto-scroll so the latest text stays visible.
  final VoidCallback? onTick;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _visibleCount = 0;
  bool _animationDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.text.isNotEmpty) {
      _startAnimation();
    } else {
      _animationDone = true;
      _visibleCount = widget.text.length;
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final textChanged = oldWidget.text != widget.text;

    // If the text content changed mid-animation, restart cleanly.
    if (textChanged) {
      _timer?.cancel();
      _animationDone = false;
      _visibleCount = 0;
      if (widget.animate) {
        _startAnimation();
      } else {
        _animationDone = true;
        _visibleCount = widget.text.length;
      }
    }
  }

  void _startAnimation() {
    _timer = Timer.periodic(widget.tickDuration, (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      setState(() {
        _visibleCount =
            (_visibleCount + widget.charsPerTick).clamp(0, widget.text.length);
        if (_visibleCount >= widget.text.length) {
          _animationDone = true;
          _timer?.cancel();
        }
      });
      // Notify parent to scroll after every reveal so the latest text stays visible
      widget.onTick?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When animation is complete (or never needed), use a simple Text
    // to avoid any ongoing StatefulWidget overhead.
    if (_animationDone || !widget.animate) {
      return Text(
        widget.text,
        style: widget.style ??
            context.textTheme.bodySmall?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.black,
            ),
      );
    }

    // Animation in progress — show only the visible slice
    final visibleText = widget.text.substring(0, _visibleCount);
    return Text(
      visibleText,
      style: widget.style ??
          context.textTheme.bodySmall?.copyWith(
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: context.isDark ? AppColors.white : AppColors.black,
          ),
    );
  }
}
