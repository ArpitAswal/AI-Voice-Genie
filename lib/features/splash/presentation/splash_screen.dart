import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import 'package:ai_voice_genie/core/constants/app_assets.dart';
import 'package:ai_voice_genie/core/enums/app_enums.dart';
import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:ai_voice_genie/core/localization/app_localizations.dart';
import 'package:ai_voice_genie/core/router/app_routes.dart';
import 'package:ai_voice_genie/features/auth/presentation/auth_provider.dart';
import 'package:ai_voice_genie/features/key_setup/presentation/api_key_provider.dart';
import 'package:ai_voice_genie/features/usage/presentation/usage_provider.dart';

/// Splash screen for AI Voice Genie.
///
/// Features:
///   - Unconstrained full-bleed Scaffold background across all devices & orientations
///   - Unified theatrical conical spotlight beam on all viewports (phones, tablets, portrait, landscape)
///   - Centered brand emblem lockup (mascot + hero title + tagline) with clamped content width
///   - Dynamic typography matching golden reference standards
///   - Resolves AuthState + user setup flags before routing
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Minimum time the splash screen stays visible (brand impression)
  static const Duration _minDisplayDuration = Duration(seconds: 3);

  Timer? _minDurationTimer;
  bool _minDurationElapsed = false;
  bool _hasNavigated = false;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _startMinDurationTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    if (_authProvider != authProvider) {
      _authProvider?.removeListener(_onAuthStateChanged);
      _authProvider = authProvider;
      _authProvider?.addListener(_onAuthStateChanged);
    }
    _attemptNavigation();
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    _attemptNavigation();
  }

  // ── Minimum Duration Timer ─────────────────────────────────────────────────

  void _startMinDurationTimer() {
    _minDurationTimer = Timer(_minDisplayDuration, () {
      if (!mounted) return;
      _minDurationElapsed = true;
      _attemptNavigation();
    });
  }

  // ── Navigation Logic ───────────────────────────────────────────────────────

  /// Attempt navigation only when BOTH conditions are true:
  ///   1. Minimum display duration has elapsed (3s)
  ///   2. Auth state is resolved (not initial or authenticating)
  void _attemptNavigation() {
    if (_hasNavigated) return;
    if (!_minDurationElapsed) return;
    if (!mounted) return;

    final authProvider = _authProvider ?? context.read<AuthProvider>();
    final authState = authProvider.authState;

    // Still resolving — wait for AuthProvider to notify
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
      _navigateUnauthenticated();
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

  void _navigateUnauthenticated() {
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      // The Scaffold and its background color are unconstrained to fill the entire screen
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SafeArea(
            child: Stack(
              alignment: AlignmentGeometry.center,
              children: [
                // ── Background Theatrical Conical Spotlight (Edge-to-Edge) ─────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      isDark: isDark,
                    ),
                  ),
                ),

                // ── Foreground Centered Adaptive Content ───────────────────────
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildCenteredContent(context, constraints),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Unified Centered Brand Content (Phones, Tablets & Orientations) ─────────

  Widget _buildCenteredContent(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height <= 550 || size.width <= 360;
    final isTablet = context.isTablet;

    final logoToTextGap = isShort ? 8.0 : (isTablet ? 16.0 : 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MascotWidget(constraints: constraints),
        SizedBox(height: logoToTextGap),
        _BrandTextLockup(constraints: constraints),
      ],
    );
  }
}

// =============================================================================
// BACKGROUND SPOTLIGHT PAINTER (FULL-HEIGHT THEATRICAL CONICAL BEAM)
// =============================================================================

class _SpotlightPainter extends CustomPainter {
  final bool isDark;

