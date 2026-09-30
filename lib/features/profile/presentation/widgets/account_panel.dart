import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';

import 'profile_common_widgets.dart';

class ProfileAccountPanel extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const ProfileAccountPanel({
    super.key,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        children: [
          ProfileListTile(
            icon: Icons.logout_rounded,
            title: context.l10n.signOut,
            titleColor:
                context.isDark ? AppColors.darkError : AppColors.lightError,
            iconColor:
                context.isDark ? AppColors.darkError : AppColors.lightError,
            showChevron: false,
            onTap: onLogout,
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.delete_forever_rounded,
            title: context.l10n.deleteAccount,
            titleColor:
                context.isDark ? AppColors.darkError : AppColors.lightError,
            iconColor:
                context.isDark ? AppColors.darkError : AppColors.lightError,
            showChevron: false,
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
