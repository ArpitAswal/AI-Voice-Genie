import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/usage_summary_model.dart';
import 'usage_analytics_provider.dart';
import 'usage_provider.dart';
import 'widgets/feature_metric_breakdown.dart';
import 'widgets/model_distribution_chart.dart';
import 'widgets/usage_metric_cards.dart';
import 'widgets/usage_scope_header.dart';
import 'widgets/usage_trend_chart.dart';

/// Screen arguments passed when navigating to [UsageAnalyticsScreen].
class UsageAnalyticsArguments {
  /// Optional initial provider to pre-filter the dashboard upon opening.
  final AiProviderId? initialProvider;

  /// Optional billing month key to display (e.g. '2026-10').
  final String? initialMonthKey;

  const UsageAnalyticsArguments({
    this.initialProvider,
    this.initialMonthKey,
  });
}

/// Adaptive Usage Analytics & Telemetry Screen for Mobile & Tablet.
///
/// Implements the Stitch design specifications ("Usage Analytics - Mobile & Tablet")
/// grounded 100% in real Firestore `usageSummaries` and `usageEvents` data.
///
/// Layout Architecture:
/// - **Mobile (< 840dp width)**: Single-column scroll with [RefreshIndicator] for pull-to-refresh,
///   KPI metric cards, vector Bezier trend chart, donut distribution, feature breakdown, and provider status.
/// - **Tablet / Desktop (>= 840dp width)**: 2-column split-grid dashboard:
///   - Left pane (38% width): Donut model distribution, feature metric grid, provider topologies.
///   - Right pane (62% width): Month & filter scope controls, 4 KPI cards, full-width trend graph.
///
/// State & Caching:
/// - Leverages [UsageAnalyticsProvider] for monthly partitioned Firestore queries and
///   in-memory client-side filtering without extra read billing.
class UsageAnalyticsScreen extends StatefulWidget {
  final AiProviderId? initialProvider;
  final String? initialMonthKey;

  const UsageAnalyticsScreen({
    super.key,
    this.initialProvider,
    this.initialMonthKey,
  });

  @override
  State<UsageAnalyticsScreen> createState() => _UsageAnalyticsScreenState();
}

