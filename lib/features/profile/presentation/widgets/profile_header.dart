import 'package:ai_voice_genie/core/extensions/string_extension.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/domain/user_model.dart';
import 'profile_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool isShortHeight;

  const ProfileHeader(
      {super.key, required this.user, required this.isShortHeight});

  @override
  Widget build(BuildContext context) {
    final displayName =
        (user.displayName.trim().isNotEmpty) ? user.displayName.trim() : '';
    final email = (user.email.trim().isNotEmpty) ? user.email.trim() : '';
    final create =
        (user.createdAt != null && user.createdAt!.toDateString.isNotEmpty)
            ? user.createdAt!.toDateString
            : '';
    final country = user.country != null ? user.country! : '';
    final state = user.state != null ? user.state! : '';

    return LayoutBuilder(builder: (context, constraints) {
      final imgSize = (context.isCompact
          ? isShortHeight
              ? 60.0
              : 90.0
          : (context.isExpanded)
              ? 120.0
              : 140.0);
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        textAlign: TextAlign.left,
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.titleSmall
                                    : context.textTheme.titleMedium)
                                : context.textTheme.titleLarge)
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colorScheme.onSurface),
                      ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                : context.textTheme.bodyLarge)
                            ?.copyWith(color: context.colorScheme.tertiary),
                      ),
                    if (create.isNotEmpty)
                      Text(
                        "${context.l10n.activeUser}, $create",
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                : context.textTheme.bodyLarge)
                            ?.copyWith(color: context.colorScheme.tertiary),
                      ),
                    if (country.isNotEmpty && state.isNotEmpty) ...[
                      Text(
                        "$country, $state",
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                : context.textTheme.bodyLarge)
                            ?.copyWith(color: context.colorScheme.tertiary),
                      ),
                    ] else if (country.isNotEmpty) ...[
                      Text(
                        country,
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                : context.textTheme.bodyLarge)
                            ?.copyWith(color: context.colorScheme.tertiary),
                      ),
                    ] else if (state.isNotEmpty) ...[
                      Text(
                        state,
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                : context.textTheme.bodyLarge)
                            ?.copyWith(color: context.colorScheme.tertiary),
                      ),
                    ],
                    if (user.isNewUser)
                      Text(
                        context.l10n.newUser,
                        style: (context.isCompact
                                ? (isShortHeight
                                    ? context.textTheme.labelSmall
                                    : context.textTheme.labelMedium)
                                : context.textTheme.labelLarge)
                            ?.copyWith(
                          color: context.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                  ]),
            ),
            const SizedBox(width: 16),
            ProfileAvatar(
              displayName: displayName,
              photoUrl: user.photoUrl,
              canUpdate: false,
              size: imgSize,
            ),
          ]);
    });
  }
}
