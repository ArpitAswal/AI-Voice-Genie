import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import 'profile_common_widgets.dart';

class AboutHero extends StatelessWidget {
  const AboutHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // gradient: LinearGradient(
        //   colors: [
        //     ProfileUiHelpers.panelColor(context),
        //     context.primaryColor.withValues(alpha: context.isDark ? 0.18 : 0.1),
        //   ],
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        // ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: ProfileUiHelpers.softShadow(context),
      ),
      child: const AboutLogo(),
    );
  }
}

class AboutLogo extends StatelessWidget {
  const AboutLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle, gradient: AppColors.primaryGradientDark),
          child: ImageView(
            image: const ImageViewData.asset(AppAssets.appLogo),
            width: context.screenWidth / 4,
            height: context.screenWidth / 4,
            filterQuality: FilterQuality.high,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Text(context.l10n.appName,
            textAlign: TextAlign.center, style: context.textTheme.titleLarge),
        Text(context.l10n.appTagline,
            textAlign: TextAlign.center, style: context.textTheme.bodySmall),
      ],
    );
  }
}

class AboutStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const AboutStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: context.isDark ? 0.12 : 0.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: context.isDark ? resolvedColor : Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.isDark ? resolvedColor : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AboutInfoPanel extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? accentColor;

  const AboutInfoPanel({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? context.primaryColor;

    return ProfilePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileIconTile(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: context.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AboutSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: context.textTheme.headlineSmall?.copyWith(
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}


class AboutDivider extends StatelessWidget {
  const AboutDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 18,
      color: context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
    );
  }
}

class AboutFooter extends StatelessWidget {
  final String versionLabel;

  const AboutFooter({super.key, required this.versionLabel});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Column(
      children: [
        Text(
            '${context.l10n.translate('about_developer')}: '
            '${context.l10n.translate('independent_developer')}',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
            '${context.l10n.translate('copyright')} © $year '
            '${AppConstants.copyrightOwner}',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall)
      ],
    );
  }
}
