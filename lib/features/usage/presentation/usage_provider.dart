import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../domain/usage_repository.dart';
import '../data/usage_repository_impl.dart';
import '../domain/usage_budget_model.dart';
import '../domain/usage_event_model.dart';
import '../domain/usage_summary_model.dart';

/// ChangeNotifier for AI usage tracking data shown in the Profile screen.
///
/// Loads monthly summaries and budgets for all 3 providers from Firestore.
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

  /// Budgets indexed by provider
  final Map<AiProviderId, UsageBudgetModel> _budgets = {};

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
  UsageBudgetModel? budgetFor(AiProviderId provider) => _budgets[provider];

  /// Estimated spend for a provider this month
  double spendFor(AiProviderId provider) =>
      _summaries[provider]?.estimatedCostUsd ?? 0.0;

  /// Budget amount for a provider (null = not set)
  double? budgetAmountFor(AiProviderId provider) =>
      _budgets[provider]?.monthlyBudgetUsd;

  /// True if any provider has usage data this month
  bool get hasAnyUsage => _summaries.values.any((s) => s.hasActivity);

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Load all summaries and budgets for the current month.
  ///
  /// Safe to call multiple times — re-loading will refresh data from Firestore.
  Future<void> loadForMonth(String uid, {String? monthKey}) async {
    _isLoading = true;
    _error = null;
    _currentMonthKey = monthKey ?? UsageEventModel.currentMonthKey;
    notifyListeners();

    try {
      // 1. Start listening to summaries in real-time
      _summarySub?.cancel();
      _summarySub = _repo
          .watchAllSummaries(uid: uid, monthKey: _currentMonthKey)
          .listen((summaries) {
        _summaries.clear();
        for (final s in summaries) {
          _summaries[s.provider] = s;
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('⚠️ UsageProvider stream error: $e');
      });

      // 2. Load budgets once (they are rarely updated and updated locally)
      final budgetFutures = await Future.wait([
        ...AiProviderId.values
            .map((p) => _repo.getBudget(uid: uid, provider: p)),
      ]);

      for (int i = 0; i < AiProviderId.values.length; i++) {
        final budget = budgetFutures[i];
        if (budget != null) {
          _budgets[AiProviderId.values[i]] = budget;
        } else {
          _budgets.remove(AiProviderId.values[i]);
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ UsageProvider.loadForMonth failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Budget CRUD ────────────────────────────────────────────────────────────

  /// Set or update a monthly budget for a provider.
  Future<void> setBudget({
    required String uid,
    required AiProviderId provider,
    required double amountUsd,
  }) async {
    final budget = UsageBudgetModel(
      provider: provider,
      monthlyBudgetUsd: amountUsd,
      enabled: true,
    );

    try {
      await _repo.saveBudget(uid: uid, budget: budget);
      _budgets[provider] = budget;
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
      await _repo.deleteBudget(uid: uid, provider: provider);
      _budgets.remove(provider);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ removeBudget failed: $e');
      rethrow;
    }
  }
}
