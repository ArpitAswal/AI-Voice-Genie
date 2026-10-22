import 'package:flutter/material.dart';

/// BuildContext extensions for responsive layout detection.
///
/// Usage: context.isTablet, context.screenWidth
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Tablet: width >= 600px
  bool get isTablet => screenWidth > 600;

  /// Small phone: width <= 360px
  bool get isSmallPhone => screenWidth <= 360;

  /// Returns responsive value based on device type
  T responsive<T>({required T mobile, T? tablet}) {
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Responsive horizontal padding
  double get horizontalPadding => isTablet ? 32.0 : 20.0;

  /// Responsive vertical spacing
  double get verticalSpacing => isTablet ? 24.0 : 16.0;
}

/// BuildContext extensions for theme and color access.
///
/// Usage: context.primaryColor, context.isDark
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get errorColor => Theme.of(this).colorScheme.error;
}

/// BuildContext extensions for MediaQuery shortcuts.
///
/// Usage: context.topPadding, context.bottomPadding
extension MediaQueryExtension on BuildContext {
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;
  double get topPadding => MediaQuery.of(this).padding.top;
  double get bottomPadding => MediaQuery.of(this).padding.bottom;
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;
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
  /// - Ultra-short height (< 550): [titleMedium] (16sp)
  TextStyle? greetingSubheaderStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight < 550) {
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
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.headlineSmall;
    }
    return textTheme.titleLarge;
  }

  /// Responsive app title/headline style ("AI Voice Genie") considering layout constraints and orientation.
  ///
  /// - Tablet Portrait (wide >= 600, tall >= 750, and vertical): [displaySmall] (36sp)
  /// - Tablet Landscape pane or phone: [headlineLarge] (32sp)
  /// - Ultra-short height (< 550): [headlineMedium] (28sp)
  TextStyle? greetingHeaderStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight < 550) {
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
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.displaySmall;
    }
    return textTheme.headlineLarge;
  }

  /// Responsive button label considering layout constraints and orientation.
  ///
  /// - Standard phones & tablets: [titleMedium] (16sp, bold/w600) for strong CTA prominence
  /// - Ultra-short screens (< 550px): [labelLarge] (14sp, bold/w600) to conserve height
  TextStyle? buttonLabelStyle([BoxConstraints? constraints]) {
    if (constraints != null && constraints.maxHeight < 550) {
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
        return textTheme.bodyMedium;
      }
      return textTheme.bodySmall;
    }
    // Fallback if called without LayoutBuilder constraints:
    if (size.width >= 600 && !isLandscape) {
      return textTheme.bodyMedium;
    }
    return textTheme.bodySmall;
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

  /// Responsive onboarding title style considering layout constraints.
  ///
  /// - Tablet Portrait (wide >= 600 & tall >= 750): [headlineLarge] (32sp, bold)
  /// - Tablet Landscape pane or phone: [headlineMedium] (28sp, bold)
  /// - Short screen / tight height (< 550px): [headlineSmall] (24sp, bold)
  TextStyle? onboardingTitleStyle([BoxConstraints? constraints]) {
    final base = textTheme.headlineMedium;
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight < 550) {
        return (textTheme.headlineSmall ?? base)?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        );
      }
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return (textTheme.headlineLarge ?? base)?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        );
      }
      return base?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );
    }
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return (textTheme.headlineLarge ?? base)?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );
    }
    if (size.height < 550) {
      return (textTheme.headlineSmall ?? base)?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );
    }
    return base?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );
  }

  /// Responsive onboarding description style considering layout constraints.
  ///
  /// - Tablet Portrait (wide >= 600 & tall >= 750): [bodyLarge] (16sp)
  /// - Normal phone / tablet pane: [bodyMedium] (14sp)
  /// - Short screen / tight height (< 550px): [bodySmall] (12sp)
  TextStyle? onboardingDescStyle([BoxConstraints? constraints]) {
    final size = MediaQuery.sizeOf(this);
    final isLandscape = size.width > size.height;

    if (constraints != null) {
      if (constraints.maxHeight < 550) {
        return textTheme.bodySmall;
      }
      if (!isLandscape &&
          constraints.maxWidth >= 600 &&
          constraints.maxHeight >= 750) {
        return textTheme.bodyLarge;
      }
      return textTheme.bodyMedium;
    }
    if (size.height < 550) {
      return textTheme.bodySmall;
    }
    if (size.width >= 600 && !isLandscape && size.height >= 750) {
      return textTheme.bodyLarge;
    }
    return textTheme.bodyMedium;
  }

  /// Responsive onboarding skip button style considering layout constraints.
  TextStyle? onboardingSkipStyle([BoxConstraints? constraints]) {
    if (constraints != null && constraints.maxHeight < 550) {
      return textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    }
    return textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
  }

  /// Responsive onboarding action button label style.
  TextStyle? onboardingButtonStyle([BoxConstraints? constraints]) =>
      buttonLabelStyle(constraints);

  // ── Backward-compatible helper methods ─────────────────────────────────────

  /// Helper with explicit constraints and side-by-side flag for backwards compatibility.
  TextStyle? greetingSubheaderStyleForConstraints(
    BoxConstraints constraints, {
    bool isSideBySide = false,
  }) {
    final effectiveConstraints = isSideBySide
        ? BoxConstraints(
            maxWidth: constraints.maxWidth / 2,
            maxHeight: constraints.maxHeight,
          )
        : constraints;
    return greetingSubheaderStyle(effectiveConstraints);
  }

  /// Helper with explicit constraints and side-by-side flag for backwards compatibility.
  TextStyle? greetingHeaderStyleForConstraints(
    BoxConstraints constraints, {
    bool isSideBySide = false,
  }) {
    final effectiveConstraints = isSideBySide
        ? BoxConstraints(
            maxWidth: constraints.maxWidth / 2,
            maxHeight: constraints.maxHeight,
          )
        : constraints;
    return greetingHeaderStyle(effectiveConstraints);
  }

  /// Helper with explicit constraints and side-by-side flag for backwards compatibility.
  TextStyle? buttonLabelStyleForConstraints(
    BoxConstraints constraints, {
    bool isSideBySide = false,
  }) {
    final effectiveConstraints = isSideBySide
        ? BoxConstraints(
            maxWidth: constraints.maxWidth / 2,
            maxHeight: constraints.maxHeight,
          )
        : constraints;
    return buttonLabelStyle(effectiveConstraints);
  }

  /// Helper with explicit constraints and side-by-side flag for backwards compatibility.
  TextStyle? legalTextStyleForConstraints(
    BoxConstraints constraints, {
    bool isSideBySide = false,
  }) {
    final effectiveConstraints = isSideBySide
        ? BoxConstraints(
            maxWidth: constraints.maxWidth / 2,
            maxHeight: constraints.maxHeight,
          )
        : constraints;
    return legalTextStyle(effectiveConstraints);
  }

  /// Helper with explicit constraints and side-by-side flag for backwards compatibility.
  TextStyle? legalLinkStyleForConstraints(
    BoxConstraints constraints, {
    bool isSideBySide = false,
  }) {
    final effectiveConstraints = isSideBySide
        ? BoxConstraints(
            maxWidth: constraints.maxWidth / 2,
            maxHeight: constraints.maxHeight,
          )
        : constraints;
    return legalLinkStyle(effectiveConstraints);
  }
}

