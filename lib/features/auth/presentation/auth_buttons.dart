import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';

class AuthButtons extends StatelessWidget {
  final bool isTablet;
  final VoidCallback onTap;
  final String label;
  final SocialAuthProvider authType;

  const AuthButtons(
      {super.key,
      required this.isTablet,
      required this.onTap,
      required this.label,
      required this.authType});

  @override
  Widget build(BuildContext context) {
    return (authType.name == SocialAuthProvider.google.name)
        ? context.themedElevatedButton(
            label: label,
            onPressed: () => onTap,
            background: AppColors.white,
            foreground: AppColors.black,
            imgIcon: AppAssets.googleLogo)
        : context.themedElevatedButton(
            label: label,
            onPressed: () => onTap,
            background: AppColors.black,
            foreground: AppColors.white,
            imgIcon: AppAssets.appleLogo,
            imgColor: AppColors.white);
  }
}
