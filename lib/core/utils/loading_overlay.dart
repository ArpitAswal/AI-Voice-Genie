import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';

/// ✨ NEW: Global loading overlay that blocks user interaction
///
/// Shows a centered loading indicator with a semi-transparent background
/// Usage:
/// ```dart
/// // Show loading
/// LoadingOverlay.show(context);
///
/// // Hide loading
/// LoadingOverlay.hide(context);
///
/// // Or wrap async operation
/// await LoadingOverlay.wrap(
///   context,
///   future: someAsyncOperation(),
/// );
/// ```
class LoadingOverlay {
  static bool _isShowing = false;
  static BuildContext? _dialogContext;

  /// Show the loading overlay
  ///
  /// [context] - BuildContext to show the dialog
  /// [message] - Optional loading message (default: "Loading...")
  static void show(BuildContext context, {String? message}) {
    // Prevent showing multiple overlays
    if (_isShowing) return;

    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext ctx) {
        _dialogContext = ctx;
        return PopScope(
          // Prevent back button / swipe to close
          canPop: false,
          child: _LoadingOverlayWidget(message: message),
        );
      },
    ).then((_) {
      _isShowing = false;
      _dialogContext = null;
    });
  }

  /// Hide the loading overlay
  static void hide() {
    if (!_isShowing || _dialogContext == null) return;

    try {
      if (Navigator.of(_dialogContext!).canPop()) {
        Navigator.of(_dialogContext!).pop();
      }
    } catch (_) {
      // ignore
    }
    _isShowing = false;
    _dialogContext = null;
  }

  /// Wrap an async operation with loading overlay
  ///
  /// Automatically shows loading at start and hides when complete
  /// Returns the result of the future
  ///
  /// Example:
  /// ```dart
  /// final result = await LoadingOverlay.wrap(
  ///   context,
  ///   future: authProvider.login(email, password),
  ///   message: "Logging in...",
  /// );
  /// ```
  static Future<T> wrap<T>({
    required BuildContext context,
    required Future<T> future,
    String? message,
  }) async {
    try {
      show(context, message: message);
      final result = await future;
      return result;
    } finally {
      // Always hide loading, even if error occurs
      hide();
    }
  }

  /// Check if loading is currently showing
  static bool get isShowing => _isShowing;
}

/// Internal widget for the loading overlay UI
class _LoadingOverlayWidget extends StatelessWidget {
  final String? message;

  const _LoadingOverlayWidget({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: context.screenWidth * 0.5,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 16,
            vertical: isTablet ? 36 : 32,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Progress Indicator
              SizedBox(
                width: isTablet ? 60 : 30,
                height: isTablet ? 60 : 30,
                child: CircularProgressIndicator(
                  strokeWidth: isTablet ? 4 : 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),

              SizedBox(height: isTablet ? 24 : 24),

              // Loading text
              Text(
                message ?? 'Loading...',
                style: (theme.textTheme.bodyLarge)?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension method to easily show/hide loading from context
extension LoadingOverlayExtension on BuildContext {
  /// Show loading overlay
  void showLoading({String? message}) {
    LoadingOverlay.show(this, message: message);
  }

  /// Hide loading overlay
  void hideLoading() {
    LoadingOverlay.hide();
  }

  /// Wrap future with loading
  Future<T> withLoading<T>({required Future<T> future, String? message}) {
    return LoadingOverlay.wrap(context: this, future: future, message: message);
  }
}
