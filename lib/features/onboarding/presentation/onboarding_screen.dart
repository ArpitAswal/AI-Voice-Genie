import 'package:ai_voice_genie/features/auth/presentation/auth_provider.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/image_view.dart';

/// Onboarding screen shown to brand new users after first sign-in.
///
/// Gives a brief introduction to the app's core features.
/// Tapping "Get Started" routes to KeySetupScreen.
///
/// Note: Full animated onboarding UI is a polish task.
/// This screen fulfills the routing requirement for Phase 1/2.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 3;

  List<_OnboardingPageData> get _pages => [
        _OnboardingPageData(
            icon: Icons.chat_bubble_outline_rounded,
            titleKey: context.l10n.onboardTitle1,
            descKey: context.l10n.onboardDesc1,
            image: (context.isLight)
                ? AppAssets.lightFirstOnboard
                : AppAssets.darkFirstOnboard),
        _OnboardingPageData(
            icon: Icons.mic_rounded,
            titleKey: context.l10n.onboardTitle2,
            descKey: context.l10n.onboardDesc2,
            image: (context.isLight)
                ? AppAssets.lightSecondOnboard
                : AppAssets.darkSecondOnboard),
        _OnboardingPageData(
            icon: Icons.auto_awesome_rounded,
            titleKey: context.l10n.onboardTitle3,
            descKey: context.l10n.onboardDesc3,
            image: (context.isLight)
                ? AppAssets.lightThirdOnboard
                : AppAssets.darkThirdOnboard),
      ];

  void _handleNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: AppConstants.mediumDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _handleGetStarted();
    }
  }

  Future<void> _handleGetStarted() async {
    // Write onboardingDone = true to Firestore + Hive
    // This is non-blocking for the user — navigate immediately after

    await context.read<AuthProvider>().markBoardingComplete();

    if (!mounted) return;
    // Navigate to KeySetupScreen — back stack cleared so user cannot
    // press back to Onboarding

    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.keySetup);

  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Page View ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _totalPages,
                itemBuilder: (context, index) => Stack(
                  children: [
                    ImageView(
                      image: ImageViewData.asset(_pages[index].image),
                      width: context.screenWidth,
                      height: context.screenHeight,
                      filterQuality: FilterQuality.high,
                      fit: BoxFit.cover,
                    ),
                    Column(
                      children: [
                        _OnboardingPage(
                            data: _pages[index],
                            isTablet: isTablet,
                            navigate: _handleGetStarted),

                        const Spacer(),
                        // ── Page Indicators ──────────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _totalPages,
                            (index) => AnimatedContainer(
                              duration: AppConstants.shortDuration,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? AppColors.primaryLight
                                    : (context.isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 36 : 28),

                        // ── Next / Get Started Button ────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.horizontalPadding,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: isTablet ? 58 : 44,
                            child: ElevatedButton(
                              onPressed: _handleNext,
                              child: Text(
                                _currentPage == _totalPages - 1
                                    ? context.l10n.getStarted
                                    : context.l10n.next,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: context.bottomPadding + (isTablet ? 32 : 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ONBOARDING PAGE
// =============================================================================

class _OnboardingPageData {
  final IconData icon;
  final String titleKey;
  final String descKey;
  final String image;

  const _OnboardingPageData({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.image,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final bool isTablet;
  final void Function() navigate;

  const _OnboardingPage(
      {required this.data, required this.isTablet, required this.navigate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Skip button ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: navigate,
              child: Text(
                l10n.skip,
                style: context.textTheme.titleMedium,
              ),
            ),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          // ── Title ─────────────────────────────────────────────────────────
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: context.horizontalPadding * 2),
            child: Text(
              data.titleKey,
              style: context.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          // ── Description ───────────────────────────────────────────────────
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: context.horizontalPadding * 3),
            child: Text(
              data.descKey,
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
