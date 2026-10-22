import 'package:flutter/material.dart';

/// Centralized typography system for AI Voice Genie.
///
/// Uses Poppins exclusively across all text styles.
/// Both light and dark themes are defined here.
/// Usage: Theme.of(context).textTheme.bodyLarge
///
/// Material 3 Type Scale reference:
///   displayLarge (57sp), displayMedium (45sp), displaySmall (36sp)
///   headlineLarge (32sp), headlineMedium (28sp), headlineSmall (24sp)
///   titleLarge (22sp), titleMedium (16sp), titleSmall (14sp)
///   bodyLarge (16sp), bodyMedium (14sp), bodySmall (12sp)
///   labelLarge (14sp), labelMedium (12sp), labelSmall (11sp)
class AppTextStyles {
  // Single font family — enforced project-wide
  static const String fontFamily = 'Poppins';

  // ── Light Theme Text Styles ───────────────────────────────────────────────
  static const TextTheme lightTextTheme = TextTheme(
    // Display — app name, onboarding hero text, splash screen
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),

    // Headline — screen titles, section headers, AppBar titles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),

    // Title — card titles, list item headers, button text
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),

    // Body — chat messages, descriptions, general content
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),

    // Label — chips, badges, timestamps, metadata, model indicators
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
  );

  // ── Dark Theme Text Styles ────────────────────────────────────────────────
  static const TextTheme darkTextTheme = TextTheme(
    // Display
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
    ),

    // Headline
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),

    // Title
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
    ),

    // Body
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
    ),

    // Label
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    ),
  );
}
