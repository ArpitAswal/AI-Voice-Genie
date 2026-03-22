import 'package:flutter/material.dart';

/// Centralized color system for AI Voice Genie.
///
/// All colors are defined as named constants here.
/// No color should ever be hardcoded anywhere else in the codebase.
/// Supports full light/dark mode theming.
class AppColors {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  // Primary brand color for AI Voice Genie (deep violet-blue — intelligent, premium)
  static const Color primaryLight = Color(0xFF5C6BC0);
  static const Color primaryDark = Color(0xFF7986CB);
  static const Color primaryLightColor = Color(0xFF5C6BC0);
  static const Color primaryDarkColor = Color(0xFF7986CB);

  // Accent colors (electric teal — voice/AI pulse energy)
  static const Color accentLight = Color(0xFF00BCD4);
  static const Color accentDark = Color(0xFF4DD0E1);
  static const Color accentLightColor = Color(0xFF00BCD4);
  static const Color accentDarkColor = Color(0xFF4DD0E1);

  // ── Background Colors ─────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color darkBackground = Color(0xFF0F0F14);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1A1A24);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color darkCardBackground = Color(0xFF1E1E2E);

  // ── Text Colors ───────────────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // ── Button Text Colors ────────────────────────────────────────────────────
  static const Color lightTextBtnColor = primaryLight;
  static const Color darkTextBtnColor = primaryDark;

  // ── Border Colors ─────────────────────────────────────────────────────────
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color darkBorder = Color(0xFF2D2D3F);

  // ── Common Colors ─────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9CA3AF);
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color greyDark = Color(0xFF374151);
  static const Color transparent = Colors.transparent;

  // ── Status / Feedback Colors ──────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── AI Model Brand Colors ─────────────────────────────────────────────────
  // Used for model indicator chips, key status badges, and model selector UI.

  // OpenAI / ChatGPT brand color (their official green)
  static const Color openAiBrand = Color(0xFF10A37F);
  static const Color openAiBrandLight = Color(0xFFE6F7F4);
  static const Color openAiBrandDark = Color(0xFF0D8A6B);

  // Google Gemini brand color (their multi-color blue is the dominant hue)
  static const Color geminiBrand = Color(0xFF1A73E8);
  static const Color geminiBrandLight = Color(0xFFE8F0FE);
  static const Color geminiBrandDark = Color(0xFF1557B0);

  // Anthropic Claude brand color (their signature amber/warm orange)
  static const Color claudeBrand = Color(0xFFD97706);
  static const Color claudeBrandLight = Color(0xFFFEF3C7);
  static const Color claudeBrandDark = Color(0xFFB45309);

  // ── Chat Bubble Colors ────────────────────────────────────────────────────
  // User message bubble
  static const Color userBubbleLight = Color(0xFF5C6BC0);
  static const Color userBubbleDark = Color(0xFF7986CB);
  static const Color userBubbleTextLight = Color(0xFFFFFFFF);
  static const Color userBubbleTextDark = Color(0xFFFFFFFF);

  // AI message bubble
  static const Color aiBubbleLight = Color(0xFFFFFFFF);
  static const Color aiBubbleDark = Color(0xFF1E1E2E);
  static const Color aiBubbleTextLight = Color(0xFF1A1A2E);
  static const Color aiBubbleTextDark = Color(0xFFF0F0F5);

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
  static const LinearGradient primaryGradientLight = LinearGradient(
    colors: [Color(0xFF5C6BC0), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF7986CB), Color(0xFF4DD0E1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Voice pulse gradient (used on recording animation)
  static const RadialGradient voicePulseGradient = RadialGradient(
    colors: [Color(0x44EF4444), Color(0x00EF4444)],
    radius: 1.0,
  );
}