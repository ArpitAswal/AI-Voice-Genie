import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/utils/widget_utils.dart';
import '../../../shared/model/image_model.dart';
import '../../../shared/widgets/image_view.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../../usage/presentation/usage_provider.dart';
import 'auth_provider.dart';

/// Login screen for AI Voice Genie.
///
/// Shows:
///   - App logo and branding
///   - "Continue with Google" button (always visible)
///   - "Continue with Apple" button (iOS only — guarded by Platform.isIOS)
///
/// Auth errors are observed from AuthProvider and shown via MessageUtils.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.consumeSessionExpired()) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          context.showWarning(context.l10n.sessionExpired);
        });
      }
    });
  }

  // ── Sign-In Handlers ───────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    context.showLoading(message: context.l10n.signingIn);

    try {
      await authProvider.signInWithGoogle();
    } finally {
      if (mounted) context.hideLoading();
    }

    if (!mounted) return;

    if (authProvider.authState == AuthState.authenticated) {
      _navigateAfterAuth(authProvider);
      return;
    }

    _consumeError(authProvider);
  }

  /// Show and clear any auth error set by AuthProvider.
  void _consumeError(AuthProvider authProvider) {
    final error = authProvider.authError;
    if (error != null && error.isNotEmpty) {
      context.showError(context.l10n.translate(error));
      authProvider.clearAuthError();
    }
  }

  // ── Navigation After Successful Auth ───────────────────────────────────────

  void _navigateAfterAuth(AuthProvider authProvider) {
    final user = authProvider.currentUser;

    if (user == null) {
      context.showError(context.l10n.somethingWentWrong);
      return;
    }

    if (user.keySetupDone) {
      context.read<ApiKeyProvider>().loadExistingKeys(user.uid);
      context.read<UsageProvider>().loadForMonth(user.uid);
    }

    if (!user.onboardingDone) {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.onboarding);
    } else if (!user.keySetupDone) {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.keySetup);
    } else {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.tabBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final isTabletLandscape =
              size.width >= 600 && size.width > size.height;

          return isTabletLandscape
              ? _buildSideBySideView(context, constraints)
              : _buildSingleView(context, constraints);
        },
      ),
    );
  }

  // ── Portrait / Compact Layout ─────────────────────────────────────────────

  Widget _buildSingleView(BuildContext context, BoxConstraints constraints) {
    return Stack(
      children: [
        Positioned.fill(child: _buildBackground(constraints)),
        SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.viewPadding.top + 16,
                      ),
                      child: _buildTopGreeting(context, constraints),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.viewPadding.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Center(
                              child: _buildAuthenticationAction(
                                  context, constraints),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: _buildPrivacyNote(context, constraints),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Landscape / Tablet Side-by-Side Layout ──────────────────────────────────

  Widget _buildSideBySideView(
      BuildContext context, BoxConstraints constraints) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildBackground(constraints)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, paneConstraints) {
              final isShort = paneConstraints.maxHeight < 500;

              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                    vertical: context.verticalSpacing,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopGreeting(context, paneConstraints),
                        SizedBox(height: isShort ? 16.0 : 32.0),
                        _buildAuthenticationAction(context, paneConstraints),
                        SizedBox(height: isShort ? 8.0 : 16.0),
                        _buildPrivacyNote(context, paneConstraints),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(BoxConstraints constraints) {
    return ImageView(
      image: ImageViewData.asset(
        context.isDark ? AppAssets.darkAuth : AppAssets.lightAuth,
      ),
      height: constraints.maxHeight,
      width: constraints.maxWidth,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildTopGreeting(BuildContext context, BoxConstraints constraints) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.welcome,
          style: context.subHeaderStyle(constraints)?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
          textAlign: TextAlign.center,
        ),
        Text(
          context.l10n.appName,
          style: context.titleHeaderStyle(constraints)?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthenticationAction(
      BuildContext context, BoxConstraints constraints) {
    final isTablet = constraints.maxWidth >= 600;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 500 : double.infinity,
      ),
      child: Column(
        children: [
          _authButton(
            context,
            constraints: constraints,
            label: context.l10n.signInWithGoogle,
            onTap: _handleGoogleSignIn,
            authType: SocialAuthProvider.google,
            isBorder: isTablet,
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 15),
            _authButton(
              context,
              constraints: constraints,
              label: context.l10n.signInWithApple,
              onTap: () {},
              authType: SocialAuthProvider.apple,
              isBorder: isTablet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _authButton(
    BuildContext context, {
    required BoxConstraints constraints,
    required VoidCallback onTap,
    required SocialAuthProvider authType,
    required String label,
    required bool isBorder,
  }) {
    final buttonFontStyle = context.buttonLabelStyle(constraints);
    final isSmall = constraints.maxWidth <= 360 || constraints.maxHeight <= 550;
    final buttonHeight =
        constraints.maxWidth >= 600 ? 56.0 : (isSmall ? 40.0 : 48.0);
    final verticalPadding = isSmall ? 8.0 : 12.0;
    final isGoogle = authType == SocialAuthProvider.google;

    return context.themedElevatedButton(
      label: label,
      height: buttonHeight,
      textStyle: isGoogle
          ? buttonFontStyle
          : buttonFontStyle?.copyWith(color: AppColors.white),
      width: double.infinity,
      onPressed: onTap,
      background: isGoogle ? AppColors.white : AppColors.black,
      foreground: isGoogle ? AppColors.black : AppColors.white,
      imgIcon: isGoogle ? AppAssets.googleLogo : AppAssets.appleLogo,
      imgColor: isGoogle ? null : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: context.isDark && isBorder
              ? (isGoogle ? Colors.black : Colors.white)
              : Colors.transparent,
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: context.horizontalPadding,
      ),
    );
  }

  // ── Privacy Note with Clickable Legal Links ────────────────────────────────

  Widget _buildPrivacyNote(BuildContext context, BoxConstraints constraints) {
    final legalStyle = context.legalTextStyle(constraints)?.copyWith(
          height: 1.6,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w400,
        );
    final linkStyle = legalStyle?.copyWith(
      color: context.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: context.colorScheme.primary,
    );

    TextSpan linkSpan(String text, String route, String mdFileName) {
      return TextSpan(
        text: text,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => AppRoutes.navigateTo(
                context,
                route,
                arguments: {'title': text, 'mdFileName': mdFileName},
              ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: constraints.maxWidth >= 600 ? 440 : double.infinity,
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: legalStyle,
            children: [
              TextSpan(text: context.l10n.privacyNotePrefix),
              linkSpan(
                context.l10n.termsOfService,
                AppRoutes.terms,
                'legal/terms_of_service.md',
              ),
              TextSpan(text: context.l10n.privacyNoteAnd),
              linkSpan(
                context.l10n.privacyPolicy,
                AppRoutes.privacy,
                'legal/privacy_policy.md',
              ),
              TextSpan(text: context.l10n.privacyNoteSuffix),
            ],
          ),
        ),
      ),
    );
  }
}

