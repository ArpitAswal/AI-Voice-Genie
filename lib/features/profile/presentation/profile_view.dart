import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/widgets/app_alert_dialog.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../usage/presentation/usage_provider.dart';
import 'profile_view_model.dart';
import 'widgets/account_panel.dart';
import 'widgets/ai_intelligence_section.dart';
import 'widgets/ai_preferences_panel.dart';
import 'widgets/profile_common_widgets.dart';
import 'widgets/profile_header.dart';
import 'widgets/settings_panel.dart';
import 'widgets/support_panel.dart';

export '../../legal_section/presentation/about_screen.dart';
export 'edit_profile_screen.dart';

/// Material 3 Adaptive Profile Screen supporting Compact, Medium, and Expanded viewports.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel();
    // Load usage data after the first frame so we have auth context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<UsageProvider>().loadForMonth(uid);
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final viewModel = context.read<ProfileViewModel>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.signOut),
        content: Text(context.l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => AppRoutes.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: context.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => AppRoutes.pop(context, true),
            child: Text(
              context.l10n.signOut,
              style: TextStyle(
                color:
                    context.isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    LoadingOverlay.show(context, message: context.l10n.signingOut);
    bool success = false;
    try {
      success = await viewModel.signOut(context.read<AuthProvider>());
    } finally {
      LoadingOverlay.hide();
    }

    if (!mounted) return;
    if (success) {
      MessageUtils.showSuccess(context, context.l10n.signOutSuccess);
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
    } else {
      final errorKey = viewModel.errorMessage ?? 'sign_out_failed';
      MessageUtils.showError(context, context.l10n.translate(errorKey));
      viewModel.clearErrorMessage();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final viewModel = context.read<ProfileViewModel>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.deleteAccount),
        content: Text(context.l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => AppRoutes.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: context.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => AppRoutes.pop(context, true),
            child: Text(
              context.l10n.deleteAccount,
              style: TextStyle(
                color:
                    context.isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    // Show loading overlay while account deletion coordinates across remote and local databases.
    // AuthProvider and ProfileViewModel guarantee catching any exception and returning a boolean,
    // ensuring LoadingOverlay.hide() always runs without freezing the UI.
    LoadingOverlay.show(context, message: context.l10n.deletingAccount);
    bool success = false;
    try {
      success = await viewModel.deleteAccount(context.read<AuthProvider>());
    } finally {
      LoadingOverlay.hide();
    }

    if (!mounted) return;
    if (success) {
      context.read<UsageProvider>().clear();
      // Only navigate away if the account was successfully wiped and deleted.
      MessageUtils.showSuccess(context, context.l10n.accountDeleted);
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
    } else {
      // If deletion failed (e.g. requires-recent-login or offline), stay on the Profile screen
      // and display a specific localized error toast so the user knows why the account was NOT deleted.
      final authProvider = context.read<AuthProvider>();
      final errorKey = viewModel.errorMessage ??
          authProvider.authError ??
          'delete_account_failed';
      MessageUtils.showError(context, context.l10n.translate(errorKey));
      viewModel.clearErrorMessage();
      authProvider.clearAuthError();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Keep Provider above Scaffold to scope the ViewModel to the entire screen
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              if (height <= 550.0 || width < 600.0) {
                return _buildCompactLayout(context,
                    isShortHeight: height <= 550.0);
              }
              if (width >= 840.0) {
                return _buildExpandedLayout(context);
              }
              return _buildMediumLayout(context);
            },
          ),
        ),
      ),
    );
  }

  // ── 1. Compact Viewport (< 600dp or height <= 550dp) ─────────────────────────
  Widget _buildCompactLayout(
    BuildContext context, {
    required bool isShortHeight,
  }) {
    // Dynamic vertical spacing: tightened on short-height displays to minimize vertical sprawl
    final double verticalPadding =
        isShortHeight ? 12.0 : context.verticalSpacing;
    final double sectionSpacing = isShortHeight ? 14.0 : 20.0;
    final double headerSpacing = isShortHeight ? 10.0 : 16.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeaderSection(isShortHeight: isShortHeight),
          SizedBox(height: headerSpacing),
          _AppSettingsSection(isShortHeight: isShortHeight),
          SizedBox(height: sectionSpacing),
          _AiPreferencesSection(isShortHeight: isShortHeight),
          SizedBox(height: sectionSpacing),
          ProfileAiIntelligenceSection(isShortHeight: isShortHeight),
          SizedBox(height: sectionSpacing),
          _SupportSection(isShortHeight: isShortHeight),
          SizedBox(height: sectionSpacing),
          _AccountSection(
            onLogout: () => _handleLogout(),
            onDeleteAccount: () => _handleDeleteAccount(),
          ),
          // Soft keyboard clearance and bottom inset safety
          SizedBox(height: context.viewInsets.bottom + 16.0),
        ],
      ),
    );
  }

  // ── 2. Medium Viewport (600dp <= width < 840dp && height > 550dp) ────────────
  Widget _buildMediumLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640.0),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileHeaderSection(),
              const SizedBox(height: 20.0),
              const _AppSettingsSection(),
              const SizedBox(height: 20.0),
              const _AiPreferencesSection(),
              const SizedBox(height: 20.0),
              const ProfileAiIntelligenceSection(),
              const SizedBox(height: 20.0),
              const _SupportSection(),
              const SizedBox(height: 20.0),
              _AccountSection(
                onLogout: () => _handleLogout(),
                onDeleteAccount: () => _handleDeleteAccount(),
              ),
              // Soft keyboard clearance and bottom inset safety
              SizedBox(height: context.viewInsets.bottom + 16.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Expanded Viewport (width >= 840dp && height > 550dp) ──────────────────
  Widget _buildExpandedLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200.0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
          ).copyWith(top: context.verticalSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left Hero Pane: Identity, App Settings, Support & Account ─────────
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 280.0,
                  maxWidth: 360.0,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ProfileHeaderSection(),
                      const SizedBox(height: 20.0),
                      // App Settings placed above AppSupport in the left pane
                      const _AppSettingsSection(),
                      const SizedBox(height: 20.0),
                      // AppSupport section
                      const _SupportSection(),
                      const SizedBox(height: 20.0),
                      // Account section
                      _AccountSection(
                        onLogout: () => _handleLogout(),
                        onDeleteAccount: () => _handleDeleteAccount(),
                      ),
                      SizedBox(height: context.viewInsets.bottom + 16.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24.0),

              // ── Right Workspace Pane: AI Preferences & Vertical Intelligence Grid ─
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Preferences
                        const _AiPreferencesSection(),
                        const SizedBox(height: 20.0),
                        // AI Intelligence with all cards stacked vertically
                        const ProfileAiIntelligenceSection(),
                        SizedBox(height: context.viewInsets.bottom + 16.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULAR SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Top app bar row featuring title and accessible 48x48dp edit profile action.
class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    this.isShortHeight = false,
  });

  final bool isShortHeight;

  @override
  Widget build(BuildContext context) {
    // Dynamic typography: step to headlineMedium on height-constrained viewports, headlineLarge on tablet
    final titleStyle = isShortHeight
        ? context.textTheme.headlineMedium
        : (context.isTablet
            ? context.textTheme.displayMedium
                ?.copyWith(fontWeight: FontWeight.w700)
            : context.textTheme.displaySmall);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          context.l10n.profile,
          style: titleStyle,
        ),
        // Minimum 48x48dp accessible touch target with ink ripple and hover feedback
        IconButton(
          onPressed: () => AppRoutes.navigateTo(context, AppRoutes.profileEdit),
          tooltip: context.l10n.editProfile,
          constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
          icon: FaIcon(
            FontAwesomeIcons.penToSquare,
            size: context.isTablet ? 24.0 : 16,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Visual header section containing title, edit shortcut, and user identity summary.
class _ProfileHeaderSection extends StatelessWidget {
  const _ProfileHeaderSection({
    this.isShortHeight = false,
  });

  final bool isShortHeight;

  @override
  Widget build(BuildContext context) {
    // Using context.select so ONLY the header rebuilds when user changes:
    final user =
        context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileTopBar(isShortHeight: isShortHeight),
        SizedBox(height: isShortHeight ? 4.0 : 8.0),
        if (user != null)
          ProfileHeader(user: user, isShortHeight: isShortHeight),
      ],
    );
  }
}

