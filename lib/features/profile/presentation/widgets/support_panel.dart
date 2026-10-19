import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../profile_view_model.dart';
import 'profile_common_widgets.dart';

class ProfileSupportPanel extends StatelessWidget {
  const ProfileSupportPanel({super.key});

  void _openHelpSupport(BuildContext context) async {
    final viewModel = context.read<ProfileViewModel>();
    final result = await viewModel.openSupport(
      '${context.l10n.appName} - ${context.l10n.helpCenter}',
    );
    if (!context.mounted) return;
    if (result == ProfileLinkResult.copied) {
      context.showSuccessToast(
          '${context.l10n.copiedToClipboard}: ${AppConstants.supportEmail}');
    } else if (result == ProfileLinkResult.missing) {
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
