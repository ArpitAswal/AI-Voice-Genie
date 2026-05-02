import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/auth_provider.dart';

class EditableAvatarPreview extends StatelessWidget {

  const EditableAvatarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final displayName = user?.displayName ?? context.l10n.user;
    final photoUrl = user?.photoUrl ?? '';

    return ProfileAvatar(
      displayName: displayName,
      photoUrl: photoUrl,
      size: context.isTablet ? 140 : 116,
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String displayName;
  final String photoUrl;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.displayName,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            context.isDark ? AppColors.primaryLight : AppColors.primaryDark,
            AppColors.tealAccent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor:
            context.isDark ? AppColors.cardDark : AppColors.cardLight,
        child: ClipOval(
          child: photoUrl.trim().isEmpty
              ? _InitialsAvatar(displayName: displayName)
              : Image.network(
                  photoUrl.trim(),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _InitialsAvatar(displayName: displayName),
                ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String displayName;

  const _InitialsAvatar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: context.isDark
            ? AppColors.darkVoiceGradient
            : AppColors.lightVoiceGradient,
      ),
      child: Text(
        _initials(displayName),
        style: context.textTheme.displayMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
