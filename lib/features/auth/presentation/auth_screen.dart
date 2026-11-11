import 'dart:io';

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
          // Material 3 Responsive layout switching:
          // Side-by-side mode on Expanded viewports (>= 840dp) or landscape tablet with sufficient height
          final isSideBySide = constraints.maxWidth >= 840.0 ||
              (constraints.maxWidth >= 600.0 &&
                  constraints.maxWidth > constraints.maxHeight &&
                  constraints.maxHeight >= 500.0);
          debugPrint(
              "constraint width: ${constraints.maxWidth}, height: ${constraints.maxHeight}");

          return isSideBySide
              ? _buildSideBySideView(context, constraints)
              : _buildSingleView(context, constraints);
        },
      ),
    );
  }

  // ── Portrait / Compact Layout ─────────────────────────────────────────────

  Widget _buildSingleView(BuildContext context, BoxConstraints constraints) {
    debugPrint("singleview height: ${constraints.maxHeight}");
    return Stack(
      children: [
        Positioned.fill(child: _AuthBackground(constraints: constraints)),
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
                      child: _AuthTopGreeting(constraints: constraints),
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
                              child: _AuthActions(
                                constraints: constraints,
                                onGoogleSignIn: _handleGoogleSignIn,
                              ),
                            ),
                          ),
                          SizedBox(
                              height:
                                  (constraints.maxHeight < 650) ? 8.0 : 16.0),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child:
                                _PrivacyPolicyFooter(constraints: constraints),
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
        Expanded(child: _AuthBackground(constraints: constraints)),
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
                        _AuthTopGreeting(constraints: paneConstraints),
                        SizedBox(height: isShort ? 16.0 : 32.0),
                        _AuthActions(
                          constraints: paneConstraints,
                          onGoogleSignIn: _handleGoogleSignIn,
                        ),
                        SizedBox(height: isShort ? 8.0 : 16.0),
                        _PrivacyPolicyFooter(constraints: paneConstraints),
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
}

// =============================================================================
// SUB-WIDGET COMPONENTS
// =============================================================================

/// Background artwork with high-quality scaling and theme support.
class _AuthBackground extends StatelessWidget {
  final BoxConstraints constraints;

  const _AuthBackground({required this.constraints});

  @override
  Widget build(BuildContext context) {
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
}

/// Responsive greeting and app title header using container-aware typography.
class _AuthTopGreeting extends StatelessWidget {
  final BoxConstraints constraints;

  const _AuthTopGreeting({required this.constraints});

  @override
  Widget build(BuildContext context) {
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
}

/// Authentication action buttons with guaranteed 48dp minimum touch targets.
class _AuthActions extends StatelessWidget {
  final BoxConstraints constraints;
  final VoidCallback onGoogleSignIn;

  const _AuthActions({
    required this.constraints,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = constraints.maxWidth >= 600;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 500 : double.infinity,
      ),
      child: Column(
        children: [
          _SocialAuthButton(
            constraints: constraints,
            label: context.l10n.signInWithGoogle,
            onTap: onGoogleSignIn,
            authType: SocialAuthProvider.google,
            isBorder: isTablet,
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 16),
            _SocialAuthButton(
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
}

/// Social authentication button respecting WCAG 48×48dp touch targets.
class _SocialAuthButton extends StatelessWidget {
  final BoxConstraints constraints;
  final VoidCallback onTap;
  final SocialAuthProvider authType;
  final String label;
  final bool isBorder;

  const _SocialAuthButton({
    required this.constraints,
    required this.onTap,
    required this.authType,
    required this.label,
    required this.isBorder,
  });

  @override
  Widget build(BuildContext context) {
    final buttonFontStyle = context.buttonLabelStyle(constraints);
    // Strict adherence to >= 48dp touch target across all breakpoints
    final buttonHeight = constraints.maxWidth >= 600 ? 56.0 : 48.0;
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
        vertical: 12.0,
        horizontal: context.horizontalPadding,
      ),
    );
  }
}

/// Privacy Policy & Terms of Service footer with 48×48dp accessible tap targets.
class _PrivacyPolicyFooter extends StatelessWidget {
  final BoxConstraints constraints;

  const _PrivacyPolicyFooter({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final legalStyle = context.legalTextStyle(constraints)?.copyWith(
          height: 1.5,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w400,
        );
    final linkStyle = legalStyle?.copyWith(
      color: context.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: context.colorScheme.primary,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: constraints.maxWidth >= 600 ? 460 : double.infinity,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2.0,
          runSpacing: 0.0,
          runAlignment: WrapAlignment.center,
          children: [
            Text(
              context.l10n.privacyNotePrefix.trim(),
              style: legalStyle,
              textAlign: TextAlign.center,
            ),
            const Text(" "),
            Semantics(
              button: true,
              label: context.l10n.termsOfService,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => AppRoutes.navigateTo(
                  context,
                  AppRoutes.terms,
                  arguments: {
                    'title': context.l10n.termsOfService,
                    'mdFileName': 'legal/terms_of_service.md',
                  },
                ),
                child: Center(
                  widthFactor: 1.0,
                  child: Text(
                    context.l10n.termsOfService,
                    style: linkStyle,
                  ),
                ),
              ),
            ),
            const Text(" "),
            Text(
              context.l10n.privacyNoteAnd.trim(),
              style: legalStyle,
            ),
            const Text(" "),
            Semantics(
              button: true,
              label: context.l10n.privacyPolicy,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => AppRoutes.navigateTo(
                  context,
                  AppRoutes.privacy,
                  arguments: {
                    'title': context.l10n.privacyPolicy,
                    'mdFileName': 'legal/privacy_policy.md',
                  },
                ),
                child: Center(
                  widthFactor: 1.0,
                  child: Text(
                    context.l10n.privacyPolicy,
                    style: linkStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
