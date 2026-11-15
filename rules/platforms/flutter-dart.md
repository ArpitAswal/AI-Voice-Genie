# Platform Extension: Flutter & Dart

> **Activation**: Apply when working with `pubspec.yaml`, `*.dart` files, or Flutter widgets and state holders.

## 1. Architecture & State Management
- **Feature-First Structure**: Organize code by feature (`lib/features/<feature_name>/{data, domain, presentation}`), not by global file types. Shared utilities live in `lib/core/`.
- **Provider Pattern (Project Standard)**: This project uses `Provider` with `ChangeNotifier`. Do **not** introduce Riverpod, BLoC, or GetX without explicit architectural approval. Access state with `context.watch<T>()` for rebuilding widgets and `context.read<T>()` for event-only calls (never `context.watch` inside callbacks or `initState`).
- **Domain Independence**: Keep domain models and business logic pure Dart. Never import `package:flutter/material.dart` or UI dependencies into `domain/` or `data/` layers.
- **Sealed Types**: Use Dart 3 `sealed class` with exhaustive `switch` to represent UI/domain states (`Initial`, `Loading`, `Success`, `Failure`).

## 2. Rebuild Discipline & Widget Performance
- **Aggressive `const`**: Add `const` to all widget constructors and child subtrees where possible.
- **Scope Listeners Tight**: Wrap only the specific child widgets that depend on state changes in `Consumer<T>` or `Selector<T, R>`. Avoid `context.watch` at the top-level screen widget to prevent full-tree rebuilds.
- **ListView Builders**: Always use `ListView.builder` or slivers for dynamic or long lists. Never embed an unbounded `ListView` inside a `Column` without `Expanded` or `Flexible`.

## 3. Lifecycle & Asynchronous Safety
- **Dispose Controllers**: Every `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`, `StreamSubscription`, or `ChangeNotifier` created in a widget or controller MUST be disposed in `dispose()`.
- **Async `BuildContext` Safety**: After any `await`, always check `if (!context.mounted) return;` before calling `Navigator`, showing `SnackBar`s, or accessing `Theme.of(context)`.
- **Isolate Offloading**: Offload heavy JSON parsing (>50 KB), LLM response post-processing, or PDF compilation to a worker isolate using `Isolate.run()`.
- **Audio Lifecycle**: Stop `SpeechToText`, `FlutterTts`, and `AudioRecorder` streams in `dispose()` to avoid microphone lock on Android.

## 4. Hive Local Database
- Annotate models with `@HiveType(typeId: N)` and `@HiveField(N)`. Use unique, stable `typeId` integers — never reuse or change them.
- After editing any annotated model, regenerate adapters:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Open boxes lazily (`await Hive.openBox<T>('name')`) and close them in `dispose()` for screens that own the lifecycle.
- Never store sensitive data (API keys, auth tokens) in Hive. Use `flutter_secure_storage` exclusively for those.

## 5. Code Generation & Serialization
- Run the build runner after editing `@HiveType` / `@HiveField` annotations:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Keep generated files (`*.g.dart`) committed to source control so CI doesn't require a codegen step.

## 6. Verification Commands
```bash
dart format .
flutter analyze
flutter test
flutter test --coverage   # for coverage reports
```
