import 'package:ai_voice_genie/core/extensions/string_extension.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final email =
        (user?.email.trim().isNotEmpty ?? false) ? user!.email.trim() : '';
    final dob = user?.dateOfBirth;
    final create =
        (user?.createdAt != null && user!.createdAt!.toDateString.isNotEmpty) ? user!.createdAt?.toDateString : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  textAlign: TextAlign.left,
                  style: context.textTheme.bodyLarge),
              if (email.isNotEmpty)
                Text(email, style: context.textTheme.bodyLarge),
              if (dob != null)
                Text(dob.toString(), style: context.textTheme.bodyLarge),
              if (create != null)
                Text("${context.l10n.translate('active_user')}, $create",
                    style: context.textTheme.bodyLarge),
            ],
          ),
        ),
        ProfileAvatar(
            displayName: displayName,
            photoUrl: user?.photoUrl ?? '',
            size: context.screenWidth * (context.isTablet ? 0.35 : 0.2),
            canUpdate: false),
      ],
    );
  }
}
