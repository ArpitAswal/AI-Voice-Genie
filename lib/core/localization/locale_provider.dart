import 'package:flutter/material.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/services/storage_service.dart';

/// Locale provider for AI Voice Genie.
///
/// Persists the user's language preference to Hive.
/// Drives MaterialApp.locale via Consumer.
///
/// Usage:
/// ```dart
/// context.read<LocaleProvider>().setLocale(const Locale('hi'));
/// context.watch<LocaleProvider>().locale
/// ```
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// All supported locales — referenced directly in MaterialApp
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
  ];

  /// Load persisted locale from Hive on app start.
  void initialize() {
    final saved = StorageService().getString(StorageKeys.locale);
    if (saved != null) {
      _locale = Locale(saved);
    }
  }

  /// Update locale and persist to local storage.
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    _locale = locale;
    await StorageService().setString(StorageKeys.locale, locale.languageCode);
    notifyListeners();
  }

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isHindi => _locale.languageCode == 'hi';
}