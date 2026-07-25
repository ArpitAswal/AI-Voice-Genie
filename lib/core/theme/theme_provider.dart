import 'package:flutter/material.dart';

import '../constants/storage_keys.dart';
import '../enums/app_enums.dart';
import '../services/storage_service.dart';

/// Theme provider for AI Voice Genie.
///
/// Persists the user's theme preference to Hive.
/// Drives MaterialApp.themeMode via Consumer.
///
/// Usage:
/// ```dart
/// context.read<ThemeProvider>().setTheme(ThemeType.dark);
/// context.watch<ThemeProvider>().themeMode
/// ```
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeType get currentThemeType {
    switch (_themeMode) {
      case ThemeMode.light:
      case ThemeMode.system:
        return ThemeType.light;
      case ThemeMode.dark:
        return ThemeType.dark;
    }
  }

  /// Load persisted theme from Hive on app start.
  void initialize() {
    final saved = StorageService().getString(StorageKeys.themeMode);
    if (saved != null) {
      final type = ThemeType.fromValue(saved);
      _themeMode = _toThemeMode(type);
    }
  }

  /// Update theme and persist to local storage.
  Future<void> setTheme(ThemeType type) async {
    _themeMode = _toThemeMode(type);
    await StorageService().setString(StorageKeys.themeMode, type.value);
    notifyListeners();
  }

  ThemeMode _toThemeMode(ThemeType type) {
    switch (type) {
      case ThemeType.light:
      case ThemeType.system:
        return ThemeMode.light;
      case ThemeType.dark:
        return ThemeMode.dark;
    }
  }
}