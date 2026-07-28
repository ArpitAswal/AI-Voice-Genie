import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../domain/usage_repository.dart';
import '../data/usage_repository_impl.dart';
import '../domain/usage_event_model.dart';
import '../domain/usage_summary_model.dart';

/// ChangeNotifier for AI usage tracking data shown in the Profile screen.
///
/// Loads the unified profiles (summaries + budget settings) for all providers.
/// Must be provided at the profile screen level.
class UsageProvider extends ChangeNotifier {
  final UsageRepository _repo;

  UsageProvider({UsageRepository? repo})
      : _repo = repo ?? UsageRepositoryImpl();

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _error;
  String _currentMonthKey = UsageEventModel.currentMonthKey;

  /// Usage summaries indexed by provider
  final Map<AiProviderId, UsageSummaryModel> _summaries = {};

  StreamSubscription<List<UsageSummaryModel>>? _summarySub;

  @override
  void dispose() {
    _summarySub?.cancel();
    super.dispose();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentMonthKey => _currentMonthKey;

  UsageSummaryModel? summaryFor(AiProviderId provider) => _summaries[provider];

  /// Estimated lifetime spend for a provider
  double lifetimeSpendFor(AiProviderId provider) =>
      _summaries[provider]?.lifetimeSpend() ?? 0.0;

  /// Estimated current month spend for a provider
  double currentMonthSpendFor(AiProviderId provider) =>
      _summaries[provider]?.getMonth(_currentMonthKey).estimatedCostUsd ?? 0.0;

  /// Budget amount for a provider (null = not set)
  double? totalBudgetFor(AiProviderId provider) =>
      _summaries[provider]?.totalBudgetUsd;

  /// True if any provider has usage data
  bool get hasAnyUsage => _summaries.values.any((s) => s.hasAnyActivity);

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Load all summaries.
  ///
  /// Safe to call multiple times — re-loading will refresh data from Firestore.
  Future<void> loadForMonth(String uid, {String? monthKey}) async {
    _isLoading = true;
    _error = null;
    _currentMonthKey = monthKey ?? UsageEventModel.currentMonthKey;
    notifyListeners();

    try {
      // 1. Start listening to unified summaries in real-time
      _summarySub?.cancel();
      _summarySub = _repo.watchAllSummaries(uid: uid).listen((summaries) {
        _summaries.clear();
        for (final s in summaries) {
          _summaries[s.provider] = s;
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint(
            '⚠️ UsageProvider stream error (ignored during logout/deletion): $e');
      });
    } catch (e) {
      // Store the localization key, not the translated string, so the UI can
      // render the correct language at display time (agent rule: no hardcoded strings).
      _error = 'usage_load_failed';
      debugPrint('⚠️ UsageProvider load error: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Budget CRUD ────────────────────────────────────────────────────────────

  /// Set or update a total budget for a provider.
  Future<void> setBudget({
    required String uid,
    required AiProviderId provider,
    required double amountUsd,
    double? alreadyUsedUsd,
  }) async {
    // We update the existing model or create a new one
    final existing =
        _summaries[provider] ?? UsageSummaryModel(provider: provider);

    final updated = UsageSummaryModel(
      provider: provider,
      enabled: true,
      totalBudgetUsd: amountUsd,
      alreadyUsedUsd: alreadyUsedUsd,
      monthlyData: existing.monthlyData,
      updatedAt: DateTime.now(),
    );

    try {
      await _repo.updateGlobalSettings(uid: uid, model: updated);
      _summaries[provider] = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ setBudget failed: $e');
      rethrow;
    }
  }

  /// Remove a provider's budget.
  Future<void> removeBudget({
    required String uid,
    required AiProviderId provider,
  }) async {
    try {
      await _repo.disableBudget(uid: uid, provider: provider);

      final existing = _summaries[provider];
      if (existing != null) {
        _summaries[provider] = UsageSummaryModel(
          provider: provider,
          enabled: false,
          totalBudgetUsd: null,
          alreadyUsedUsd: existing.alreadyUsedUsd, // keep usage intact
          monthlyData: existing.monthlyData,
          updatedAt: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ removeBudget failed: $e');
      rethrow;
    }
  }
}
