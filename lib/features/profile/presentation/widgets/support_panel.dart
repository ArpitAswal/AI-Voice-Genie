import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import 'profile_common_widgets.dart';

class ProfileSupportPanel extends StatelessWidget {
  const ProfileSupportPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        children: [
          ProfileListTile(
            icon: Icons.help_outline_rounded,
            title: context.l10n.helpCenter,
            showChevron: true,
            onTap: () => context.showWarning('coming_soon'),
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.info_outline_rounded,
            title: context.l10n.about,
            showChevron: true,
            onTap: () => AppRoutes.navigateTo(context, AppRoutes.about),
          ),
        ],
      ),
    );
  }
}
