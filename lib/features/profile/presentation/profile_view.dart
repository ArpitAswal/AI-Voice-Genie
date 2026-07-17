import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
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

export 'screens/about_screen.dart';
export 'screens/edit_profile_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel;
  late final UsageProvider _usageProvider;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel();
    _usageProvider = UsageProvider();
    // Load usage data after the first frame so we have auth context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        _usageProvider.loadForMonth(uid);
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _usageProvider.dispose();
    super.dispose();
  }

  Future<void> _handleLogout(ProfileViewModel viewModel) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              style: const TextStyle(color: AppColors.lightError),
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
    MessageUtils.showSuccess(context, context.l10n.signOutSuccess);
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _viewModel),
        ChangeNotifierProvider.value(value: _usageProvider),
      ],
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
                  Text(
                    context.l10n.profile,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: context.isDark
                            ? AppColors.primaryLight
                            : AppColors.primaryDark),
                  ),
                  ProfileHeader(user: authProvider.currentUser),
                  const SizedBox(height: 14),
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
                  ProfileSupportPanel(
                    onLogout: () => _handleLogout(viewModel),
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
