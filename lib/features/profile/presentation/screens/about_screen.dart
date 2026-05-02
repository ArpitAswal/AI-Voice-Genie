import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../domain/profile_view_model.dart';
import '../widgets/about_widgets.dart';

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
    _viewModel = ProfileViewModel()..loadPackageInfo();
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
        context.showWarning(context.l10n.linkUnavailable);
      case ProfileLinkResult.failed:
        context.showError(context.l10n.couldNotOpenLink);
    }
  }

  void _openLicenses(String versionLabel) {
    // showLicensePage(
    //   context: context,
    //   applicationName: context.l10n.appName,
    //   applicationVersion: versionLabel,
    //   applicationIcon: const AboutLogo(),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ProfileViewModel>(
        builder: (context, viewModel, _) {
          final hasPrivacy = AppConstants.privacyPolicyUrl.trim().isNotEmpty;
          final hasTerms = AppConstants.termsOfServiceUrl.trim().isNotEmpty;
          final hasSupport = AppConstants.supportEmail.trim().isNotEmpty ||
              AppConstants.helpCenterUrl.trim().isNotEmpty;

          return Scaffold(
            appBar:
                AppBar(title: Text(context.l10n.aboutApp), centerTitle: false),
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
                    spacing: 10,
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
                        color: AppColors.warning,
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
                      AboutLinkRow(
                        icon: Icons.privacy_tip_outlined,
                        title: context.l10n.privacyPolicy,
                        subtitle: context.l10n.translate('configured'),
                        isEnabled: hasPrivacy,
                        onTap: () => _handleLinkResult(
                          viewModel.openUrl(AppConstants.privacyPolicyUrl),
                        ),
                      ),
                      const AboutDivider(),
                      AboutLinkRow(
                        icon: Icons.description_outlined,
                        title: context.l10n.termsOfService,
                        subtitle: context.l10n.translate('configured'),
                        isEnabled: hasTerms,
                        onTap: () => _handleLinkResult(
                          viewModel.openUrl(AppConstants.termsOfServiceUrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AboutSectionCard(
                    title: context.l10n.support,
                    children: [
                      AboutLinkRow(
                        icon: Icons.support_agent_rounded,
                        title: context.l10n.translate('contact_support'),
                        subtitle: context.l10n.translate('configured'),
                        isEnabled: hasSupport,
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
                      AboutLinkRow(
                        icon: Icons.inventory_2_outlined,
                        title: context.l10n.translate('open_source_licenses'),
                        subtitle: context.l10n.translate('view_licenses'),
                        isEnabled: true,
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
