import 'dart:io';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/utils/widget_utils.dart';
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
/// Auth errors are observed from AuthProvider and shown via
/// MessageUtils (context extension) after the loading overlay hides.
///
/// Navigation after successful auth is handled entirely by SplashScreen
/// observing AuthState — this screen does NOT navigate anywhere.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    // Check if session was terminated remotely or expired, and alert user upon landing on login screen
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

    // Show loading before async gap — context is valid here
    context.showLoading(message: context.l10n.signingIn);

    try {
      await authProvider.signInWithGoogle();
    } finally {
      // Hide loading — guaranteed to run even if an exception occurs
      if (mounted) {
        context.hideLoading();
      }
    }

    // Show error if one was set — check mounted before using context
    if (!mounted) return;

    // If sign-in succeeded, navigate to the correct screen
    if (authProvider.authState == AuthState.authenticated) {
      _navigateAfterAuth(authProvider);
      return;
    }

    // Otherwise show the localized error message
    _consumeError(authProvider);
  }

  // Apple Sign-In is temporarily disabled pending Apple Developer account setup
  // Future<void> _handleAppleSignIn() async {
  //   final authProvider = context.read<AuthProvider>();
  //   context.showLoading(message: context.l10n.signingIn);
  //   try {
  //     await authProvider.signInWithApple();
  //   } finally {
  //     if (mounted) {
  //       context.hideLoading();
  //     }
  //   }
  //   if (!mounted) return;
  //   if (authProvider.authState == AuthState.authenticated) {
  //     _navigateAfterAuth(authProvider);
  //     return;
  //   }
  //   _consumeError(authProvider);
  // }

  /// Check if AuthProvider has an error, show it, then clear it.
  /// Show and clear any auth error set by AuthProvider.
  ///
  /// Not called on cancellation — cancelled sign-in sets no error.
  /// Check if AuthProvider has an error, show localized message, then clear it.
  /// Not called on cancellation — cancelled sign-in sets no error.
  void _consumeError(AuthProvider authProvider) {
    final error = authProvider.authError;
    if (error != null && error.isNotEmpty) {
      // Look up localized text for the auth error code
      context.showError(context.l10n.translate(error));
      authProvider.clearAuthError();
    }
  }

  // ── Navigation After Successful Auth ───────────────────────────────────────

  /// Routes to the correct screen based on the user's setup flags.
  ///
  /// This mirrors the same logic in SplashScreen._navigateAuthenticated()
  /// and is intentionally duplicated here — SplashScreen is no longer
  /// mounted when LoginScreen is on screen.
  ///
  /// Stack is cleared so the user cannot press back into LoginScreen.
  void _navigateAfterAuth(AuthProvider authProvider) {
    final user = authProvider.currentUser;

    if (user == null) {
      // Safety guard — authenticated state with no user model is unexpected
      // Stay on LoginScreen and show localized generic error
      context.showError(context.l10n.somethingWentWrong);
      return;
    } else {
      if (user.keySetupDone) {
        context.read<ApiKeyProvider>().loadExistingKeys(user.uid);
        context.read<UsageProvider>().loadForMonth(user.uid);
      }
    }

    if (!user.onboardingDone) {
      // Brand new user — show onboarding first
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.onboarding);
    } else if (!user.keySetupDone) {
      // Onboarding done but no AI keys configured yet
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.keySetup);
    } else {
      // Fully set up returning user
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.tabBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        // debugPrint(
        //     "maxWidth: ${constraints.maxWidth}, and minWidth: ${constraints.minWidth}");
        // debugPrint(
        //     "maxHeight: ${constraints.maxHeight}, and minHeight: ${constraints.minHeight}");

        final size = MediaQuery.sizeOf(context);
        final isLandscape = size.width > size.height;

        // 1. Tablet & Desktop layouts with orientation-specific composition
        if (size.width >= 600 && isLandscape) {
          return _buildSideBySideView(context, constraints);
        }

        // 2. Phone layouts with orientation-specific composition
        return _buildSingleView(context, constraints);
      }),
    );
  }

  Widget _buildSingleView(BuildContext context, BoxConstraints constraints) {
    return Stack(
      children: [
        // ── Background Image (edge-to-edge full bleed) ───────────────
        Positioned.fill(child: _imageView(constraints)),

        // ── Foreground Content (respects device safe areas) ──────────
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
                    // ── Top Greeting ─────────────────────────────
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.viewPadding.top + 16,
                      ),
                      child: _buildTopGreeting(context, constraints),
                    ),

                    // ── Bottom Authentication Actions & Privacy Note ─────────
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

  Widget _buildSideBySideView(
      BuildContext context, BoxConstraints constraints) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: _imageView(constraints)),
        Expanded(
          flex: 1,
          child: LayoutBuilder(
            builder: (context, paneConstraints) {
              final isShortHeight = paneConstraints.maxHeight < 500;
              final verticalGap = isShortHeight ? 16.0 : 32.0;
              final privacyGap = isShortHeight ? 8.0 : 16.0;

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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Top Greeting ───────────────────────────────────────────────
                        _buildTopGreeting(context, paneConstraints),

                        SizedBox(height: verticalGap),

                        // ── Authentication Actions ─────────────────────────────────────
                        _buildAuthenticationAction(context, paneConstraints),

                        SizedBox(height: privacyGap),

                        // ── Privacy Note ───────────────────────────────────────────────
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

  Widget _imageView(BoxConstraints constraints) {
    return ImageView(
      image: ImageViewData.asset(
          context.isDark ? AppAssets.darkAuth : AppAssets.lightAuth),
      height: constraints.maxHeight,
      width: constraints.maxWidth,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildTopGreeting(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final subheaderStyle = context.subHeaderStyle(constraints);
    final headerStyle = context.titleHeaderStyle(constraints);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Welcome Text ─────────────────────────────────────────────
        Text(
          context.l10n.welcome,
          style: subheaderStyle?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),

        // ── App Name ─────────────────────────────────────────────
        Text(
          context.l10n.appName,
          style: headerStyle?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthenticationAction(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth >= 600 ? 500 : double.infinity,
      ),
      child: Column(
        children: [
          _authAction(context,
              constraints: constraints,
              label: context.l10n.signInWithGoogle,
              onTap: _handleGoogleSignIn,
              authType: SocialAuthProvider.google,
              isBorder: constraints.maxWidth >= 600),
          if (Platform.isIOS) ...[
            const SizedBox(height: 15),
            _authAction(context,
                constraints: constraints,
                label: context.l10n.signInWithApple,
                onTap: () {},
                authType: SocialAuthProvider.apple,
                isBorder: constraints.maxWidth >= 600)
          ],
        ],
      ),
    );
  }

  Widget _authAction(
    BuildContext context, {
    required BoxConstraints constraints,
    required Function() onTap,
    required SocialAuthProvider authType,
    required String label,
    required bool isBorder,
  }) {
    final buttonFontStyle = context.buttonLabelStyle(constraints);
    final isSmall = constraints.maxWidth <= 360 || constraints.maxHeight <= 550;
    final buttonHeight =
        constraints.maxWidth >= 600 ? 56.0 : (isSmall ? 40.0 : 48.0);
    final verticalPadding = isSmall ? 8.0 : 12.0;

    return (authType.name == SocialAuthProvider.google.name)
        ? context.themedElevatedButton(
            label: label,
            height: buttonHeight,
            textStyle: buttonFontStyle,
            width: double.infinity,
            onPressed: () => onTap(),
            background: AppColors.white,
            foreground: AppColors.black,
            imgIcon: AppAssets.googleLogo,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(
                    color: context.isDark && isBorder
                        ? Colors.black
                        : Colors.transparent)),
            padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: context.horizontalPadding))
        : context.themedElevatedButton(
            label: label,
            height: buttonHeight,
            textStyle: buttonFontStyle?.copyWith(color: AppColors.white),
            width: double.infinity,
            onPressed: () => onTap(),
            background: AppColors.black,
            foreground: AppColors.white,
            imgIcon: AppAssets.appleLogo,
            imgColor: AppColors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(
                    color: context.isDark && isBorder
                        ? Colors.white
                        : Colors.transparent)),
            padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: context.horizontalPadding));
  }

  // ── Privacy Note with Clickable Legal Links ────────────────────────────────
  Widget _buildPrivacyNote(
    BuildContext context,
    BoxConstraints constraints,
  ) {
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
              TextSpan(
                text: context.l10n.termsOfService,
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => AppRoutes.navigateTo(
                        context,
                        AppRoutes.terms,
                        arguments: {
                          'title': context.l10n.termsOfService,
                          'mdFileName': 'legal/terms_of_service.md',
                        },
                      ),
              ),
              TextSpan(text: context.l10n.privacyNoteAnd),
              TextSpan(
                text: context.l10n.privacyPolicy,
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => AppRoutes.navigateTo(
                        context,
                        AppRoutes.privacy,
                        arguments: {
                          'title': context.l10n.privacyPolicy,
                          'mdFileName': 'legal/privacy_policy.md',
                        },
                      ),
              ),
              TextSpan(text: context.l10n.privacyNoteSuffix),
            ],
          ),
        ),
      ),
    );
  }
}
