import 'package:flutter/material.dart';

import '../../../../core/services/analytics_service.dart';

/// ViewModel responsible for managing the root TabBar navigation state.
///
/// Follows MVVM architecture:
/// - Encapsulates active tab index and tab switching logic.
/// - Handles back-press double-tap exit debouncing.
/// - Dispatches analytics screen-view events without cluttering presentation widgets.
class HomeNavViewModel extends ChangeNotifier {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

  /// Current active tab index (0: Intro/Home, 1: History, 2: Profile).
  int get currentIndex => _currentIndex;

  /// Updates the active tab and logs the screen view to Analytics.
  ///
  /// Ignores redundant selection when tapping the already active tab.
  void selectTab(int index) {
    if (_currentIndex == index) return;

    _currentIndex = index;
    notifyListeners();

    // Log screen view in analytics for user navigation tracking
    final (screenName, screenClass) = switch (index) {
      0 => ('Home Screen', 'IntroScreen'),
      1 => ('Conversation History Screen', 'ConversationHistoryScreen'),
      2 => ('Profile Screen', 'ProfileScreen'),
      _ => ('Home Screen', 'TabBarScreen'),
    };

    AnalyticsService.instance.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Handles double-back-press logic for app exit prevention.
  ///
  /// Returns `true` if the back button was pressed within 2 seconds of the
  /// previous press (indicating the app should exit). Otherwise triggers
  /// the [onShowExitWarning] callback and returns `false`.
  bool handleBackPress({required VoidCallback onShowExitWarning}) {
    final now = DateTime.now();
    if (_lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
      _lastPressedAt = now;
      onShowExitWarning();
      return false; // Do not exit yet
    }
    return true; // Allow exit
  }

  @override
  void dispose() {
    // Clean up internal references to prevent memory leaks
    _lastPressedAt = null;
    super.dispose();
  }
}
