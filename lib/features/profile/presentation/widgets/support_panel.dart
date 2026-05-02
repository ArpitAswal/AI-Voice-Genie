import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import 'profile_common_widgets.dart';

class ProfileSupportPanel extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileSupportPanel({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        children: [
          ProfileActionRow(
            icon: Icons.help_outline_rounded,
            title: context.l10n.helpCenter,
            onTap: () => context.showWarning('coming_soon'),
          ),
          const SizedBox(height: 18),
          ProfileActionRow(
            icon: Icons.info_outline_rounded,
            title: context.l10n.about,
            onTap: () => AppRoutes.navigateTo(context, AppRoutes.about),
          ),
          const SizedBox(height: 18),
          ProfileActionRow(
            icon: Icons.logout_rounded,
            title: context.l10n.signOut,
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          ProfileIconTile(icon: icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: ProfileUiHelpers.mutedTextColor(context),
          ),
        ],
      ),
    );
  }
}