/// App settings section (Theme switcher and language preferences).
class _AppSettingsSection extends StatelessWidget {
  final bool isShortHeight;
  const _AppSettingsSection({this.isShortHeight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileSectionTitle(
            label: context.l10n.appSettings, isShortHeight: isShortHeight),
        const SizedBox(height: 14.0),
        const ProfileSettingsPanel(),
      ],
    );
  }
}

/// AI preferences section (Default provider, auto TTS, response creativity).
class _AiPreferencesSection extends StatelessWidget {
  const _AiPreferencesSection({this.isShortHeight = false});

  final bool isShortHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileSectionTitle(
            label: context.l10n.aiPreferences, isShortHeight: isShortHeight),
        const SizedBox(height: 14.0),
        const ProfileAiPreferencesPanel(),
      ],
    );
  }
}

/// Support & Help section (Help center email, About screen).
class _SupportSection extends StatelessWidget {
  const _SupportSection({this.isShortHeight = false});

  final bool isShortHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileSectionTitle(
            label: context.l10n.support, isShortHeight: isShortHeight),
        const SizedBox(height: 14.0),
        const ProfileSupportPanel(),
      ],
    );
  }
}

/// Account management section (Sign out, delete account).
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileSectionTitle(label: context.l10n.account),
        const SizedBox(height: 14.0),
        ProfileAccountPanel(
          onLogout: onLogout,
          onDeleteAccount: onDeleteAccount,
        ),
      ],
    );
  }
}
