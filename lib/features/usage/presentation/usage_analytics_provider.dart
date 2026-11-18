import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../data/usage_repository_impl.dart';
import '../domain/usage_analytics_data.dart';
import '../domain/usage_event_model.dart';
import '../domain/usage_repository.dart';
import '../domain/usage_summary_model.dart';
import 'usage_provider.dart';

/// State management provider for the Usage Analytics & Telemetry Screen.
///
/// Encapsulates:
/// 1. Asynchronous fetching and in-memory caching of monthly [UsageEventModel] records.
/// 2. Instantaneous client-side filtering by [AiProviderId] and [AiCapability] without touching the database.
/// 3. Dynamic time-series aggregation for line/bar trend charts and donut distribution charts.
/// 4. Coordination with [UsageProvider] for high-level summary budgets and monthly spend ceilings.
class UsageAnalyticsProvider extends ChangeNotifier {
  final UsageRepository _repository;

  UsageAnalyticsProvider({UsageRepository? repository})
      : _repository = repository ?? UsageRepositoryImpl();

  // ── State Fields ───────────────────────────────────────────────────────────

  /// The active billing month key being analyzed in 'YYYY-MM' format (e.g., '2026-10').
  String _selectedMonthKey = UsageEventModel.currentMonthKey;

  /// Optional active filter for AI Provider (null represents 'All Models').
  AiProviderId? _selectedProvider;

  /// Optional active filter for modality capability (null represents 'All Capabilities').
  AiCapability? _selectedCapability;

  /// Metric currently toggled on the trajectory trend chart: 'tokens' or 'requests'.
  String _activeChartMetric = 'tokens';

  /// Whether telemetry events are currently being fetched from Firestore.
  bool _isLoading = false;

  /// Human-readable error message, if a network query fails.
  String? _error;

  /// Process-wide in-memory cache of raw usage events indexed by monthKey.
  ///
  /// Prevents redundant Firestore queries and saves read quotas when the user
  /// toggles back and forth between different months during the same app session.
  final Map<String, List<UsageEventModel>> _monthEventsCache = {};

  /// Tracks the last UID loaded to prevent cross-user data contamination.
  String? _currentUid;

  // ── Getters ────────────────────────────────────────────────────────────────

  String get selectedMonthKey => _selectedMonthKey;
  AiProviderId? get selectedProvider => _selectedProvider;
  AiCapability? get selectedCapability => _selectedCapability;
  String get activeChartMetric => _activeChartMetric;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns whether a specific month has already been loaded into in-memory cache.
  bool isMonthCached(String monthKey) => _monthEventsCache.containsKey(monthKey);

  /// Returns the cached events list for the currently selected month.
  List<UsageEventModel> get currentMonthEvents =>
      _monthEventsCache[_selectedMonthKey] ?? const [];

  /// Dynamically computes the filtered analytics data (time-series points, peak day,
  /// distribution percentages, and input/output ratios) 100% in-memory.
  UsageAnalyticsData get analytics {
    final rawEvents = currentMonthEvents;
    final activeSummary = _resolveActiveSummary();

    return UsageAnalyticsData.compute(
      events: rawEvents,
      monthKey: _selectedMonthKey,
      providerFilter: _selectedProvider,
      capabilityFilter: _selectedCapability,
      summary: activeSummary,
    );
  }

  /// Trend-specific analytics data that filters by [AiProviderId] but stays agnostic
  /// to modality/capability filters, ensuring stable time-series timelines for each model.
  UsageAnalyticsData get modelTrendData {
    final rawEvents = currentMonthEvents;
    final activeSummary = _resolveActiveSummary();

    return UsageAnalyticsData.compute(
      events: rawEvents,
      monthKey: _selectedMonthKey,
      providerFilter: _selectedProvider,
      capabilityFilter: null,
      summary: activeSummary,
    );
  }

  /// Unfiltered monthly baseline data spanning all providers and modalities for the selected month.
  ///
  /// Feeds macro-level distribution charts (e.g. [ModelDistributionChart]) so they remain
  /// a stable benchmark of overall monthly AI workload regardless of active drill-down filters.
  UsageAnalyticsData get overallMonthData {
    final rawEvents = currentMonthEvents;
    final activeSummary = _resolveActiveSummary();

    return UsageAnalyticsData.compute(
      events: rawEvents,
      monthKey: _selectedMonthKey,
      providerFilter: null,
      capabilityFilter: null,
      summary: activeSummary,
    );
  }

