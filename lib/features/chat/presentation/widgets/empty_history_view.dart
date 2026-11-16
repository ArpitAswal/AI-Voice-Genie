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
    final isShortHeight = context.screenHeight <= 550.0;

    // Clamped proportional Lottie dimension prevents giant blowout on tablets/desktops
    // and guards against vertical clipping on short or landscape displays.
    final lottieSize = isShortHeight
        ? 140.0
        : (isTablet ? 260.0 : (context.screenWidth * 0.65).clamp(160.0, 240.0));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: isShortHeight ? 8.0 : context.verticalSpacing,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: lottieSize,
                height: lottieSize,
                child: Lottie.asset(
                  AppAssets.emptyConversation,
                  reverse: true,
                  repeat: true,
                  fit: BoxFit.contain,
                  imageProviderFactory: (lottieImage) {
                    return const AssetImage(AppAssets.appLogo);
                  },
                ),
              ),
              context.themedElevatedButton(
                onPressed: () => AppRoutes.navigateTo(context, AppRoutes.chat),
                label: l10n.newConversation,
                align: Alignment.center,
                foreground: Colors.white,
                textStyle: (context.isCompact
                    ? context.textTheme.titleSmall
                    : context.textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
