import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../utils/status_message_utils.dart';
import 'ai_exception.dart';
import 'effect_bus.dart';

/// A top-level widget that listens for global side-effect failures
/// and displays UI feedback (Snackbar/Warning) safely.
///
/// This is placed above Navigator via MaterialApp.builder
/// so it can react to errors from anywhere in the app.
class GlobalEffectListener extends StatefulWidget {
  final Widget child;

  /// child represents the Navigator content injected by MaterialApp.builder
  const GlobalEffectListener({super.key, required this.child});

  @override
  State<GlobalEffectListener> createState() => _GlobalEffectListenerState();
}

class _GlobalEffectListenerState extends State<GlobalEffectListener> {
  late final StreamSubscription sub;

  /// Subscription to EffectBus stream.
  /// We keep reference so it can be cancelled in dispose.
  @override
  void initState() {
    super.initState();
    sub = EffectBus.instance.stream.listen(_handle);

    /// Subscribe to global effect stream.
    /// Any failure emitted from EffectBus will trigger _handle().
  }

  /// Called whenever an EffectFailure event is emitted.
  void _handle(EffectFailure f) {
    /// Ensures UI operations happen AFTER current frame build.
    /// Prevents:
    /// - setState during build
    /// - scaffold not yet mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      /// Safety: widget may have been disposed.
      if (!mounted) return;

      /// Obtain ScaffoldMessenger safely.
      /// maybeOf returns null if context not ready.
      final messenger = ScaffoldMessenger.maybeOf(context);

      /// If UI not ready, ignore silently.
      if (messenger == null) return;

      /// Debug logging for development visibility.
      debugPrint("✨SIDE EFFECT FAILED: ${f.error}");

      String errorMsg;
      if (f.error is AiException) {
        final key = (f.error as AiException).message;
        errorMsg = AppLocalizations.of(context)?.translate(key) ?? key;
      } else {
        errorMsg = f.error.toString();
      }

      /// Show warning message globally.
      /// Centralized UI feedback layer.
      MessageUtils.showWarning(context, errorMsg);
    });
  }

  @override
  void dispose() {
    sub.cancel();

    /// Important: cancel stream subscription to avoid memory leak.
    super.dispose();
  }

  /// This widget does NOT render UI itself.
  /// It only wraps child Navigator tree.
  @override
  Widget build(BuildContext context) => widget.child;
}
