import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../profile/presentation/widgets/profile_common_widgets.dart';

class AboutHero extends StatelessWidget {
  final double? size;

  const AboutHero({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (context.isTablet ? 96.0 : 80.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: resolvedSize,
          height: resolvedSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradientDark,
          ),
          alignment: Alignment.center,
          child: ImageView(
            image: const ImageViewData.asset(AppAssets.appLogo),
            width: resolvedSize,
            height: resolvedSize,
            filterQuality: FilterQuality.high,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.appName,
          textAlign: TextAlign.center,
          style: (context.isCompact
                  ? context.textTheme.titleMedium
                  : context.textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.appTagline,
          textAlign: TextAlign.center,
          style: context.isCompact
              ? context.textTheme.bodyMedium
              : context.textTheme.bodyLarge,
        ),
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
    final resolvedColor = color ?? context.theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding / 2,
        vertical: context.verticalSpacing / 4,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resolvedColor.withValues(alpha: context.isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: resolvedColor, size: context.isTablet ? 16 : 12),
          const SizedBox(width: 12),
          Text(
            label,
            style: (context.isCompact
                    ? context.textTheme.labelMedium
                    : context.textTheme.labelLarge)
                ?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w600,
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

  const AboutInfoPanel({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = context.screenWidth <= 360.0;
    return ProfilePanel(
      child: !isSmallScreen
          ? Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileIconTile(
                  icon: icon,
                  size: context.isTablet ? 40 : 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (context.isCompact
                              ? context.textTheme.titleSmall
                              : context.textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: (context.isCompact
                              ? context.textTheme.labelSmall
                              : context.textTheme.labelMedium)
                          ?.copyWith(
                              height: 1.5, color: context.colorScheme.tertiary),
                    ),
                  ],
                ))
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.max, children: [
                  ProfileIconTile(
                    icon: icon,
                    size: context.isTablet ? 40 : 36,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: (context.isCompact
                            ? context.textTheme.titleLarge
                            : context.textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: (context.isCompact
                          ? context.textTheme.bodySmall
                          : context.textTheme.bodyMedium)
                      ?.copyWith(
                          height: 1.5, color: context.colorScheme.tertiary),
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
            style: (context.isTablet
                    ? context.textTheme.titleSmall?.copyWith(fontSize: 15)
                    : context.textTheme.bodyLarge)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
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
    final textStyle = context.isTablet
        ? context.textTheme.bodyMedium
        : context.textTheme.bodySmall;

    return Column(
      children: [
        Text(
          '${context.l10n.aboutDeveloper}: ${context.l10n.independentDeveloper}',
          textAlign: TextAlign.center,
          style: textStyle,
        ),
        const SizedBox(height: 6),
        Text(
          '${context.l10n.copyright} © $year ${AppConstants.copyrightOwner}',
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ],
    );
  }
}
