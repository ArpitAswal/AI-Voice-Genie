import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography system for AI Voice Genie.
///
/// Uses Poppins exclusively across all text styles.
/// Both light and dark themes are defined here.
/// Usage: Theme.of(context).textTheme.bodyLarge
///
/// Scale reference:
///   display   → App name, splash hero text
///   headline  → Screen titles, section headers
///   title     → Card titles, button labels
///   body      → General content, chat messages
///   label     → Chips, badges, metadata, timestamps
class AppTextStyles {
  // Single font family — enforced project-wide
  static const String fontFamily = 'Poppins';

  // ── Light Theme Text Styles ───────────────────────────────────────────────
  static const TextTheme lightTextTheme = TextTheme(
    // Display — app name, onboarding hero text, splash screen
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryLight,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryLight,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryLight,
      fontFamily: fontFamily,
    ),

    // Headline — screen titles, section headers, AppBar titles
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextTertiary,
      fontFamily: fontFamily,
    ),

    // Title — card titles, list item headers, button text
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryLight,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
    ),

    // Body — chat messages, descriptions, general content
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
      height: 1.4,
    ),

    // Label — chips, badges, timestamps, metadata, model indicators
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextSecondary,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextPrimary,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextSecondary,
      fontFamily: fontFamily,
      letterSpacing: 0.4,
    ),
  );

  // ── Dark Theme Text Styles ────────────────────────────────────────────────
  static const TextTheme darkTextTheme = TextTheme(
    // Display
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryDark,
      fontFamily: fontFamily,
    ),
    displayMedium: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryDark,
      fontFamily: fontFamily,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryDark,
      fontFamily: fontFamily,
    ),

    // Headline
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextTertiary,
      fontFamily: fontFamily,
    ),

    // Title
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryDark,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
    ),

    // Body
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
      height: 1.4,
    ),

    // Label
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextSecondary,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextPrimary,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextSecondary,
      fontFamily: fontFamily,
      letterSpacing: 0.4,
    ),
  );
}