  const _SpotlightPainter({
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isLandscape = size.width > size.height;

    // Constrain only the conical beam width so it stays focused on tablets and landscape,
    // while the foreground tagline and brand text remain unconstrained.
    final maxBeamWidth = isLandscape ? 480.0 : math.min(size.width, 420.0);
    final topHalfWidth = maxBeamWidth * 0.5;

    // Full-height canonical beam starting right from the top edge of the screen (0.0),
    // with no top padding, down to full screen height.
    const topY = 0.0;
    final bottomY = size.height;
    final centerX = size.width * 0.5;

    final path = Path();
    final topLeft = Offset(centerX - topHalfWidth, topY);
    final topRight = Offset(centerX + topHalfWidth, topY);
    final bottomPoint = Offset(centerX, bottomY);

    path.moveTo(topLeft.dx, topLeft.dy);
    path.lineTo(topRight.dx, topRight.dy);
    path.lineTo(bottomPoint.dx, bottomPoint.dy);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                // const Color(0x2818FFFF), // Luminous teal beam right from top edge
                const Color(0x000B1220), // Seamless fade at bottom
                const Color(0x2018FFFF),
                const Color(0x1418FFFF),
                const Color(0x0818FFFF),
                const Color(0x000B1220), // Seamless fade at bottom
              ]
            : [
                // const Color(0xD8D8F3E5), // Frosted Luminous Mint right from top edge
                const Color(0x00E5E5E5), // Seamless blend at bottom
                const Color(0xB8C2EEDB), // Core Mint
                const Color(0x78C2EEDB), // Soft mint mid-tone
                const Color(0x28C2EEDB), // Soft lower fade
                const Color(0x00E5E5E5), // Seamless blend at bottom
              ],
        stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
      ).createShader(Rect.fromLTRB(
        centerX - topHalfWidth,
        topY,
        centerX + topHalfWidth,
        bottomY,
      ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

// =============================================================================
// MASCOT WIDGET (LOTTIE ANIMATION WITH CONSTRAINED BOUNDS)
// =============================================================================

class _MascotWidget extends StatelessWidget {
  final BoxConstraints constraints;

  const _MascotWidget({
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isTablet = context.isTablet;
    final isShort = size.height <= 550 || size.width <= 360;

    // Dynamically calculate the bounded size for the mascot:

    final double dynamicSize;
    if (isShort) {
      dynamicSize = (constraints.maxHeight * 0.28).clamp(150.0, 200.0);
    } else if (isTablet && isLandscape) {
      dynamicSize = (constraints.maxHeight * 0.42).clamp(280.0, 340.0);
    } else if (isTablet) {
      dynamicSize = (constraints.maxHeight * 0.36).clamp(300.0, 350.0);
    } else {
      dynamicSize = (constraints.maxHeight * 0.3).clamp(240.0, 300.0);
    }

    const lottieScale = 1.334;
    final lottieSize = dynamicSize * lottieScale;
    final opticalYOffset = -dynamicSize * 0.172;

    return SizedBox(
      width: dynamicSize,
      height: dynamicSize,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, opticalYOffset),
            child: SizedBox(
              width: lottieSize,
              height: lottieSize,
              child: Lottie.asset(
                AppAssets.splashLottie,
                width: lottieSize,
                height: lottieSize,
                reverse: true,
                repeat: true,
                fit: BoxFit.contain,
                imageProviderFactory: (lottieImage) {
                  return const AssetImage(AppAssets.splashLogo);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BRAND TEXT LOCKUP (PULSING TITLE + TAGLINE WITH DYNAMIC TYPOGRAPHY)
// =============================================================================

class _BrandTextLockup extends StatelessWidget {
  final BoxConstraints constraints;

  const _BrandTextLockup({
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final titleToTaglineGap =
        context.isSmallPhone ? 4.0 : (context.isTablet ? 10.0 : 6.0);

    final titleStyle =
        context.titleHeaderStyle(constraints)?.copyWith(letterSpacing: -0.5);
    final tagLineStyle = context.buttonLabelStyle(constraints)?.copyWith(
        color: context.colorScheme.tertiary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500);

    return _PulsingWidget(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            context.l10n.appName,
            style: titleStyle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: titleToTaglineGap),
          Text(
            context.l10n.appTagline,
            style: tagLineStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

    _animation = Tween<double>(begin: 0.97, end: 1.03).animate(
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
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