  /// Returns a sorted list of unique billing month keys ('YYYY-MM') available
  /// for selection, generated from recorded summary history and current calendar month.
  List<String> get availableMonths {
    final Set<String> months = {
      _selectedMonthKey,
      UsageEventModel.currentMonthKey
    };

    // Incorporate months discovered in summaries
    final usageProvider = UsageProvider.instance;
    if (usageProvider != null) {
      for (final provider in AiProviderId.values) {
        final summary = usageProvider.summaryFor(provider);
        if (summary != null) {
          months.addAll(summary.monthlyData.keys);
        }
      }
    }

    final sorted = months.toList();
    // Sort descending: newest month at index 0 (e.g. Oct 2026, Sep 2026, Aug 2026)
    sorted.sort((a, b) => b.compareTo(a));
    return sorted;
  }

  // ── Actions & Methods ──────────────────────────────────────────────────────

  /// Loads usage events for a specific user and month key.
  ///
  /// Uses an in-memory cache-first strategy:
  /// - If events for [monthKey] are already cached and [forceRefresh] is false,
  ///   immediately uses the cache with zero Firestore network calls.
  /// - Otherwise, queries `usageEvents` partitioned by `monthKey` from Firestore.
  Future<void> loadEvents(
    String uid, {
    String? monthKey,
    bool forceRefresh = false,
  }) async {
    final targetMonth = monthKey ?? _selectedMonthKey;
    _selectedMonthKey = targetMonth;

    // Reset cache if authenticated user switched
    if (_currentUid != null && _currentUid != uid) {
      _monthEventsCache.clear();
    }
    _currentUid = uid;

    // 1. Return early from cache if available and not forcing refresh
    if (!forceRefresh && _monthEventsCache.containsKey(targetMonth)) {
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    // 2. Fetch from Firestore
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final events = await _repository.getEventsForMonth(
        uid: uid,
        monthKey: targetMonth,
      );

      _monthEventsCache[targetMonth] = events;
      _error = null;
    } catch (e) {
      _error = 'Failed to load usage events';
      debugPrint('⚠️ UsageAnalyticsProvider.loadEvents failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches the active month view and triggers loading for that month's events.
  void selectMonth(String uid, String monthKey) {
    if (_selectedMonthKey == monthKey &&
        _monthEventsCache.containsKey(monthKey)) {
      return;
    }
    loadEvents(uid, monthKey: monthKey);
  }

  /// Updates the provider filter in-memory (e.g. 'All Models', 'Gemini', 'ChatGPT', 'Claude').
  void setProviderFilter(AiProviderId? provider) {
    if (_selectedProvider == provider) return;
    _selectedProvider = provider;
    notifyListeners();
  }

  /// Updates the capability filter in-memory (e.g. 'All', 'PDF', 'Image', 'Text').
  void setCapabilityFilter(AiCapability? capability) {
    if (_selectedCapability == capability) return;
    _selectedCapability = capability;
    notifyListeners();
  }

  /// Toggles the metric plotted on the trajectory chart between 'tokens' and 'requests'.
  void setChartMetric(String metric) {
    if (_activeChartMetric == metric) return;
    _activeChartMetric = metric;
    notifyListeners();
  }

  /// Clears in-memory cache and reloads the current month from Firestore (Pull-to-Refresh).
  Future<void> refresh(String uid) async {
    await loadEvents(uid, monthKey: _selectedMonthKey, forceRefresh: true);
  }

  /// Clears all local state and caches (called on logout/account switch).
  void clear() {
    _monthEventsCache.clear();
    _selectedProvider = null;
    _selectedCapability = null;
    _selectedMonthKey = UsageEventModel.currentMonthKey;
    _activeChartMetric = 'tokens';
    _isLoading = false;
    _error = null;
    _currentUid = null;
    notifyListeners();
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  /// Resolves the corresponding provider summary from [UsageProvider] if a single
  /// provider filter is active.
  UsageSummaryModel? _resolveActiveSummary() {
    final prov = _selectedProvider;
    if (prov == null) return null;
    return UsageProvider.instance?.summaryFor(prov);
  }
}
