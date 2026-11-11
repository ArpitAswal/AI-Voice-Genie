import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../profile/presentation/profile_view_model.dart';
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
      case ProfileLinkResult.copied:
        context.showSuccessToast(
          '${context.l10n.copiedToClipboard}: ${AppConstants.supportEmail}',
        );
      case ProfileLinkResult.missing:
        context.showWarning(context.l10n.linkUnavailable);
      case ProfileLinkResult.failed:
        context.showError(context.l10n.couldNotOpenLink);
    }
  }

  void _openLicenses(String versionLabel) {
    showLicensePage(
      context: context,
      applicationName: context.l10n.appName,
      applicationVersion: versionLabel,
      applicationIcon: const Padding(
        padding: EdgeInsets.all(8.0),
        child: AboutHero(size: 64.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: _viewModel,
        child: Scaffold(
          appBar: AppBar(
              title: Text(context.l10n.aboutApp,
                  style: context.isCompact
                      ? context.textTheme.titleLarge
                      : context.textTheme.headlineSmall)),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                // ── Breakpoint Architecture ────────────────────────────────
                // 1. Phone landscape guard or height-constrained (height <= 550dp) or Compact (< 600dp):
                // Enforces single-column scrollable layout, avoiding vertical crushing.
                if (height <= 550.0 || width < 600.0) {
                  return _buildCompactLayout(
                    context,
                    isShortHeight: height <= 550.0,
                  );
                }

                // 2. Expanded Viewport (width >= 840dp && height > 550dp):
                // Dual-pane ergonomic desktop/tablet landscape composition.
                if (width >= 840.0) {
                  return _buildExpandedLayout(
                    context,
                  );
                }

                // 3. Medium Viewport (600dp <= width < 840dp && height > 550dp):
                // Centered tablet portrait layout with maxWidth constraints.
                return _buildMediumLayout(
                  context,
                );
              },
            ),
          ),
        ));
  }

  // ── 1. Compact Viewport (< 600dp or height <= 550dp) ─────────────────────────
  Widget _buildCompactLayout(
    BuildContext context, {
    required bool isShortHeight,
  }) {
    final double verticalPadding =
        isShortHeight ? 12.0 : context.verticalSpacing;
    final double itemSpacing = isShortHeight ? 12.0 : 18.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AboutHero(size: isShortHeight ? 64.0 : 80.0),
          SizedBox(height: itemSpacing),
          _buildStatusChips(context),
          SizedBox(height: itemSpacing),
          AboutInfoPanel(
            title: context.l10n.aboutMissionTitle,
            body: context.l10n.aboutMissionBody,
            icon: Icons.auto_awesome_rounded,
          ),
          SizedBox(height: itemSpacing),
          _buildLegalCard(context),
          SizedBox(height: itemSpacing),
          _buildSupportCard(context),
          SizedBox(height: itemSpacing),
          _buildLicensesCard(context),
          SizedBox(height: itemSpacing + 4.0),
          _buildFooter(context),
          SizedBox(height: context.viewInsets.bottom + 16.0),
        ],
      ),
    );
  }

  // ── 2. Medium Viewport (600dp <= width < 840dp && height > 550dp) ────────────
  Widget _buildMediumLayout(
    BuildContext context,
  ) {
    // Aligns content to the top-center to prevent large empty voids below the AppBar
    // on tall tablet portrait devices while enforcing a readable maxWidth constraint.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640.0),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AboutHero(size: 92.0),
              const SizedBox(height: 18.0),
              _buildStatusChips(context),
              const SizedBox(height: 20.0),
              AboutInfoPanel(
                title: context.l10n.aboutMissionTitle,
                body: context.l10n.aboutMissionBody,
                icon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(height: 20.0),
              _buildLegalCard(context),
              const SizedBox(height: 20.0),
              _buildSupportCard(context),
              const SizedBox(height: 20.0),
              _buildLicensesCard(context),
              const SizedBox(height: 24.0),
              _buildFooter(context),
              SizedBox(height: context.viewInsets.bottom + 16.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Expanded Viewport (width >= 840dp && height > 550dp) ──────────────────
  Widget _buildExpandedLayout(
    BuildContext context,
  ) {
    // Anchors dual-pane layout to top-center with max reading width of 1200dp
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200.0),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left Hero Pane: Identity, Status, Mission & Copyright ────────
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 320.0,
                  maxWidth: 360.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AboutHero(size: 96.0),
                    const SizedBox(height: 16.0),
                    _buildStatusChips(context),
                    const SizedBox(height: 20.0),
                    AboutInfoPanel(
                      title: context.l10n.aboutMissionTitle,
                      body: context.l10n.aboutMissionBody,
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(height: 24.0),
                    _buildFooter(context),
                  ],
                ),
              ),
              const SizedBox(width: 32.0),

              // ── Right Workspace Pane: Legal Docs, Support & Licenses ──────────
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegalCard(context),
                      const SizedBox(height: 20.0),
                      _buildSupportCard(context),
                      const SizedBox(height: 20.0),
                      _buildLicensesCard(context),
                      SizedBox(height: context.viewInsets.bottom + 16.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widget builders ───────────────────────────────────────────────────────

  Widget _buildStatusChips(
    BuildContext context,
  ) {
    final versionLabel = context.select<ProfileViewModel, String>(
      (vm) => vm.versionLabel,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        AboutStatusChip(
          label: '${context.l10n.appVersion}: $versionLabel',
          icon: Icons.tag_rounded,
        ),
        AboutStatusChip(
          label: kReleaseMode
              ? context.l10n.productionBuild
              : context.l10n.developmentBuild,
          icon: kReleaseMode
              ? Icons.verified_rounded
              : Icons.construction_rounded,
          color: kReleaseMode
              ? (context.isDark
                  ? AppColors.darkSuccess
                  : AppColors.lightSuccess)
              : (context.isDark
                  ? AppColors.darkWarning
                  : AppColors.lightWarning),
        ),
      ],
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return AboutSectionCard(
      title: context.l10n.legal,
      children: [
        ProfileListTile(
          icon: Icons.privacy_tip_outlined,
          iconColor: AppColors.grey,
          title: context.l10n.privacyPolicy,
          subtitle: context.l10n.readInApp,
          showChevron: true,
          onTap: () => AppRoutes.navigateTo(
            context,
            AppRoutes.privacy,
            arguments: {
              'title': context.l10n.privacyPolicy,
              'mdFileName': 'legal/privacy_policy.md',
            },
          ),
        ),
        const AboutDivider(),
        ProfileListTile(
          icon: Icons.description_outlined,
          iconColor: AppColors.grey,
          title: context.l10n.termsOfService,
          subtitle: context.l10n.readInApp,
          showChevron: true,
          onTap: () => AppRoutes.navigateTo(
            context,
            AppRoutes.terms,
            arguments: {
              'title': context.l10n.termsOfService,
              'mdFileName': 'legal/terms_of_service.md',
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final viewModel = context.read<ProfileViewModel>();
    return AboutSectionCard(
      title: context.l10n.support,
      children: [
        ProfileListTile(
          icon: Icons.support_agent_rounded,
          iconColor: AppColors.grey,
          title: context.l10n.contactSupport,
          subtitle: AppConstants.supportEmail.isNotEmpty
              ? AppConstants.supportEmail
              : context.l10n.notConfigured,
          trailing: Icon(Icons.open_in_new_rounded,
              color: context.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              size: (context.isTablet ? 21 : 16)),
          onTap: () => _handleLinkResult(
            viewModel.openSupport(
              '${context.l10n.appName} - ${context.l10n.contactSupport}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicensesCard(
    BuildContext context,
  ) {
    final versionLabel = context.select<ProfileViewModel, String>(
      (vm) => vm.versionLabel,
    );
    return AboutSectionCard(
      title: context.l10n.creditsAttribution,
      children: [
        ProfileListTile(
          icon: Icons.inventory_2_outlined,
          iconColor: AppColors.grey,
          title: context.l10n.openSourceLicenses,
          subtitle: context.l10n.viewLicenses,
          trailing: Icon(
            Icons.open_in_new_rounded,
            color: context.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            size: (context.isTablet ? 21 : 16),
          ),
          onTap: () => _openLicenses(versionLabel),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final versionLabel = context.select<ProfileViewModel, String>(
      (vm) => vm.versionLabel,
    );
    return AboutFooter(versionLabel: versionLabel);
  }
}
