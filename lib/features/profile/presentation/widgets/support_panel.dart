import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../domain/profile_view_model.dart';
import 'profile_common_widgets.dart';

class ProfileSupportPanel extends StatelessWidget {
  const ProfileSupportPanel({super.key});

  void _openHelpSupport(BuildContext context) async {
    final viewModel = context.read<ProfileViewModel>();
    final result = await viewModel.openSupport(context.l10n.appName);
    if (!context.mounted) return;
    if (result == ProfileLinkResult.missing) {
      context.showWarning(context.l10n.linkUnavailable);
    } else if (result == ProfileLinkResult.failed) {
      context.showError(context.l10n.couldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        children: [
          ProfileListTile(
            icon: Icons.help_outline_rounded,
            title: context.l10n.helpCenter,
            showChevron: true,
            onTap: () => _openHelpSupport(context),
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
