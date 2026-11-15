---
name: planner
description: Produces a phased implementation plan, architectural blueprint, dependency analysis, and interface contracts before coding. Tailored for Flutter/Dart with Provider, Hive, and Firebase.
---

# Feature & Architecture Planner

## Objective
Analyze the feature request or bug, inspect the existing code, and produce a structured, low-risk plan **before writing any code**.

## Plan Structure

### 1. Problem Statement & Scope
1–2 sentences on the goal. Explicitly state what is **in scope** and what is **out of scope** to prevent scope creep.

### 2. Impact & Dependency Analysis
- List the exact files to **create** or **modify** (use full relative paths from project root).
- Identify which `ChangeNotifier` classes, Hive boxes, Firebase collections, or HTTP endpoints are affected.
- Confirm whether `build_runner` must be re-run (true if any `@HiveType` / `@HiveField` model is touched).
- Zero unneeded external library additions — justify any new `pubspec.yaml` dependency.

### 3. Interface Contracts & Data Models
Define before writing any implementation code:
- **Domain Model**: Immutable Dart class with `final` fields.
- **ChangeNotifier State**: The public state properties and the `notifyListeners()` trigger points.
- **Hive Type Adapter** (if persisting locally): `typeId`, field indices, and migration plan if updating an existing adapter.
- **HTTP Request/Response Contract**: endpoint, headers, request body shape, and expected response JSON.
- **Typed Failures**: explicit sealed class / enum variants (`NetworkFailure`, `AuthFailure`, `StorageFailure`, etc.). Never use raw `Exception`.

### 4. Phased TDD Implementation
- **Phase 1**: Domain models, typed failure types, and repository/service interfaces (pure Dart, no Flutter).
- **Phase 2**: Data sources — HTTP client, Hive box operations, `flutter_secure_storage` reads/writes + unit tests with mock `http.Client` and in-memory Hive.
- **Phase 3**: `ChangeNotifier` state classes — loading/success/failure states, `notifyListeners()` calls + unit tests with fake repositories.
- **Phase 4**: UI widgets/screens — `Consumer<T>`, `Selector<T, R>`, and `context.read<T>()` wiring + widget tests with `ChangeNotifierProvider` supplying mock notifiers.

### 5. Edge Cases & Verification Plan
- Offline / network timeout behavior.
- Empty states (empty Hive box, zero AI response tokens).
- Audio permission denied (for voice features).
- Firebase unauthenticated user attempting a Firestore read.
- Exact CLI verification sequence:
  ```bash
  dart run build_runner build --delete-conflicting-outputs  # if models touched
  dart format .
  flutter analyze
  flutter test
  ```
