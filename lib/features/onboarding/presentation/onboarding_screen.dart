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
          titleKey: context.l10n.onboardTitle1,
          descKey: context.l10n.onboardDesc1,
          image: context.isLight
              ? AppAssets.lightFirstOnboard
              : AppAssets.darkFirstOnboard,
        ),
        _OnboardingPageData(
          titleKey: context.l10n.onboardTitle2,
          descKey: context.l10n.onboardDesc2,
          image: context.isLight
              ? AppAssets.lightSecondOnboard
              : AppAssets.darkSecondOnboard,
        ),
        _OnboardingPageData(
          titleKey: context.l10n.onboardTitle3,
          descKey: context.l10n.onboardDesc3,
          image: context.isLight
              ? AppAssets.lightThirdOnboard
              : AppAssets.darkThirdOnboard,
        ),
      ];

  void _onPageChanged(int index) => _currentPageNotifier.value = index;

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

  // ── Reusable Sub-Widgets ───────────────────────────────────────────────────

  /// Builds accessible "Skip" button adhering to WCAG 48×48dp minimum touch bounds.
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
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48.0, 48.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                    ),
                    onPressed: _handleGetStarted,
                    child: Text(
                      l10n.skip,
                      style: skipStyle,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds responsive page indicator dots with accessible hitboxes (>= 48x48dp).
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
                      minWidth: 48.0,
                      minHeight: 48.0,
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

  /// Builds primary action CTA button with minimum 48dp touch height.
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

  /// Builds high-fidelity hero image for onboarding slide.
  Widget _buildHeroImage(String image) {
    return ImageView(
      image: ImageViewData.asset(image),
      width: context.screenWidth,
      height: context.screenHeight,
      filterQuality: FilterQuality.high,
      fit: BoxFit.cover,
    );
  }

  // ── Build Method & Layout Dispatcher ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Material 3 Responsive layout switching:
            // Side-by-side mode activated on Expanded viewports (width >= 840dp)
            final isExpanded = constraints.maxWidth >= 840.0;

            return PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _totalPages,
              itemBuilder: (context, index) {
                final page = _pages[index];
                return isExpanded
                    ? _buildSideBySidePage(context, constraints, page)
                    : _buildSinglePage(context, constraints, page);
              },
            );
          },
        ),
      ),
    );
  }

  // ── Single / Portrait Layout (Phone & Tablet Portrait) ─────────────────────

  Widget _buildSinglePage(
    BuildContext context,
    BoxConstraints constraints,
    _OnboardingPageData page,
  ) {
    final titleStyle = context.subHeaderStyle(constraints);
    final descStyle = context.descStyle(constraints);

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isShort = constraints.maxHeight <= 550 || constraints.maxWidth <= 360;
    final isTabletPortrait = !isLandscape &&
        constraints.maxWidth >= 600 &&
        constraints.maxHeight >= 750;

    final double titleToDescGap =
        isShort ? 4.0 : (isTabletPortrait ? 10.0 : 8.0);
    final double indicatorToButtonGap =
        isShort ? 6.0 : (isTabletPortrait ? 20.0 : 10.0);

    return Stack(
      children: [
        Positioned.fill(child: _buildHeroImage(page.image)),
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 600 ? 550 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.viewPadding.top,
                  bottom: (context.viewPadding.bottom + 32.0).clamp(16.0, 32.0),
                  left: context.horizontalPadding,
                  right: context.horizontalPadding,
                ),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: context.viewPadding.top +
                                    (isTabletPortrait ? 36.0 : 12.0),
                              ),
                              Text(
                                page.titleKey,
                                style: titleStyle,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: titleToDescGap),
                              Text(
                                page.descKey,
                                style: descStyle?.copyWith(
                                  color: context.colorScheme.tertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPageIndicators(context, constraints),
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
        Positioned(
          top: context.viewPadding.top + (isTabletPortrait ? 12.0 : 4.0),
          right: context.horizontalPadding,
          child: _buildSkipButton(context, constraints),
        ),
      ],
    );
  }

  // ── Side-By-Side Layout (Tablet Landscape & Desktop) ───────────────────────

  Widget _buildSideBySidePage(
    BuildContext context,
    BoxConstraints constraints,
    _OnboardingPageData page,
  ) {
    final titleStyle = context.subHeaderStyle(constraints);
    final descStyle = context.descStyle(constraints);
    final isShort = constraints.maxHeight <= 550 || constraints.maxWidth <= 360;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildHeroImage(page.image)),
        Expanded(
          child: Stack(
            children: [
              Positioned(
                top: context.viewPadding.top + 16.0,
                right: 28.0,
                child: _buildSkipButton(context, constraints),
              ),
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
                        children: [
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
                          SizedBox(height: isShort ? 8.0 : 16.0),
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
                          SizedBox(height: isShort ? 16.0 : 36.0),
                          _buildPageIndicators(context, constraints),
                          SizedBox(height: isShort ? 12.0 : 22.0),
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
  }
}

// ── Onboarding Page Data Model ───────────────────────────────────────────────

class _OnboardingPageData {
  final String titleKey;
  final String descKey;
  final String image;

  const _OnboardingPageData({
    required this.titleKey,
    required this.descKey,
    required this.image,
  });
}
