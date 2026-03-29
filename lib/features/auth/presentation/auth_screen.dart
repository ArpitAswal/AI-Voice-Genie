import 'dart:io';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/features/auth/presentation/auth_buttons.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../shared/widgets/image_view.dart';
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
  // ── Sign-In Handlers ───────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();

    // Show loading before async gap — context is valid here
    context.showLoading(message: context.l10n.translate('signing_in'));

    await authProvider.signInWithGoogle();

    // Hide loading — always safe, even if sign-in failed
    if (mounted) {
      context.hideLoading();
    }

    // Show error if one was set — check mounted before using context
    if (!mounted) return;
    _consumeError();
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = context.read<AuthProvider>();

    context.showLoading(message: context.l10n.translate('signing_in'));

    await authProvider.signInWithApple();

    if (mounted) {
      context.hideLoading();
    }

    if (!mounted) return;
    _consumeError();
  }

  /// Check if AuthProvider has an error, show it, then clear it.
  void _consumeError() {
    final authProvider = context.read<AuthProvider>();
    final error = authProvider.authError;

    if (error != null && error.isNotEmpty) {
      context.showError(error);
      authProvider.clearAuthError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = context.l10n;

    return Scaffold(
       body: SafeArea(
        child: SingleChildScrollView(
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
                            height: (context.screenHeight *
                                (isTablet ? 0.2 : 0.08))),

                        // ── Welcome Text ─────────────────────────────────────────────
                        Text(
                          l10n.welcome,
                          style: context.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),

                        // ── App Name ─────────────────────────────────────────────
                        Text(
                          l10n.appName,
                          style: context.textTheme.displayLarge,
                          textAlign: TextAlign.center,
                        ),

                        // ── Spacer pushes buttons to bottom ──────────────────────
                        const Spacer(),

                        AuthButtons(
                            isTablet: isTablet,
                            onTap: _handleGoogleSignIn,
                            label: l10n.signInWithGoogle,
                            authType: SocialAuthProvider.google),

                        // Apple Sign-In — iOS only
                        if (Platform.isAndroid) ...[
                          SizedBox(height: isTablet ? 16 : 12),
                          AuthButtons(
                              isTablet: isTablet,
                              onTap: _handleAppleSignIn,
                              label: l10n.signInWithApple,
                              authType: SocialAuthProvider.apple),
                        ],

                        SizedBox(height: isTablet ? 16 : 12),

                        // ── Privacy note ─────────────────────────────────────────
                        Text(
                          l10n.privacyNote,
                          style: context.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(
                            height: (context.screenHeight *
                                (Platform.isIOS
                                    ? (isTablet ? 0.02 : 0.01)
                                    : (isTablet ? 0.2 : 0.06))))
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
