import 'package:ai_voice_genie/core/constants/app_colors.dart';
import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';

/// A unified circular icon button widget used across chat composer actions
/// (attachment, send, and voice listening buttons) to eliminate boilerplate
/// and guarantee uniform dimensions and styling.
class ChatActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool isTablet;
  final bool isLoading;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const ChatActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isTablet,
    this.tooltip,
    this.isLoading = false,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 44.0 : 38.0;

    Widget child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.primaryColor.withValues(alpha: 0.18),
        boxShadow: boxShadow,
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.primaryColor.withValues(alpha: 0.18),
              ),
            )
          : Icon(
              icon,
              color: color ?? AppColors.white,
              size: isTablet ? 22 : 20,
            ),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