/// BoxConstraints extensions for convenient responsive typography access directly from constraints.
///
/// Usage inside [LayoutBuilder]:
/// ```dart
/// LayoutBuilder(builder: (context, constraints) {
///   final style = constraints.greetingSubheaderStyle(context);
///   return Text('Welcome', style: style);
/// });
/// ```
extension ResponsiveConstraintsTypography on BoxConstraints {
  /// Responsive greeting subheader style ("Welcome to") for these constraints.
  TextStyle? greetingSubheaderStyle(BuildContext context) =>
      context.greetingSubheaderStyle(this);

  /// Responsive app title/headline style ("AI Voice Genie") for these constraints.
  TextStyle? greetingHeaderStyle(BuildContext context) =>
      context.greetingHeaderStyle(this);

  /// Responsive button label style for these constraints.
  TextStyle? buttonLabelStyle(BuildContext context) =>
      context.buttonLabelStyle(this);

  /// Responsive legal disclaimer style for these constraints.
  TextStyle? legalTextStyle(BuildContext context) =>
      context.legalTextStyle(this);

  /// Responsive legal link style for these constraints.
  TextStyle? legalLinkStyle(BuildContext context) =>
      context.legalLinkStyle(this);

  /// Responsive onboarding title style for these constraints.
  TextStyle? onboardingTitleStyle(BuildContext context) =>
      context.onboardingTitleStyle(this);

  /// Responsive onboarding description style for these constraints.
  TextStyle? onboardingDescStyle(BuildContext context) =>
      context.onboardingDescStyle(this);

  /// Responsive onboarding skip button style for these constraints.
  TextStyle? onboardingSkipStyle(BuildContext context) =>
      context.onboardingSkipStyle(this);

  /// Responsive onboarding action button style for these constraints.
  TextStyle? onboardingButtonStyle(BuildContext context) =>
      context.onboardingButtonStyle(this);
}
