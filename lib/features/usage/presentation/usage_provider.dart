import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/enums/app_enums.dart';
import '../../key_setup/data/api_key_repository_impl.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../domain/usage_repository.dart';
import '../data/usage_repository_impl.dart';
import '../domain/usage_event_model.dart';
import '../domain/usage_summary_model.dart';

/// ChangeNotifier for AI usage tracking data shown in the Profile screen.
///
/// Loads the unified profiles (summaries + budget settings) for all providers.
/// Must be provided at the profile screen level.
class UsageProvider extends ChangeNotifier {
  static UsageProvider? _instance;
  static UsageProvider? get instance => _instance;

  final UsageRepository _repo;

  UsageProvider({UsageRepository? repo})
      : _repo = repo ?? UsageRepositoryImpl() {
    _instance = this;
  }

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _error;
  String _currentMonthKey = UsageEventModel.currentMonthKey;

  /// Usage summaries indexed by provider (mapped to the active key for that provider)
  final Map<AiProviderId, UsageSummaryModel> _summaries = {};

  /// All usage summary documents from Firestore indexed by document ID
  final Map<String, UsageSummaryModel> _summariesByDocId = {};

  StreamSubscription<List<UsageSummaryModel>>? _summarySub;
  String? _activeUid;

  @override
  void dispose() {
    _summarySub?.cancel();
    _summarySub = null;
    _activeUid = null;
    super.dispose();
  }

