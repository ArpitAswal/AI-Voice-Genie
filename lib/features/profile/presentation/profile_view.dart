import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../usage/presentation/usage_provider.dart';
import '../domain/profile_view_model.dart';
import 'widgets/ai_intelligence_section.dart';
import 'widgets/ai_preferences_panel.dart';
import 'widgets/profile_common_widgets.dart';
import 'widgets/profile_header.dart';
import 'widgets/settings_panel.dart';
import 'widgets/support_panel.dart';
import 'widgets/account_panel.dart';

export '../../legal_section/presentation/about_screen.dart';
export 'edit_profile_screen.dart';

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

  Future<void> _handleLogout(ProfileViewModel viewModel) async {
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
                  color: context.isDark
                      ? AppColors.darkError
                      : AppColors.lightError),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    LoadingOverlay.show(context, message: context.l10n.signingOut);
    await viewModel.signOut(context.read<AuthProvider>());
    LoadingOverlay.hide();

    if (!mounted) return;
    context.read<UsageProvider>().clear();
    MessageUtils.showSuccess(context, context.l10n.signOutSuccess);
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
  }

  Future<void> _handleDeleteAccount(ProfileViewModel viewModel) async {
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
                  color: context.isDark
                      ? AppColors.darkError
                      : AppColors.lightError),
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
    final success = await viewModel.deleteAccount(context.read<AuthProvider>());
    LoadingOverlay.hide();

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
      final errorKey = authProvider.authError ?? 'something_went_wrong';
      MessageUtils.showError(context, context.l10n.translate(errorKey));
      authProvider.clearAuthError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer2<AuthProvider, ProfileViewModel>(
        builder: (context, authProvider, viewModel, _) {
          return Scaffold(
            body: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                  vertical: context.verticalSpacing,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.profile,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      GestureDetector(
                          onTap: () => AppRoutes.navigateTo(
                              context, AppRoutes.profileEdit),
                        child: FaIcon(FontAwesomeIcons.penToSquare,
                        size: context.textTheme.titleLarge?.fontSize,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProfileHeader(user: authProvider.currentUser),
                  const SizedBox(height: 8),
                  ProfileSectionTitle(label: context.l10n.appSettings),
                  const SizedBox(height: 14),
                  const ProfileSettingsPanel(),
                  const SizedBox(height: 24),
                  ProfileSectionTitle(label: context.l10n.aiPreferences),
                  const SizedBox(height: 14),
                  const ProfileAiPreferencesPanel(),
                  const SizedBox(height: 24),
                  const ProfileAiIntelligenceSection(),
                  const SizedBox(height: 24),
                  ProfileSectionTitle(label: context.l10n.support),
                  const SizedBox(height: 14),
                  const ProfileSupportPanel(),
                  const SizedBox(height: 24),
                  ProfileSectionTitle(label: context.l10n.account),
                  const SizedBox(height: 14),
                  ProfileAccountPanel(
                    onLogout: () => _handleLogout(viewModel),
                    onDeleteAccount: () => _handleDeleteAccount(viewModel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
