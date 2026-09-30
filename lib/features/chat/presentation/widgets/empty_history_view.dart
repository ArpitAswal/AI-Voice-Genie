import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/widget_utils.dart';

class EmptyHistoryView extends StatelessWidget {
  final bool isTablet;
  const EmptyHistoryView({super.key, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: context.screenWidth,
          height: context.screenWidth,
          child: Lottie.asset(
            AppAssets.emptyConversation,
            reverse: true,
            repeat: true,
            fit: BoxFit.cover,
            imageProviderFactory: (lottieImage) {
              return const AssetImage(AppAssets.appLogo);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          child: context.themedElevatedButton(
              onPressed: () => AppRoutes.navigateTo(context, AppRoutes.chat),
              label: l10n.newConversation,
              align: Alignment.center),
        ),
      ],
    );
  }
}
