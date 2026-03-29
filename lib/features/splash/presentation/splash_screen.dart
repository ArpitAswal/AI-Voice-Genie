
import 'package:ai_voice_genie/core/constants/app_assets.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/router/app_routes.dart';
import 'package:ai_voice_genie/features/auth/presentation/auth_provider.dart';

import '../../../core/extensions/build_context_extensions.dart';

/// Splash screen for AI Voice Genie.
///
/// Responsibilities:
///   1. Display the app logo and brand animation
///   2. Wait for a minimum display duration (2500ms) for brand impression
///   3. Wait for AuthProvider to resolve auth state
///   4. Navigate to the correct screen based on auth state + user flags
///
/// Navigation logic:
///   authenticated + onboardingDone=false → OnboardingScreen
///   authenticated + keySetupDone=false   → KeySetupScreen
///   authenticated + both done            → HomeScreen
///   unauthenticated                       → LoginScreen
///
/// IMPORTANT: Never navigate based on button taps here.
/// Navigation is always a reaction to AuthState changes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Minimum time the splash screen stays visible (brand impression)
  static const Duration _minDisplayDuration = Duration(seconds: 5);

  bool _minDurationElapsed = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startMinDurationTimer();
  }

  // ── Minimum Duration Timer ─────────────────────────────────────────────────

  void _startMinDurationTimer() {
    Future.delayed(_minDisplayDuration, () {
      if (!mounted) return;
      setState(() => _minDurationElapsed = true);
      // Try to navigate now that min duration has elapsed
      _attemptNavigation();
    });
  }

  // ── Navigation Logic ───────────────────────────────────────────────────────

  /// Attempt navigation only when BOTH conditions are true:
  ///   1. Minimum display duration has elapsed
  ///   2. Auth state is resolved (not AuthState.initial or authenticating)
  void _attemptNavigation() {
    if (_hasNavigated) return;
    if (!_minDurationElapsed) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final authState = authProvider.authState;

    // Still resolving — wait for AuthProvider to call notifyListeners()
    if (authState == AuthState.initial ||
        authState == AuthState.authenticating) {
      return;
    }

    _hasNavigated = true;

    if (authState == AuthState.authenticated) {
      _navigateAuthenticated(authProvider);
    } else {
      _navigateUnauthenticated();
    }
  }

  /// Route an authenticated user to the correct screen.
  void _navigateAuthenticated(AuthProvider authProvider) {
    final user = authProvider.currentUser;

    if (user == null) {
      // Authenticated state but no user model — safety fallback
      _navigateUnauthenticated();
      return;
    }

    if (!user.onboardingDone) {
      // New user — show onboarding first
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.onboarding);
    } else if (!user.keySetupDone) {
      // Onboarding done but no AI keys yet — go to key setup
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.keySetup);
    } else {
      // Fully set up — go to home
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.home);
    }
  }

  void _navigateUnauthenticated() {
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider — triggers _attemptNavigation on state change
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Attempt navigation on every rebuild caused by auth state change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _attemptNavigation();
        });

        return Scaffold(
          body: SafeArea(
            child: _SplashContent(),
          ),
        );
      },
    );
  }
}

// =============================================================================
// PULSING ANIMATOR
// =============================================================================

class _PulsingWidget extends StatefulWidget {
  final Widget child;
  const _PulsingWidget({required this.child});

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// SPLASH CONTENT WIDGET
// =============================================================================

class _SplashContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── App Logo ───────────────────────────────────────────────────────
        Center(
          child: Lottie.asset(
            AppAssets.splashLottie,
            reverse: true,
            repeat: true,
            fit: BoxFit.contain,
            imageProviderFactory: (lottieImage) {
              return const AssetImage(AppAssets.appLogo);
            },
          ),
        ),

        SizedBox(height: isTablet ? 32 : 24),

        // ── App Name ───────────────────────────────────────────────────────
        _PulsingWidget(
          child: Text(
            context.l10n.appName,
            style: context.textTheme.displayLarge,
            textAlign: TextAlign.center,
          ),
        ),

        SizedBox(height: isTablet ? 12 : 8),

        // ── Tagline ────────────────────────────────────────────────────────
        _PulsingWidget(
          child: Text(
            context.l10n.appTagline,
            style: context.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