  /// Clear in-memory summaries and cancel active Firestore stream subscription.
  void clear() {
    _summarySub?.cancel();
    _summarySub = null;
    _activeUid = null;
    _summaries.clear();
    _summariesByDocId.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentMonthKey => _currentMonthKey;

  /// Returns the active usage summary for the given provider.
  UsageSummaryModel? summaryFor(AiProviderId provider) {
    final activeKey = ApiKeyProvider.instance?.apiKeyFor(provider) ??
        ApiKeyRepositoryImpl.getCachedKey(provider);
    final activeHint = (activeKey != null && activeKey.apiKey.isNotEmpty)
        ? activeKey.keyHint
        : null;

    if (activeHint != null) {
      final expectedDocId = '${provider.id}_$activeHint';
      final current = _summaries[provider];
      if (current?.docId != expectedDocId &&
          _summariesByDocId.containsKey(expectedDocId)) {
        _summaries[provider] = _summariesByDocId[expectedDocId]!;
      }
    }

    return _summaries[provider];
  }

  /// Estimated lifetime spend for a provider
  double lifetimeSpendFor(AiProviderId provider) =>
      summaryFor(provider)?.lifetimeSpend() ?? 0.0;

  /// Estimated current month spend for a provider
  double currentMonthSpendFor(AiProviderId provider) =>
      summaryFor(provider)?.getMonth(_currentMonthKey).estimatedCostUsd ?? 0.0;

  /// Budget amount for a provider (null = not set)
  double? totalBudgetFor(AiProviderId provider) =>
      summaryFor(provider)?.totalBudgetUsd;

  /// True if any provider has usage data
  bool get hasAnyUsage => _summaries.values.any((s) => s.hasAnyActivity);

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Load all summaries.
  ///
  /// Safe to call multiple times — skips redundant setup if already watching for the same uid.
  Future<void> loadForMonth(String uid,
      {String? monthKey, bool force = false}) async {
    if (!force && _activeUid == uid && _summarySub != null) return;
    _activeUid = uid;
    _isLoading = true;
    _error = null;
    _currentMonthKey = monthKey ?? UsageEventModel.currentMonthKey;
    notifyListeners();

    try {
      // 1. Start listening to unified summaries in real-time
      _summarySub?.cancel();
      _summarySub = _repo.watchAllSummaries(uid: uid).listen((summaries) {
        _summariesByDocId.clear();
        for (final s in summaries) {
          _summariesByDocId[s.docId] = s;
        }
        _recomputeActiveSummaries();
        notifyListeners();
      }, onError: (e) {
        debugPrint(
            '⚠️ UsageProvider stream error (ignored during logout/deletion): $e');
      });
    } catch (e) {
      _error = 'usage_load_failed';
      debugPrint('⚠️ UsageProvider load error: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resolves the correct active summary document per provider.
  void _recomputeActiveSummaries() {
    _summaries.clear();
    for (final provider in AiProviderId.values) {
      final activeKey = ApiKeyProvider.instance?.apiKeyFor(provider) ??
          ApiKeyRepositoryImpl.getCachedKey(provider);
      final activeHint = (activeKey != null && activeKey.apiKey.isNotEmpty)
          ? activeKey.keyHint
          : null;

      UsageSummaryModel? chosen;

      if (activeHint != null) {
        final expectedDocId = '${provider.id}_$activeHint';
        chosen = _summariesByDocId[expectedDocId];

        // Also check if any doc in this provider matches the keyHint
        if (chosen == null) {
          for (final s in _summariesByDocId.values) {
            if (s.provider == provider && s.keyHint == activeHint) {
              chosen = s;
              break;
            }
          }
        }
      }

      // Fallback: legacy doc matching provider.id
      chosen ??= _summariesByDocId[provider.id];

      // Fallback: newest summary for this provider
      if (chosen == null) {
        final matching = _summariesByDocId.values
            .where((s) => s.provider == provider)
            .toList();
        if (matching.isNotEmpty) {
          matching.sort((a, b) => (b.updatedAt ?? DateTime(0))
              .compareTo(a.updatedAt ?? DateTime(0)));
          chosen = matching.first;
        }
      }

      if (chosen != null) {
        _summaries[provider] = chosen;
      }
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
    final existing =
        summaryFor(provider) ?? UsageSummaryModel(provider: provider);
    final activeKey = ApiKeyProvider.instance?.apiKeyFor(provider) ??
        ApiKeyRepositoryImpl.getCachedKey(provider);
    final activeHint = (activeKey != null && activeKey.apiKey.isNotEmpty)
        ? activeKey.keyHint
        : existing.keyHint;

    // Prioritize active key docId if active key is present, preventing orphan provider docs
    final resolvedDocId = (activeHint != null && activeHint.isNotEmpty)
        ? '${provider.id}_$activeHint'
        : (existing.docId.isNotEmpty ? existing.docId : provider.id);

    final updated = UsageSummaryModel(
      docId: resolvedDocId,
      provider: provider,
      totalBudgetUsd: amountUsd,
      alreadyUsedUsd: alreadyUsedUsd,
      monthlyData: existing.monthlyData,
      keyHint: activeHint,
      encryptedApiKey: existing.encryptedApiKey,
      updatedAt: DateTime.now(),
    );

    try {
      await _repo.updateGlobalSettings(uid: uid, model: updated);
      _summaries[provider] = updated;
      _summariesByDocId[resolvedDocId] = updated;
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
      final existing = summaryFor(provider);
      final activeKey = ApiKeyProvider.instance?.apiKeyFor(provider) ??
          ApiKeyRepositoryImpl.getCachedKey(provider);
      final activeHint = (activeKey != null && activeKey.apiKey.isNotEmpty)
          ? activeKey.keyHint
          : existing?.keyHint;

      final targetDocId = (activeHint != null && activeHint.isNotEmpty)
          ? '${provider.id}_$activeHint'
          : ((existing != null && existing.docId.isNotEmpty)
              ? existing.docId
              : provider.id);

      await _repo.disableBudget(
        uid: uid,
        provider: provider,
        docId: targetDocId,
      );

      if (existing != null) {
        final updated = UsageSummaryModel(
          docId: targetDocId,
          provider: provider,
          totalBudgetUsd: null,
          alreadyUsedUsd: null,
          monthlyData: existing.monthlyData,
          keyHint: existing.keyHint,
          encryptedApiKey: existing.encryptedApiKey,
          updatedAt: DateTime.now(),
        );
        _summaries[provider] = updated;
        _summariesByDocId[targetDocId] = updated;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ removeBudget failed: $e');
      rethrow;
    }
  }
}
