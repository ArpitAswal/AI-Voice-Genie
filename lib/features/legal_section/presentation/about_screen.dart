import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../profile/domain/profile_view_model.dart';
import 'widgets/about_widgets.dart';
import '../../profile/presentation/widgets/profile_common_widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleLinkResult(Future<ProfileLinkResult> action) async {
    final result = await action;
    if (!mounted) return;

    switch (result) {
      case ProfileLinkResult.opened:
        return;
      case ProfileLinkResult.missing:
        context.showWarning(context.l10n.translate('link_unavailable'));
      case ProfileLinkResult.failed:
        context.showError(context.l10n.translate('could_not_open_link'));
    }
  }

  void _openLicenses(String versionLabel) {
    showLicensePage(
      context: context,
      // applicationName: context.l10n.appName,
      applicationVersion: versionLabel,
      applicationIcon: const AboutHero(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.aboutApp)),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                  vertical: context.verticalSpacing,
                ),
                children: [
                  const AboutHero(),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      AboutStatusChip(
                        label:
                            '${context.l10n.appVersion}: ${viewModel.versionLabel}',
                        icon: Icons.tag_rounded,
                      ),
                      AboutStatusChip(
                        label: context.l10n.developmentBuild,
                        icon: Icons.construction_rounded,
                        color: context.isDark
                            ? AppColors.darkWarning
                            : AppColors.lightWarning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AboutInfoPanel(
                    title: context.l10n.translate('about_mission_title'),
                    body: context.l10n.translate('about_mission_body'),
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 18),
                  AboutSectionCard(
                    title: context.l10n.translate('legal'),
                    children: [
                      ProfileListTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: AppColors.grey,
                        title: context.l10n.privacyPolicy,
                        subtitle: context.l10n.translate('read_in_app'),
                        showChevron: true,
                        onTap: () => AppRoutes.navigateTo(
                          context, AppRoutes.privacy,
                          arguments: {
                            'title': context.l10n.privacyPolicy,
                            'mdFileName': 'legal/privacy_policy.md'
                          }
                        ),
                      ),
                      const AboutDivider(),
                      ProfileListTile(
                        icon: Icons.description_outlined,
                        iconColor: AppColors.grey,
                        title: context.l10n.termsOfService,
                        subtitle: context.l10n.translate('read_in_app'),
                        showChevron: true,
                        onTap: () => AppRoutes.navigateTo(context,
                            AppRoutes.terms,
                        arguments: {
                          'title': context.l10n.termsOfService,
                          'mdFileName': 'legal/terms_of_service.md',
                        })
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AboutSectionCard(
                    title: context.l10n.support,
                    children: [
                      ProfileListTile(
                        icon: Icons.support_agent_rounded,
                        iconColor: AppColors.grey,
                        title: context.l10n.translate('contact_support'),
                        subtitle: AppConstants.supportEmail.isNotEmpty
                            ? AppConstants.supportEmail
                            : context.l10n.translate('not_configured'),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: context.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                          size: context.textTheme.titleLarge?.fontSize,
                        ),
                        onTap: () => _handleLinkResult(
                          viewModel.openSupport(context.l10n.appName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AboutSectionCard(
                    title: context.l10n.translate('credits_attribution'),
                    children: [
                      ProfileListTile(
                        icon: Icons.inventory_2_outlined,
                        iconColor: AppColors.grey,
                        title: context.l10n.translate('open_source_licenses'),
                        subtitle: context.l10n.translate('view_licenses'),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: context.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                          size: context.textTheme.titleLarge?.fontSize,
                        ),
                        onTap: () => _openLicenses(viewModel.versionLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AboutFooter(versionLabel: viewModel.versionLabel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
