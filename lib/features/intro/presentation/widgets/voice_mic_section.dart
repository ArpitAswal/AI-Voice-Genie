import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Primary Voice Assistant interactive call-to-action button for compact viewports.
///
/// Features:
/// - Prominent multi-layer glowing circular design.
/// - Minimum 48x48dp accessible touch area with full semantic labels.
/// - Tactile ink ripple feedback on press.
class VoiceMicSection extends StatelessWidget {
  final VoidCallback onTap;

  const VoiceMicSection({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final voiceTooltip = l10n.tapToStartVoiceChat;
    final isTablet = context.isTablet;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: voiceTooltip,
            button: true,
            child: Tooltip(
              message: voiceTooltip,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  splashColor: AppColors.primaryLight.withValues(alpha: 0.25),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient outer pulsing aura
                      Container(
                        width: isTablet ? 124 : 110,
                        height: isTablet ? 124 : 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.isDark
                              ? AppColors.purpleAccent.withValues(alpha: 0.12)
                              : AppColors.tealAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      // Core active microphone sphere
                      Container(
                        width: isTablet ? 90 : 80,
                        height: isTablet ? 90 : 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: context.isDark
                              ? AppColors.darkVoiceGradient
                              : AppColors.lightVoiceGradient,
                          boxShadow: [
                            BoxShadow(
                              color: (context.isDark
                                      ? AppColors.primaryDark
                                      : AppColors.primaryLight)
                                  .withValues(alpha: 0.45),
                              blurRadius: 22,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: isTablet ? 42 : 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isTablet ? 14 : 10),
          Text(
            l10n.voiceAssistant.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: context.colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// Floating Action Button (FAB) variant of the Voice Assistant for tablet/desktop viewports.
///
/// Anchored at the bottom-right of the screen to free up central space for content cards.
class VoiceMicFab extends StatelessWidget {
  final VoidCallback onTap;

  const VoiceMicFab({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final primaryColor =
        context.isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Semantics(
      button: true,
      label: l10n.tapToStartVoiceChat,
      child: Tooltip(
        message: l10n.tapToStartVoiceChat,
        child: Container(
          decoration: BoxDecoration(
            gradient: context.isDark
                ? AppColors.darkVoiceGradient
                : AppColors.lightVoiceGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(32),
              splashColor: Colors.white.withValues(alpha: 0.25),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.voiceAssistant.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
