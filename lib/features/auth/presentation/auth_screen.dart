// import 'dart:io';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/features/auth/presentation/widgets/auth_buttons.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
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
    final isTablet = context.isTablet;
    final l10n = context.l10n;

    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            ImageView(
              image: ImageViewData.asset(
                  context.isDark ? AppAssets.darkAuth : AppAssets.lightAuth),
              height: context.screenHeight,
              width: context.screenHeight,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: context.screenHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Top Spacer ───────────────────────────────────────────
                      SizedBox(
                          height:
                              (context.screenHeight * (isTablet ? 0.2 : 0.1))),

                      // ── Welcome Text ─────────────────────────────────────────────
                      Text(
                        l10n.welcome,
                        style: context.textTheme.titleLarge?.copyWith(
                            color: context.textTheme.bodyLarge?.color),
                        textAlign: TextAlign.center,
                      ),

                      // ── App Name ─────────────────────────────────────────────
                      Text(
                        l10n.appName,
                        style: context.textTheme.displaySmall?.copyWith(
                            color: context.textTheme.bodyLarge?.color),
                        textAlign: TextAlign.center,
                      ),

                      // ── Spacer pushes buttons to bottom ──────────────────────
                      const Spacer(),

                      AuthButtons(
                          isTablet: isTablet,
                          onTap: _handleGoogleSignIn,
                          label: l10n.signInWithGoogle,
                          authType: SocialAuthProvider.google),

                      // Apple Sign-In is temporarily disabled pending Apple Developer account setup
                      // if (Platform.isIOS) ...[
                      //   SizedBox(height: isTablet ? 16 : 12),
                      //   AuthButtons(
                      //       isTablet: isTablet,
                      //       onTap: _handleAppleSignIn,
                      //       label: l10n.signInWithApple,
                      //       authType: SocialAuthProvider.apple),
                      // ],

                      SizedBox(height: isTablet ? 16 : 12),

                      // ── Privacy note ─────────────────────────────────────────
                      _buildPrivacyNote(context),

                      SizedBox(
                          height:
                              (context.screenHeight * (isTablet ? 0.2 : 0.06)))
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Privacy Note with Clickable Legal Links ────────────────────────────────
  Widget _buildPrivacyNote(BuildContext context) {
    final l10n = context.l10n;
    final linkStyle = context.textTheme.bodySmall?.copyWith(
      color: context.primaryColor,
      fontWeight: FontWeight.w600,
    );
    final normalStyle = context.textTheme.bodySmall;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: normalStyle,
        children: [
          TextSpan(text: l10n.privacyNotePrefix),
          TextSpan(
            text: l10n.termsOfService,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => AppRoutes.navigateTo(
                    context,
                    AppRoutes.terms,
                    arguments: {
                      'title': l10n.termsOfService,
                      'mdFileName': 'legal/terms_of_service.md',
                    },
                  ),
          ),
          TextSpan(text: l10n.privacyNoteAnd),
          TextSpan(
            text: l10n.privacyPolicy,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => AppRoutes.navigateTo(
                    context,
                    AppRoutes.privacy,
                    arguments: {
                      'title': l10n.privacyPolicy,
                      'mdFileName': 'legal/privacy_policy.md',
                    },
                  ),
          ),
          TextSpan(text: l10n.privacyNoteSuffix),
        ],
      ),
    );
  }
}
