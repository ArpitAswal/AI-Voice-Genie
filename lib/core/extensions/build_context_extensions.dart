import 'package:flutter/material.dart';

/// Material 3 Window Size Classes based on viewport width:
/// - [compact]: Phone viewports in portrait (< 600dp)
/// - [medium]: Foldables, tablet portrait viewports (600dp - 839dp)
/// - [expanded]: Large tablets in landscape, desktop viewports (>= 840dp)
enum WindowSizeClass {
  /// Width < 600dp: compact phones in portrait
  compact,

  /// Width 600dp - 839dp: tablets in portrait, foldables
  medium,

  /// Width >= 840dp: tablets in landscape, desktop displays
  expanded,
}

/// BuildContext extensions for Material 3 responsive layout detection and spacing.
///
/// Follows Material 3 Breakpoints and the 8dp Grid System:
/// - Compact (< 600dp): 16dp margins/spacing
/// - Medium (600dp - 839dp): 24dp margins/spacing
/// - Expanded (>= 840dp): 24dp margins/spacing
///
/// Usage: `context.isCompact`, `context.isMedium`, `context.isExpanded`, `context.horizontalPadding`
extension ResponsiveExtension on BuildContext {
  /// Current screen width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Current screen height in logical pixels.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Material 3 Window Size Class computed dynamically from viewport width.
  WindowSizeClass get windowSizeClass {
    final width = screenWidth;
    if (width < 600.0) return WindowSizeClass.compact;
    if (width < 840.0) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// Compact viewport: width < 600dp (standard phones in portrait).
  bool get isCompact => screenWidth < 600.0;

  /// Medium viewport: 600dp <= width < 840dp (tablets in portrait, large foldables).
  bool get isMedium => screenWidth >= 600.0 && screenWidth < 840.0;

  /// Expanded viewport: width >= 840dp (tablets in landscape, desktop).
  bool get isExpanded => screenWidth >= 840.0;

  /// Backwards-compatible tablet check: width >= 600dp (medium or expanded).
  bool get isTablet => screenWidth >= 600.0;

  /// Height-constrained or narrow display check for vertical scaling fallbacks.
  @Deprecated('Use windowSizeClass, isCompact, or local BoxConstraints')
  bool get isSmallPhone => screenWidth <= 360.0 || screenHeight <= 550.0;

  /// Returns responsive value based on device type.
  T responsive<T>({required T mobile, T? tablet}) {
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Normalized horizontal padding based on the 8dp grid:
  /// - Compact (< 600dp): 16.0dp
  /// - Medium / Expanded (>= 600dp): 24.0dp
  double get horizontalPadding => isCompact ? 16.0 : 24.0;

  /// Normalized vertical spacing based on the 8dp grid:
  /// - Compact (< 600dp): 16.0dp
  /// - Medium / Expanded (>= 600dp): 24.0dp
  double get verticalSpacing => isCompact ? 16.0 : 24.0;

  // ── Stepped Icon Size Tokens ──────────────────────────────────────────────

  /// Dense icon token (18.0dp) for inline badges, tags, compact chips.
  double get iconDense => 18.0;

  /// Standard icon token (24.0dp) for app bar actions, button icons, form suffixes.
  double get iconStandard => 24.0;

  /// Avatar icon token (40.0dp on compact, 48.0dp on medium/expanded) for brand marks and avatars.
  double get iconAvatar => isCompact ? 40.0 : 48.0;
}

/// BuildContext extensions for theme and color access.
///
/// Usage: `context.primaryColor`, `context.isDark`, `context.textTheme`
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
}

/// BuildContext extensions for fine-grained MediaQuery shortcuts.
///
/// Uses fine-grained MediaQuery methods ([viewPaddingOf], [viewInsetsOf], [paddingOf])
/// to avoid unnecessary widget rebuilds when unrelated metrics change.
extension MediaQueryExtension on BuildContext {
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
  double get topPadding => MediaQuery.paddingOf(this).top;
  double get bottomPadding => MediaQuery.paddingOf(this).bottom;
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
}

/// BuildContext extensions for responsive typography scaling across devices and orientations.
///
/// Steps cleanly through Material 3 semantic roles (`display`, `headline`, `title`, `body`, `label`)
/// based on local [BoxConstraints] first, falling back to window size metrics if null.
extension ResponsiveTypographyExtension on BuildContext {
  /// Responsive greeting/subheading style ("Welcome to").
  ///
  /// Steps through M3 semantic roles:
  /// - Tight constraints (maxHeight <= 550 or maxWidth <= 360): [titleMedium] (16sp)
  /// - Tablet portrait (spacious width >= 600, height >= 750, vertical): [headlineSmall] (24sp)
  /// - Standard / default viewport: [titleLarge] (22sp)
  TextStyle? subHeaderStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight <= 550 || constraints.maxWidth <= 360) {
        return textTheme.titleMedium;
      }
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return textTheme.headlineSmall;
      }
      return textTheme.titleLarge;
    }

    // Fallback if called without LayoutBuilder constraints:
    if (size.height <= 550 || size.width <= 360) {
      return textTheme.titleMedium;
    }
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.headlineSmall;
    }
    return textTheme.titleLarge;
  }

  /// Responsive app title/headline style ("AI Voice Genie").
  ///
  /// Steps through M3 semantic roles:
  /// - Tight constraints (maxHeight <= 550 or maxWidth <= 360): [headlineMedium] (28sp)
  /// - Tablet portrait (spacious width >= 600, height >= 750, vertical): [displaySmall] (36sp)
  /// - Standard / default viewport: [headlineLarge] (32sp)
  TextStyle? titleHeaderStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight <= 550 || constraints.maxWidth <= 360) {
        return textTheme.headlineMedium;
      }
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return textTheme.displaySmall;
      }
      return textTheme.headlineLarge;
    }

    // Fallback if called without LayoutBuilder constraints:
    if (size.height <= 550 || size.width <= 360) {
      return textTheme.headlineMedium;
    }
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.displaySmall;
    }
    return textTheme.headlineLarge;
  }

  /// Responsive button label style.
  ///
  /// Steps through M3 semantic roles:
  /// - Tight constraints (maxHeight <= 550 or maxWidth <= 360): [labelLarge] (14sp, bold/w600)
  /// - Standard / default viewport: [titleMedium] (16sp, w500)
  TextStyle? buttonLabelStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);

    if (constraints != null) {
      if (constraints.maxHeight <= 550 || constraints.maxWidth <= 360) {
        return textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
      }
      return textTheme.titleMedium;
    }

    // Fallback if called without LayoutBuilder constraints:
    if (size.height <= 550 || size.width <= 360) {
      return textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    }
    return textTheme.titleMedium;
  }

  /// Responsive legal / disclaimer note style.
  ///
  /// Steps through M3 semantic roles:
  /// - Tablet portrait: [bodyLarge] (16sp)
  /// - Landscape pane: [bodyMedium] (14sp)
  /// - Compact / standard: [bodySmall] (12sp)
  TextStyle? legalTextStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return textTheme.bodyLarge;
      } else if (isLandscape) {
        return textTheme.bodyMedium;
      }
      return textTheme.bodySmall;
    }

    // Fallback if called without LayoutBuilder constraints:
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.bodyMedium;
    }
    return textTheme.bodySmall;
  }

  /// Responsive body/description text style.
  ///
  /// Steps through M3 semantic roles:
  /// - Tight constraints (maxHeight <= 550 or maxWidth <= 360): [bodySmall] (12sp)
  /// - Tablet portrait (spacious width >= 600, height >= 750, vertical): [bodyLarge] (16sp)
  /// - Standard viewport: [bodyMedium] (14sp)
  TextStyle? descStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight <= 550 || constraints.maxWidth <= 360) {
        return textTheme.bodySmall;
      }
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return textTheme.bodyLarge;
      }
      return textTheme.bodyMedium;
    }

    // Fallback if called without LayoutBuilder constraints:
    if (size.height <= 550 || size.width <= 360) {
      return textTheme.bodySmall;
    }
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.bodyLarge;
    }
    return textTheme.bodyMedium;
  }

  /// Responsive clickable legal link style (underlined, primary color).
  TextStyle? legalLinkStyle([BoxConstraints? constraints]) {
    return legalTextStyle(constraints)?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    );
  }
}
