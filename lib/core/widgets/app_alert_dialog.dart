import 'package:flutter/material.dart';
import '../extensions/build_context_extensions.dart';

/// A reusable, adaptive, and consistently styled AlertDialog for the application.
///
/// Automatically enforces:
/// - Adaptive max width clamping (max 380dp on phones, max 460dp on tablets)
/// - Safe responsive inset margins across compact, medium, and expanded viewports
/// - Landscape phone protection (`height <= 550` guard)
/// - Adaptive typography (scaled headline/title and body tokens)
/// - Material 3 action overflow handling (`actionsOverflowButtonSpacing`)
/// - Accessible minimum touch target sizes for all action buttons (>= 44-48dp)
/// - Theme-aware surface styling in light and dark modes
class AppAlertDialog extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? iconPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets? insetPadding;
  final bool scrollable;
  final MainAxisAlignment? actionsAlignment;

  const AppAlertDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.iconPadding,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.insetPadding,
    this.scrollable = false,
    this.actionsAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Follow landscape phone guard: if orientation is landscape but height <= 550, treat as compact
    final isShortHeight = size.height <= 550.0;
    final isTablet = size.width >= 600.0 && !isShortHeight;
    final isCompact = !isTablet;

    // Adaptive maximum dialog width clamping to prevent oversized banners on tablets
    final maxDialogWidth = isTablet ? 460.0 : 380.0;
    final horizontalInset = size.width > (maxDialogWidth + 32.0)
        ? (size.width - maxDialogWidth) / 2.0
        : (isShortHeight ? 16.0 : 20.0);
    final verticalInset = isShortHeight ? 16.0 : 24.0;

    final effectiveInsetPadding = insetPadding ??
        EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: verticalInset,
        );

    final effectiveTitlePadding = titlePadding ??
        EdgeInsets.fromLTRB(
          isCompact ? 20.0 : 28.0,
          isShortHeight ? 16.0 : (isCompact ? 20.0 : 24.0),
          isCompact ? 20.0 : 28.0,
          isShortHeight ? 8.0 : 12.0,
        );

    final effectiveContentPadding = contentPadding ??
        EdgeInsets.fromLTRB(
          isCompact ? 20.0 : 28.0,
          0.0,
          isCompact ? 20.0 : 28.0,
          isShortHeight ? 8.0 : 12.0,
        );

    final effectiveActionsPadding = actionsPadding ??
        EdgeInsets.fromLTRB(
          isCompact ? 16.0 : 24.0,
          0.0,
          isCompact ? 16.0 : 24.0,
          isShortHeight ? 8.0 : (isCompact ? 12.0 : 16.0),
        );

    final titleStyle = (isTablet
            ? context.textTheme.headlineSmall
            : context.textTheme.titleLarge)
        ?.copyWith(
      color: context.colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    );

    final contentStyle =
        (isTablet ? context.textTheme.bodyLarge : context.textTheme.bodyMedium)
            ?.copyWith(
      color: context.colorScheme.tertiary,
      height: 1.45,
    );

    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: (isTablet
                    ? context.textTheme.titleMedium
                    : context.textTheme.labelLarge)
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: context.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 24.0 : 20.0),
        ),
        icon: icon,
        iconPadding: iconPadding,
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
        actionsAlignment: actionsAlignment ?? MainAxisAlignment.end,
        actionsOverflowButtonSpacing: 8.0,
        actionsOverflowDirection: VerticalDirection.down,
        titlePadding: effectiveTitlePadding,
        contentPadding: effectiveContentPadding,
        actionsPadding: effectiveActionsPadding,
        insetPadding: effectiveInsetPadding,
        titleTextStyle: titleStyle,
        contentTextStyle: contentStyle,
      ),
    );
  }
}
