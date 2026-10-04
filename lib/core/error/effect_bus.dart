import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class EffectBus {
  /// Singleton instance used globally.
  static final instance = EffectBus._();
  EffectBus._();

  /// Broadcast stream allows multiple listeners.
  /// Used to propagate side-effect failures across the app.
  final _controller = StreamController<EffectFailure>.broadcast();

  /// Emit an error event into the stream.
  /// Any GlobalEffectListener will receive it, and it will be recorded
  /// as a non-fatal error in Firebase Crashlytics for production monitoring.
  void emit(Object error, StackTrace st) {
    _controller.add(EffectFailure(error, st));
    try {
      FirebaseCrashlytics.instance.recordError(error, st, fatal: false);
    } catch (_) {
      // Handled gracefully in unit testing environments or offline before Firebase initializes
    }
  }

  /// Public stream exposed for listening.
  Stream<EffectFailure> get stream => _controller.stream;

  /// Wrapper for executing async effects safely.
  ///
  /// Instead of try/catch everywhere:
  /// EffectBus.instance.safeEffect(() async { ... });
  ///
  /// Any exception automatically goes into global handler.
  Future<void> safeEffect(Future<void> Function() effect) async {
    try {
      await effect();
    } catch (e, st) {
      EffectBus.instance.emit(e, st);
    }
  }
}

/// Simple data object representing a failed side effect.
/// Keeps both error and stacktrace for logging/debugging.
class EffectFailure {
  final Object error;
  final StackTrace stackTrace;

  EffectFailure(this.error, this.stackTrace);
}

/*
User Action / Background Task
        ↓
safeEffect() executes async operation
        ↓
Exception occurs
        ↓
EffectBus.emit()
        ↓
StreamController.broadcast()
        ↓
GlobalEffectListener receives event
        ↓
PostFrameCallback
        ↓
ScaffoldMessenger
        ↓
Snackbar / Warning UI shown

await EffectBus.instance.safeEffect(() async {
  await api.deleteTask(taskId);
});
 */
