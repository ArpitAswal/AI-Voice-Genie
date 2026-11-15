import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

class ProfileSectionTitle extends StatelessWidget {
  final String label;
  final bool isShortHeight;

  const ProfileSectionTitle(
      {super.key, required this.label, this.isShortHeight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: (isShortHeight
              ? context.textTheme.titleMedium
              : context.textTheme.titleLarge)
          ?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 3.5,
      ),
    );
  }
}

class ProfilePanel extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ProfilePanel({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: ProfileUiHelpers.softShadow(context),
      ),
      child: child,
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }
    return content;
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

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (context.isTablet ? 36.0 : 30.0);

    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        color: (color ?? context.theme.colorScheme.primary)
            .withValues(alpha: context.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
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
    this.size = 42.0,
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
          size: size * 0.6,
        ),
      ),
    );
  }
}

abstract final class ProfileUiHelpers {
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

  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color:
              AppColors.black.withValues(alpha: context.isDark ? 0.12 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ];
}

class ProfileListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  const ProfileListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      children: [
        ProfileIconTile(icon: icon, color: iconColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: (context.isCompact
                        ? context.textTheme.titleSmall
                        : context.textTheme.titleMedium)
                    ?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: (context.isCompact
                          ? context.textTheme.bodySmall
                          : context.textTheme.bodyMedium)
                      ?.copyWith(
                    color: subtitleColor ??
                        (context.isDark
                            ? AppColors.darkWarning
                            : AppColors.lightWarning),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (showChevron)
          Icon(Icons.chevron_right_rounded,
              color: context.textTheme.bodySmall?.color),
      ],
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }
}
