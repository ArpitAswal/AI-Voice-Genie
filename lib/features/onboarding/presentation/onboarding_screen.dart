import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/widget_utils.dart';
import '../../../features/auth/presentation/auth_provider.dart';
import '../../../shared/model/image_model.dart';
import '../../../shared/widgets/image_view.dart';

/// Onboarding screen shown to brand new users after first sign-in.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);

  static const int _totalPages = 3;

  List<_OnboardingPageData> get _pages => [
        _OnboardingPageData(
          icon: Icons.chat_bubble_outline_rounded,
          titleKey: context.l10n.onboardTitle1,
          descKey: context.l10n.onboardDesc1,
          image: context.isLight
              ? AppAssets.lightFirstOnboard
              : AppAssets.darkFirstOnboard,
        ),
        _OnboardingPageData(
          icon: Icons.mic_rounded,
          titleKey: context.l10n.onboardTitle2,
          descKey: context.l10n.onboardDesc2,
          image: context.isLight
              ? AppAssets.lightSecondOnboard
              : AppAssets.darkSecondOnboard,
        ),
        _OnboardingPageData(
          icon: Icons.auto_awesome_rounded,
          titleKey: context.l10n.onboardTitle3,
          descKey: context.l10n.onboardDesc3,
          image: context.isLight
              ? AppAssets.lightThirdOnboard
              : AppAssets.darkThirdOnboard,
        ),
      ];

  void _onPageChanged(int index) {
    _currentPageNotifier.value = index;
  }

  void _handleNext() {
    final currentPage = _currentPageNotifier.value;
    if (currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: AppConstants.mediumDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _handleGetStarted();
    }
  }

  Future<void> _handleGetStarted() async {
    context.read<AuthProvider>().markBoardingComplete();

    if (!mounted) return;
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.keySetup);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  // ===========================================================================
  // REUSABLE SUB-WIDGETS & ACCESSIBILITY CONTROLS
  // ===========================================================================

  Widget _buildSkipButton(BuildContext context, [BoxConstraints? constraints]) {
    final l10n = context.l10n;
    final skipStyle = context.buttonLabelStyle(constraints);

    return Align(
      alignment: AlignmentGeometry.centerRight,
      child: ValueListenableBuilder<int>(
        valueListenable: _currentPageNotifier,
        builder: (context, currentPage, _) {
          final isLastPage = currentPage == _totalPages - 1;

          return AnimatedOpacity(
            duration: AppConstants.shortDuration,
            opacity: isLastPage ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: isLastPage,
              child: Semantics(
                button: true,
                label: l10n.skip,
                child: TextButton(
                  onPressed: _handleGetStarted,
                  child: Text(
                    l10n.skip,
                    style: skipStyle,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicators(
    BuildContext context, [
    BoxConstraints? constraints,
  ]) {
    final activeColor = context.colorScheme.primary;
    final inactiveColor = context.colorScheme.onSurface;

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isShort = (constraints?.maxHeight ?? size.height) <= 550 ||
        (constraints?.maxWidth ?? size.width) <= 360;
    final isTabletPortrait = !isLandscape &&
        (constraints?.maxWidth ?? size.width) >= 600 &&
        (constraints?.maxHeight ?? size.height) >= 750;

    // Adaptive indicator geometry:
    // - Tablet portrait: large prominent 10px indicators (32px active pill)
    // - Compact/phone: standard 8px indicators (24px active pill)
    // - Short landscape: compact 6px indicators (20px active pill) to save height
    final double indicatorHeight =
        isShort ? 6.0 : (isTabletPortrait ? 10.0 : 8.0);
    final double activeWidth =
        isShort ? 20.0 : (isTabletPortrait ? 32.0 : 24.0);
    final double inactiveWidth =
        isShort ? 6.0 : (isTabletPortrait ? 10.0 : 8.0);
    final double borderRadius = indicatorHeight / 2;

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageNotifier,
      builder: (context, currentPage, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _totalPages,
            (index) {
              final isSelected = currentPage == index;
              return Semantics(
                label: 'Page ${index + 1} of $_totalPages',
                selected: isSelected,
                button: true,
                child: GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: AppConstants.mediumDuration,
                      curve: Curves.easeInOut,
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44.0,
                      minHeight: 44.0,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: AppConstants.shortDuration,
                        width: isSelected ? activeWidth : inactiveWidth,
                        height: indicatorHeight,
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor : inactiveColor,
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    BoxConstraints? constraints,
  }) {
    final buttonStyle = context.buttonLabelStyle(constraints);

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageNotifier,
      builder: (context, currentPage, _) {
        final isLastPage = currentPage == _totalPages - 1;
        final label = isLastPage ? context.l10n.getStarted : context.l10n.next;

        return context.themedElevatedButton(
          label: label,
          textStyle: buttonStyle?.copyWith(color: Colors.white),
          onPressed: _handleNext,
        );
      },
    );
  }

  // ===========================================================================
  // BUILD METHOD & RESPONSIVE ROUTING
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final isLandscape = size.width > size.height;

          // 1. Tablet & Desktop layouts with orientation-specific composition
          if (size.width >= 600 && isLandscape) {
            return _buildSideBySideView(context, constraints);
          }

          // 2. Phone layouts with orientation-specific composition
          return _buildSingleView(context, constraints);
        },
      ),
    );
  }

  // ===========================================================================
  // 1. SINGLE/PORTRAIT LAYOUT (PHONE & TABLET PORTRAIT)
  // ===========================================================================

  Widget _buildSingleView(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final titleStyle = context.subHeaderStyle(constraints);
    final descStyle = context.descStyle(constraints);

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isShort = constraints.maxHeight <= 550 || constraints.maxWidth <= 360;
    final isTabletPortrait = !isLandscape &&
        constraints.maxWidth >= 600 &&
        constraints.maxHeight >= 750;

    // Clamped adaptive micro-spacings across form factors
    final double titleToDescGap =
        isShort ? 4.0 : (isTabletPortrait ? 10.0 : 8.0);
    final double indicatorToButtonGap =
        isShort ? 6.0 : (isTabletPortrait ? 20.0 : 10.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        width: context.screenWidth,
        height: context.screenHeight,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _totalPages,
          itemBuilder: (context, index) {
            final page = _pages[index];
            return Stack(
              children: [
                // Clean Hero Illustration Showcase
                Positioned.fill(
                  child: ImageView(
                    image: ImageViewData.asset(_pages[index].image),
                    width: context.screenWidth,
                    height: context.screenHeight,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            constraints.maxWidth >= 600 ? 550 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: context.viewPadding.top,
                          bottom: (context.viewPadding.bottom + 32.0)
                              .clamp(16.0, 32.0),
                          left: context.horizontalPadding,
                          right: context.horizontalPadding,
                        ),
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Top spacer reserving height for top navigation bar / Skip button
                                      SizedBox(
                                          height: context.viewPadding.top +
                                              (isTabletPortrait ? 36.0 : 12.0)),

                                      // Title
                                      Text(
                                        page.titleKey,
                                        style: titleStyle,
                                        textAlign: TextAlign.center,
                                      ),

                                      SizedBox(height: titleToDescGap),

                                      // Description
                                      Text(
                                        page.descKey,
                                        style: descStyle?.copyWith(
                                          color: context.colorScheme.tertiary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),

                                  // ── Bottom Controls (Indicators + Action Button) ────────────────
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildPageIndicators(
                                          context, constraints),
                                      SizedBox(height: indicatorToButtonGap),
                                      _buildActionButton(
                                        context,
                                        constraints: constraints,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Pinned Top-Right Skip Button (Viewport Edge) ───────────────
                Positioned(
                  top:
                      context.viewPadding.top + (isTabletPortrait ? 12.0 : 4.0),
                  right: context.horizontalPadding,
                  child: _buildSkipButton(context, constraints),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. SIDE-BY-SIDE LAYOUT (TABLET LANDSCAPE, DESKTOP & PHONE LANDSCAPE)
  // ===========================================================================

  Widget _buildSideBySideView(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final titleStyle = context.subHeaderStyle(constraints);
    final descStyle = context.descStyle(constraints);

    final isShort = constraints.maxHeight <= 550 || constraints.maxWidth <= 360;

    // Fluid, balanced vertical gaps for tablet canvas
    final double titleToDescGap = isShort ? 8.0 : 16.0;
    final double descToIndicatorsGap = isShort ? 16.0 : 36.0;
    final double indicatorsToButtonGap = isShort ? 12.0 : 22.0;

    return SafeArea(
      top: false,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          final page = _pages[index];
          return Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left Pane: Edge-to-Edge Hero Illustration ───────────────────
              Expanded(
                flex: 1,
                child: ImageView(
                  image: ImageViewData.asset(page.image),
                  width: context.screenWidth,
                  height: context.screenHeight,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.cover,
                ),
              ),

              // ── Right Pane: Integrated, Frameless Content Canvas ────────────
              Expanded(
                flex: 1,
                child: Stack(
                  children: [
                    // 1. Screen-Level Utility Action: Pinned Top-Right "Skip"
                    Positioned(
                      top: context.viewPadding.top + 16.0,
                      right: 28.0,
                      child: _buildSkipButton(context, constraints),
                    ),

                    // 2. Centered Content Block (Ergonomic Reading Flow)
                    Positioned.fill(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.horizontalPadding,
                            vertical: context.verticalSpacing,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title — prominent headline scaled for arm's length readability
                                Text(
                                  page.titleKey,
                                  style: titleStyle?.copyWith(
                                    fontSize: isShort ? 20.0 : 26.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: titleToDescGap),

                                // Description — generous line-height and readable font size
                                Text(
                                  page.descKey,
                                  style: descStyle?.copyWith(
                                    fontSize: isShort ? 12.0 : 15.0,
                                    color: context.isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary,
                                    height: 1.55,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: descToIndicatorsGap),

                                // Page Indicators (Interactive pills)
                                _buildPageIndicators(context, constraints),

                                SizedBox(height: indicatorsToButtonGap),

                                // Primary CTA Action Button — ergonomic width
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 380.0,
                                  ),
                                  child: _buildActionButton(
                                    context,
                                    constraints: constraints,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// ONBOARDING PAGE DATA MODEL
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