class _UsageAnalyticsScreenState extends State<UsageAnalyticsScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Schedule post-frame initialization to load monthly events from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAnalytics();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Initializes provider filters and queries Firestore for the selected month.
  Future<void> _initAnalytics() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final analyticsProv = context.read<UsageAnalyticsProvider>();

    // Apply pre-filter if supplied in navigation arguments
    if (widget.initialProvider != null) {
      analyticsProv.setProviderFilter(widget.initialProvider);
    }

    final targetMonth =
        widget.initialMonthKey ?? analyticsProv.selectedMonthKey;
    final isCached = analyticsProv.isMonthCached(targetMonth);

    if (!isCached && mounted) {
      LoadingOverlay.show(context, message: 'Loading usage data...');
    }

    try {
      // Trigger cached/network query for the month
      await analyticsProv.loadEvents(
        uid,
        monthKey: widget.initialMonthKey,
      );

      // Also ensure high-level summary budgets are loaded in UsageProvider
      if (mounted) {
        await context
            .read<UsageProvider>()
            .loadForMonth(uid, monthKey: widget.initialMonthKey);
      }
    } finally {
      if (!isCached) {
        LoadingOverlay.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final theme = context.theme;
    final uid =
        context.select<AuthProvider, String?>((p) => p.currentUser?.uid);

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.l10n.usageAnalytics,
          style: (context.isCompact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge)
              ?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Consumer<UsageAnalyticsProvider>(
          builder: (context, provider, _) {
            // 1. Full-Screen Error State with Retry CTA
            if (provider.error != null && provider.currentMonthEvents.isEmpty) {
              return _buildErrorState(context, provider, uid);
            }

            // 2. Render Responsive Layout across M3 Window Size Classes
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                // Landscape Phone Guard: treat short heights (<= 550dp) strictly as Compact
                final bool isShortHeight = height <= 550.0;

                if (width < 600.0 || isShortHeight) {
                  // 1. Compact / Short-Height (Mobile Portrait & Landscape Phones):
                  // 3-page horizontal swipe via NestedScrollView + PageView.builder(itemCount: 3)
                  return _buildMobileDashboard(context, provider, uid);
                } else if (width < 840.0) {
                  // 2. Medium Viewport (Tablet Portrait / Foldables 600dp - 839dp):
                  // Single unified scrollable executive dashboard
                  return _buildMediumTabletDashboard(
                      context, provider, uid, constraints);
                } else {
                  // 3. Expanded Viewport (Tablet Landscape / Desktop >= 840dp):
                  // 2-Pane split dashboard (38% left pane, 62% right pane)
                  return _buildExpandedDashboard(
                      context, provider, uid, constraints);
                }
              },
            );
          },
        ),
      ),
    );
  }

  // ── Mobile Layout (< 840dp) ────────────────────────────────────────────────

  /// 3-Page horizontal swipe layout with pinned top controls and zero blank void space.
  Widget _buildMobileDashboard(
    BuildContext context,
    UsageAnalyticsProvider provider,
    String? uid,
  ) {
    final l10n = context.l10n;
    final analytics = provider.analytics;
    final activeSummary = _resolveSummary(context, provider.selectedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (uid != null) {
          await provider.refresh(uid);
          if (context.mounted) {
            await context.read<UsageProvider>().loadForMonth(uid);
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Month Picker & Filter Controls (Pinned at top for instant filtering & no disappearing controls)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                UsageScopeHeader(provider: provider, uid: uid),
                const SizedBox(height: 24.0),

                // 2. Section Title and 3-Dash Progress Indicator (No switcher button, no dots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getPageTitle(_currentPage, l10n),
                        style: (context.isCompact
                                ? context.textTheme.titleMedium
                                : context.textTheme.titleLarge)
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isActive ? 26.0 : 12.0,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isActive
                                ? context.colorScheme.tertiary
                                : context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Responsive PageView: fills remaining screen height without artificial void space
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: 3,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    // Page 0: KPI Scoreboard & Model Distribution Donut
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsageMetricCards(
                            data: analytics,
                            activeSummary: activeSummary,
                            isTablet: false,
                          ),
                          const SizedBox(height: 14.0),
                          ModelDistributionChart(
                            data: provider.overallMonthData,
                            selectedProvider: provider.selectedProvider,
                            onProviderSelected: provider.setProviderFilter,
                          ),
                          SizedBox(height: context.viewPadding.bottom),
                        ],
                      ),
                    );

                  case 1:
                    // Page 1: Daily Activity Trends Chart
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UsageTrendChart(
                            data: provider.modelTrendData,
                            isTablet: false,
                          ),
                          SizedBox(height: context.viewPadding.bottom),
                        ],
                      ),
                    );

                  case 2:
                  default:
                    // Page 2: Feature & Modality Breakdown List
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FeatureMetricBreakdown(
                            data: provider.modelTrendData,
                            isTablet: false,
                          ),
                          SizedBox(height: context.viewPadding.bottom + 16.0),
                        ],
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Returns localized section title with page index for the mobile indicator.
  String _getPageTitle(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.overViewModels;
      case 1:
        return l10n.dailyActivityTrends;
      case 2:
      default:
        return l10n.featureModalityBreakdown;
    }
  }

  // ── Medium Layout (Tablet Portrait 600dp - 839dp) ──────────────────────────

  /// Single unified scrollable executive dashboard for tablet portrait viewports.
  Widget _buildMediumTabletDashboard(
    BuildContext context,
    UsageAnalyticsProvider provider,
    String? uid,
    BoxConstraints constraints,
  ) {
    final analytics = provider.analytics;
    final activeSummary = _resolveSummary(context, provider.selectedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (uid != null) {
          await provider.refresh(uid);
          if (context.mounted) {
            await context.read<UsageProvider>().loadForMonth(uid);
          }
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
          vertical: context.verticalSpacing,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Month Picker & Filter Controls
                UsageScopeHeader(provider: provider, uid: uid),
                const SizedBox(height: 24.0),

                // 2. High-Level KPI Summary Cards (1x4 horizontal row on tablet)
                UsageMetricCards(
                  data: analytics,
                  activeSummary: activeSummary,
                  isTablet: true,
                ),

                const SizedBox(height: 24.0),

                // 3. Full-Width Daily Activity Trend Chart, Model Distribution & Feature Modality Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ModelDistributionChart(
                          data: provider.overallMonthData,
                          selectedProvider: provider.selectedProvider,
                          onProviderSelected: provider.setProviderFilter,
                        ),
                        const SizedBox(height: 24.0),
                        UsageTrendChart(
                          data: provider.modelTrendData,
                          isTablet: true,
                        ),
                      ],
                    )),
                    const SizedBox(width: 24.0),
                    Expanded(
                      child: FeatureMetricBreakdown(
                        data: provider.modelTrendData,
                        isTablet: true,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.viewPadding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Expanded Layout (Tablet Landscape / Desktop >= 840dp) ──────────────────

  /// Two-column split-grid dashboard layout for desktop and wide screens.
  Widget _buildExpandedDashboard(
    BuildContext context,
    UsageAnalyticsProvider provider,
    String? uid,
    BoxConstraints constraints,
  ) {
    final analytics = provider.analytics;
    final activeSummary = _resolveSummary(context, provider.selectedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (uid != null) {
          await provider.refresh(uid);
          if (context.mounted) {
            await context.read<UsageProvider>().loadForMonth(uid);
          }
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.isExpanded ? 32.0 : 24.0,
          vertical: 20.0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Pane (38% width): Distribution & Modality Breakdown
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Model Distribution Donut (Fixed to overall monthly baseline)
                      ModelDistributionChart(
                        data: provider.overallMonthData,
                        selectedProvider: provider.selectedProvider,
                        onProviderSelected: provider.setProviderFilter,
                      ),
                      const SizedBox(height: 20.0),

                      // Feature & Metric Breakdown (Model-specific, modality-agnostic)
                      FeatureMetricBreakdown(
                        data: provider.modelTrendData,
                        isTablet: true,
                      ),
                      SizedBox(height: context.viewPadding.bottom + 24.0),
                    ],
                  ),
                ),
                const SizedBox(width: 24.0),

                // Right Pane (62% width): Scope Controls, KPI Row, Trend Chart
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month Picker & Filter Controls
                      UsageScopeHeader(provider: provider, uid: uid),
                      const SizedBox(height: 18.0),

                      // High-Level KPI Summary Cards (1x4 Row on tablet/desktop)
                      UsageMetricCards(
                        data: analytics,
                        activeSummary: activeSummary,
                        isTablet: true,
                      ),
                      const SizedBox(height: 20.0),

                      // Large Interactive Trend Chart (Model-specific, modality-agnostic)
                      UsageTrendChart(
                        data: provider.modelTrendData,
                        isTablet: true,
                      ),
                      SizedBox(height: context.viewPadding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Supporting States & Helpers ────────────────────────────────────────────

  /// Full-screen error state with retry action.
  Widget _buildErrorState(
    BuildContext context,
    UsageAnalyticsProvider provider,
    String? uid,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: context.isCompact ? 32 : 48.0,
              color:
                  context.isDark ? AppColors.darkError : AppColors.lightError,
            ),
            const SizedBox(height: 12.0),
            Text(context.l10n.usageLoadFailed,
                style: (context.isCompact
                        ? context.textTheme.titleMedium
                        : context.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4.0),
            Text(
              provider.error ??
                  'A network error occurred while querying events.',
              textAlign: TextAlign.center,
              style: (context.isCompact
                      ? context.textTheme.bodyMedium
                      : context.textTheme.bodyLarge)
                  ?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.theme.colorScheme.tertiary),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: uid == null ? null : () => provider.refresh(uid),
              icon: const Icon(Icons.refresh_rounded, size: 18.0),
              label: Text(context.l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves the corresponding provider summary model from [UsageProvider]
  /// if a single provider is selected, or null if all models are displayed.
  UsageSummaryModel? _resolveSummary(
    BuildContext context,
    AiProviderId? selectedProvider,
  ) {
    if (selectedProvider == null) return null;
    return context.read<UsageProvider>().summaryFor(selectedProvider);
  }
}
