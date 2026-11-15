import 'package:flutter/material.dart';

/// Centralized typography system for AI Voice Genie.
///
/// Implements the official Material 3 Type Scale using the Poppins font family:
///   - Display: displayLarge (57sp, h: 1.12), displayMedium (45sp, h: 1.15), displaySmall (36sp, h: 1.22)
///   - Headline: headlineLarge (32sp, h: 1.25), headlineMedium (28sp, h: 1.28), headlineSmall (24sp, h: 1.33)
///   - Title: titleLarge (22sp, h: 1.27), titleMedium (16sp, h: 1.50), titleSmall (14sp, h: 1.43)
///   - Body: bodyLarge (16sp, h: 1.50), bodyMedium (14sp, h: 1.43), bodySmall (12sp, h: 1.33)
///   - Label: labelLarge (14sp, h: 1.43), labelMedium (12sp, h: 1.33), labelSmall (11sp, h: 1.45)
///
/// Both light and dark themes are calibrated here to eliminate vertical font clipping and misalignments.
class AppTextStyles {
  /// Enforced project-wide font family
  static const String fontFamily = 'Poppins';

  // ── Light Theme Text Styles ───────────────────────────────────────────────
  static const TextTheme lightTextTheme = TextTheme(
    // Display — large promotional titles, onboarding hero text, splash screen
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.12,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.15,
      letterSpacing: 0.0,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.22,
      letterSpacing: 0.0,
    ),

    // Headline — screen titles, section headers, prominent AppBar titles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.25,
      letterSpacing: 0.0,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.28,
      letterSpacing: 0.0,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.0,
    ),

    // Title — card titles, dialog titles, list item headers, buttons
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.27,
      letterSpacing: 0.0,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.50,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.1,
    ),

    // Body — chat messages, descriptions, body text, general content
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.50,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.4,
    ),

    // Label — chips, badges, button labels, form labels, captions, metadata
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.45,
      letterSpacing: 0.5,
    ),
  );

  // ── Dark Theme Text Styles ────────────────────────────────────────────────
  static const TextTheme darkTextTheme = TextTheme(
    // Display
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.12,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.15,
      letterSpacing: 0.0,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      fontFamily: fontFamily,
      height: 1.22,
      letterSpacing: 0.0,
    ),

    // Headline
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.25,
      letterSpacing: 0.0,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.28,
      letterSpacing: 0.0,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.0,
    ),

    // Title
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.27,
      letterSpacing: 0.0,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.50,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.1,
    ),

    // Body
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.50,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.4,
    ),

    // Label
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.43,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.33,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
      height: 1.45,
      letterSpacing: 0.5,
    ),
  );
}
