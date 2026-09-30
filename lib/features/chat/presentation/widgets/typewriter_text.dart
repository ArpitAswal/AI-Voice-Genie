import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.onAnimationStart,
    this.onComplete,
  });

  /// Called on every animation tick (each character reveal).
  /// Use this to trigger auto-scroll so the latest text stays visible.
  final VoidCallback? onTick;

  /// Called once when the typewriter animation begins.
  final VoidCallback? onAnimationStart;

  /// Called once when the typewriter animation completes all characters.
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with AutomaticKeepAliveClientMixin {
  Timer? _timer;
  int _visibleCount = 0;
  bool _animationDone = false;

  @override
  bool get wantKeepAlive => widget.animate && !_animationDone;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.text.isNotEmpty) {
      widget.onAnimationStart?.call();
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
      updateKeepAlive();
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
          widget.onComplete?.call();
          updateKeepAlive();
        }
      });
      // Notify parent to scroll after every reveal so the latest text stays visible
      widget.onTick?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.animate && !_animationDone) {
      widget.onComplete?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final defaultStyle = widget.style ??
        context.textTheme.bodySmall?.copyWith(
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: context.isDark ? AppColors.white : AppColors.black,
        );

    // Render markdown continuously during typewriter reveal as well as when complete,
    // ensuring consistent styling (headings, bold, lists, links) throughout the streaming animation.
    final textToShow = (_animationDone || !widget.animate)
        ? widget.text
        : widget.text.substring(0, _visibleCount);

    return MarkdownBody(
      data: textToShow,
      selectable:
          false, // Ensures link taps are not swallowed by text selection gesture arena
      onTapLink: (text, href, title) => _launchUrlSafely(href),
      styleSheet: _buildMarkdownStyleSheet(context, defaultStyle),
    );
  }

  /// Opens web links in the default browser across Android and iOS.
  Future<void> _launchUrlSafely(String? href) async {
    if (href == null || href.isEmpty) return;
    try {
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: attempt direct launch without canLaunchUrl guard
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ TypewriterText: Error opening link $href: $e');
    }
  }

  /// Builds theme-aware markdown styling for the chat bubble.
  MarkdownStyleSheet _buildMarkdownStyleSheet(
    BuildContext context,
    TextStyle? defaultStyle,
  ) {
    final textColor = defaultStyle?.color ??
        (context.isDark ? AppColors.white : AppColors.black);

    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: defaultStyle,
      pPadding: EdgeInsets.zero,
      a: defaultStyle?.copyWith(
        color: context.primaryColor,
        decoration: TextDecoration.underline,
        decorationColor: context.primaryColor,
        fontWeight: FontWeight.w600,
      ),
      strong: defaultStyle?.copyWith(
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      em: defaultStyle?.copyWith(
        fontStyle: FontStyle.italic,
        color: textColor,
      ),
      h1: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      h2: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      h3: context.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      listBullet: defaultStyle?.copyWith(
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      listIndent: 16.0,
      code: defaultStyle?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: context.isDark
            ? AppColors.white.withValues(alpha: 0.1)
            : AppColors.black.withValues(alpha: 0.08),
      ),
      codeblockDecoration: BoxDecoration(
        color: context.isDark
            ? AppColors.cardDark.withValues(alpha: 0.7)
            : AppColors.cardLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquote: defaultStyle?.copyWith(
        fontStyle: FontStyle.italic,
        color: textColor.withValues(alpha: 0.85),
      ),
      blockquoteDecoration: BoxDecoration(
        color: context.isDark
            ? AppColors.primaryLight.withValues(alpha: 0.15)
            : AppColors.primaryDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: context.primaryColor,
            width: 3,
          ),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
    );
  }
}
