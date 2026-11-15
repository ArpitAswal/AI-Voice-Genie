import 'package:flutter/material.dart' hide ThemeExtension;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Top greeting and quick chat launch header.
///
/// Ergonomics:
/// - Semantic typography scaling from [ThemeExtension].
/// - Enforces WCAG 2.1 AA 48×48dp minimum touch target across all screen sizes.
/// - Self-adapting visual size based on device real estate without prop drilling.
class IntroHeaderSection extends StatelessWidget {
  final String greeting;
  final VoidCallback onOpenChat;
  final bool isShortHeight;

  const IntroHeaderSection({
    super.key,
    required this.greeting,
    required this.onOpenChat,
    this.isShortHeight = false,
  });

  /// Calculates visual button diameter based on device real estate.
  /// (Interactive touch target is always clamped to >= 48dp).
  double _buttonDiameter(BuildContext context) {
    if (context.isTablet && context.isExpanded) {
      return 52.0; // Prominent on wide screens, but doesn't overpower typography
    }
    if (context.isCompact && isShortHeight) {
      return 40.0; // Compact visual circle for height-constrained devices
    }
    return 48.0; // Standard mobile & tablet-portrait default
  }

  @override
  Widget build(BuildContext context) {
    final visualDiameter = _buttonDiameter(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting & App Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (context.isCompact
                        ? context.textTheme.headlineMedium
                        : context.textTheme.headlineLarge)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.aiAssist,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (context.isCompact
                        ? context.textTheme.bodyMedium
                        : context.textTheme.bodyLarge)
                    ?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Direct Chat Icon Button (Guaranteed 48x48dp Touch Target)
        Semantics(
          button: true,
          label: context.l10n.askQuestion,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenChat,
              customBorder: const CircleBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 48.0,
                  minHeight: 48.0,
                ),
                child: Center(
                  child: Container(
                    width: visualDiameter,
                    height: visualDiameter,
                    decoration: BoxDecoration(
                      gradient: context.isDark
                          ? AppColors.darkVoiceGradient
                          : AppColors.lightVoiceGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.solidMessage,
                        color: Colors.white,
                        size: visualDiameter * 0.44,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
