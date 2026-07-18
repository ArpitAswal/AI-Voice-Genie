import 'package:flutter/material.dart';

/// Centralized color system for AI Voice Genie.
///
/// All colors are defined as named constants here.
/// No color should ever be hardcoded anywhere else in the codebase.
/// Supports full light/dark mode theming.
class AppColors {
  // ── Brand Colors ──────────────────────────────────────────────────────────

  // Primary brand color
  static const Color primaryLight = Color(0xFF7C9CFF);
  static const Color primaryDark = Color(0xFF5571D1);

  // Accent Glow
  static const Color accentLight = Color(0xFFC1D4FB);
  static const Color accentDark = Color(0xFF0B1220);

  // ── Background Colors ─────────────────────────────────────────────────────
  static const Color scaffoldLight = Color(0xFFE5E5E5);
  static const Color cardLight = Color(0xFFF7F8FA);

  static const Color scaffoldDark = Color(0xFF0B1220);
  static const Color cardDark = Color(0xFF091328);

  // ── AppBar Colors ─────────────────────────────────────────────────────
  static const Color appBarLight = Color(0xFFE5E5E5);
  static const Color appBarTextLight = Color(0xFF0F172A);

  static const Color appBarDark = Color(0xFF0B1220);
  static const Color appBarTextDark = Color(0xFFFFFFFF);

  // ── Text Colors ───────────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF040404);
  static const Color lightTextSecondary = Color(0xFFFFFFFF);
  static const Color lightTextTertiary = Color(0xFF40485D);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF000000);
  static const Color darkTextTertiary = Color(0xFFDEE5FF);

  // ── Border Colors ─────────────────────────────────────────────────────────
  static const Color lightDivider = Color(0xFFD1D1D1);
  static const Color darkDivider = Color(0xFF2B364C);

  // ── Common Colors ─────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9CA3AF);
  static const Color purpleAccent = Color(0xFFC3B4FC);
  static const Color tealAccent = Color(0xFF6EE7F9);
  static const Color cyanAccent = Color(0xFF18FFFF);
  static const Color accentGlow = Color.fromRGBO(29, 233, 182, 0);
  static const Color transparent = Colors.transparent;

  // ── Status / Feedback Colors ──────────────────────────────────────────────
  static const Color lightSuccess = Color(0xFF10B981);
  static const Color darkSuccess = Color(0xFF059669);
  static const Color lightError = Color(0xFFEF4444);
  static const Color darkError = Color(0xFFDC2626);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color darkWarning = Color(0xFFD97706);
  static const Color info = Color(0xFF3B82F6);

  // ── AI Model Brand Colors ─────────────────────────────────────────────────
  // Used for model indicator chips, key status badges, and model selector UI.

  // OpenAI / ChatGPT brand color (their official green)
  static const Color openAiBrand = Color(0xFF10A37F);
  static const Color openAiBrandDark = Color(0xFF0D8A6B);

  // Google Gemini brand color (their multi-color blue is the dominant hue)
  static const Color geminiBrand = Color(0xFF1A73E8);
  static const Color geminiBrandDark = Color(0xFF1557B0);

  // Anthropic Claude brand color (their signature amber/warm orange)
  static const Color claudeBrand = Color(0xFFD97706);
  static const Color claudeBrandDark = Color(0xFFB45309);

  // ── Chat Bubble Colors ────────────────────────────────────────────────────
  static const Color messageBubbleLight = Color(0xFFDEE5FF);
  static const Color messageBubbleDark = Color(0xFF2D3D70);
  static const Color messageBubbleTextLight = Color(0xFFFFFFFF);
  static const Color messageBubbleTextDark = Color(0xFFFFFFFF);
  static const Color pdfBackgroundLight = Color(0xFF6F8FF1);
  static const Color pdfBackgroundDark = Color(0xFF0F172A);

  // ── Voice Input Colors ────────────────────────────────────────────────────
  // Microphone button active state (pulsing red — recording)
  static const Color voiceActive = Color(0xFFEF4444);
  static const Color voiceActiveLight = Color(0xFFFEE2E2);
  // Microphone button idle state
  static const Color voiceIdle = primaryLight;
  static const Color voiceIdleDark = primaryDark;

  // ── Capability Indicator Colors ───────────────────────────────────────────
  // Shown on feature capability chips (supported / not supported)
  static const Color capabilitySupported = Color(0xFF10B981);
  static const Color capabilityUnsupported = Color(0xFFEF4444);
  static const Color capabilityUnknown = Color(0xFF9CA3AF);

  // ── Gradient Definitions ──────────────────────────────────────────────────
  // Used for hero sections and loading shimmer effects
  static final LinearGradient primaryGradientLight = LinearGradient(
    colors: [cyanAccent.withValues(alpha: 0.3), transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static final LinearGradient primaryGradientDark = LinearGradient(
    colors: [tealAccent.withValues(alpha: 0.3), transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient openAIGradient = LinearGradient(
      colors: [openAiBrand, openAiBrandDark],
      begin: AlignmentGeometry.topLeft,
      end: AlignmentGeometry.bottomRight);

  static const LinearGradient geminiGradient = LinearGradient(
      colors: [geminiBrand, geminiBrandDark],
      begin: AlignmentGeometry.topLeft,
      end: AlignmentGeometry.bottomRight);

  static const LinearGradient claudeGradient = LinearGradient(
      colors: [claudeBrand, claudeBrandDark],
      begin: AlignmentGeometry.topLeft,
      end: AlignmentGeometry.bottomRight);

  static const LinearGradient lightVoiceGradient = LinearGradient(
    colors: [primaryLight, tealAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkVoiceGradient = LinearGradient(
    colors: [primaryDark, tealAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
