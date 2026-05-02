import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class ProfileSectionTitle extends StatelessWidget {
  final String label;

  const ProfileSectionTitle({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: context.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
      ),
    );
  }
}

class ProfilePanel extends StatelessWidget {
  final Widget child;

  const ProfilePanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ProfileUiHelpers.panelColor(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: ProfileUiHelpers.softShadow(context),
      ),
      child: child,
    );
  }
}

class ProfileIconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const ProfileIconTile({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });

  static const double defaultSize = 36;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? defaultSize;

    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        color:  (color ?? context.primaryColor)
            .withValues(alpha: context.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: color ??
            (context.isDark ? AppColors.primaryLight : AppColors.primaryDark),
        size: resolvedSize * 0.7,
      ),
    );
  }
}

class ProfileProviderLogo extends StatelessWidget {
  final AiProviderId provider;
  final double size;

  const ProfileProviderLogo({
    super.key,
    required this.provider,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ProfileUiHelpers.providerGradient(provider),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          ProfileUiHelpers.providerIcon(provider),
          color: AppColors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

abstract final class ProfileUiHelpers {
  static Color providerColor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAiBrand;
      case AiProviderId.gemini:
        return AppColors.geminiBrand;
      case AiProviderId.claude:
        return AppColors.claudeBrand;
    }
  }

  static Gradient providerGradient(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAIGradient;
      case AiProviderId.gemini:
        return AppColors.geminiGradient;
      case AiProviderId.claude:
        return AppColors.claudeGradient;
    }
  }

  static FaIconData providerIcon(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return FontAwesomeIcons.openai;
      case AiProviderId.gemini:
        return FontAwesomeIcons.gemini;
      case AiProviderId.claude:
        return FontAwesomeIcons.claude;
    }
  }

  static double providerUsage(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return 0.72;
      case AiProviderId.gemini:
        return 0.64;
      case AiProviderId.claude:
        return 0.81;
    }
  }

  static Color panelColor(BuildContext context) =>
      context.isDark ? AppColors.cardDark : AppColors.cardLight;

  static Color mutedTextColor(BuildContext context) => context.isDark
      ? AppColors.darkTextPrimary.withValues(alpha: 0.66)
      : AppColors.lightTextPrimary.withValues(alpha: 0.58);

  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color:
              AppColors.black.withValues(alpha: context.isDark ? 0.12 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ];
}
