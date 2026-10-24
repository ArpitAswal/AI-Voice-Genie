import 'package:flutter/material.dart';

/// BuildContext extensions for responsive layout detection.
///
/// Follows Material 3 Window Size Class breakpoints:
///   - Compact (< 600dp): phones in portrait
///   - Medium (600dp - 839dp): tablets in portrait, large foldables
///   - Expanded (>= 840dp): tablets in landscape, desktop viewports
///
/// Usage: context.isTablet, context.screenWidth, context.responsive(...)
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Tablet: width >= 600px (Material 3 medium window size class breakpoint)
  bool get isTablet => screenWidth >= 600;

  /// Small phone or height-constrained device: width <= 360px or height <= 550px
  bool get isSmallPhone => screenWidth <= 360 || screenHeight <= 550;

  /// Returns responsive value based on device type
  T responsive<T>({required T mobile, T? tablet}) {
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Responsive horizontal padding
  double get horizontalPadding => isTablet ? 32.0 : 24.0;

  /// Responsive vertical spacing
  double get verticalSpacing => isTablet ? 24.0 : 16.0;
}

/// BuildContext extensions for theme and color access.
///
/// Usage: context.primaryColor, context.isDark, context.textTheme
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
}

/// BuildContext extensions for MediaQuery shortcuts.
///
/// Uses fine-grained MediaQuery methods ([paddingOf], [viewInsetsOf], [viewPaddingOf])
/// to avoid unnecessary widget rebuilds when unrelated MediaQuery metrics change.
///
/// Usage: context.topPadding, context.bottomPadding, context.isKeyboardVisible
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
/// Follows Material 3 role-based scaling considering available layout space from [LayoutBuilder]:
///   - Tablet portrait (spacious width >= 600px & height >= 750px): steps up within role family
///   - Tablet landscape (side-by-side pane) or phone: stays in compact role family to fit available width
///   - Short screen / tight height (< 550px): scales down to prevent vertical crowding
extension ResponsiveTypographyExtension on BuildContext {
  /// Responsive welcome/subheading greeting style ("Welcome to") considering layout constraints and orientation.
  ///
  /// Takes [BoxConstraints] from [LayoutBuilder] to differentiate between:
  /// - Tablet Portrait (wide >= 600, tall >= 750, and vertical): [headlineSmall] (24sp)
  /// - Tablet Landscape pane or phone: [titleLarge] (22sp)
  /// - Ultra-short height (<= 550) or narrow phone (<= 360): [titleMedium] (16sp)
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

  /// Responsive app title/headline style ("AI Voice Genie") considering layout constraints and orientation.
  ///
  /// - Tablet Portrait (wide >= 600, tall >= 750, and vertical): [displaySmall] (36sp)
  /// - Tablet Landscape pane or phone: [headlineLarge] (32sp)
  /// - Ultra-short height (< 550) or narrow phone (<= 360): [headlineMedium] (28sp)
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

  /// Responsive button label considering layout constraints and orientation.
  ///
  /// - Standard phones & tablets: [titleMedium] (16sp, bold/w600) for strong CTA prominence
  /// - Ultra-short screens (< 550px) or narrow phones (<= 360px): [labelLarge] (14sp, bold/w600) to conserve height
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

  /// Responsive legal / disclaimer note considering layout constraints and orientation.
  ///
  /// - Tablet Portrait: [bodyMedium] (14sp)
  /// - Tablet Landscape pane or phone: [bodySmall] (12sp)
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

  /// Responsive body/description text style considering layout constraints and orientation.
  ///
  /// Takes [BoxConstraints] from [LayoutBuilder] to differentiate between:
  /// - Tablet Portrait (wide >= 600, tall >= 750, and vertical): [bodyLarge] (16sp)
  /// - Tablet Landscape pane or normal phone: [bodyMedium] (14sp)
  /// - Ultra-short height (< 550) or narrow phone (<= 360): [bodySmall] (12sp)
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
