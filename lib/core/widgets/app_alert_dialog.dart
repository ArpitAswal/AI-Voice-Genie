import 'package:flutter/material.dart';
import '../extensions/build_context_extensions.dart';

/// A reusable, consistently styled AlertDialog for the application.
/// Enforces app-wide corner radius and background color in dark/light modes.
class AppAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets insetPadding;

  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: title,
      content: content,
      actions: actions,
      titlePadding: titlePadding ?? const EdgeInsets.fromLTRB(24, 16, 24, 12),
      contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(24, 0, 24, 0),
      actionsPadding: actionsPadding ??
          const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8.0),
      insetPadding: insetPadding,
      titleTextStyle: context.subHeaderStyle()?.copyWith(color: context.colorScheme.primary),
      contentTextStyle: context.descStyle()?.copyWith(color: context.colorScheme.tertiary),
    );
  }
}
