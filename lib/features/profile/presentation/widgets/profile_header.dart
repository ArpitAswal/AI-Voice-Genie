import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/domain/user_model.dart';
import 'profile_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel? user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim()
        : context.l10n.user;

    return Column(
      children: [
        ProfileAvatar(
            displayName: displayName,
            photoUrl: user?.photoUrl ?? '',
            size: context.isTablet ? 150 : 118,
            canUpdate: false),
        const SizedBox(height: 18),
        Text(displayName,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineLarge),
        TextButton.icon(
          onPressed: () => AppRoutes.navigateTo(context, AppRoutes.profileEdit),
          style: TextButton.styleFrom(
              foregroundColor: context.textTheme.bodyLarge?.color),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.l10n.editProfile,
              style: context.textTheme.bodyLarge),
        ),
      ],
    );
  }
}
