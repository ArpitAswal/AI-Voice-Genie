import 'package:flutter/material.dart';

/// BuildContext extensions for responsive layout detection.
///
/// Usage: context.isTablet, context.screenWidth
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Tablet: width >= 600px
  bool get isTablet => screenWidth >= 600;

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