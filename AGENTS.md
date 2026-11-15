# AI Engineering Orchestration (`AGENTS.md`)

## 0. Active Project Stack (Load Always)
**Project**: AI Voice Genie — Flutter/Dart multi-model AI assistant (voice, vision, PDF, chat).
- **State Management**: Provider (`ChangeNotifier` + `ChangeNotifierProvider` / `Consumer`)
- **Local Storage**: Hive 2 (type-adapters via `hive_generator`) + `flutter_secure_storage` (API keys)
- **Remote**: Firebase (Auth, Firestore, Storage, Analytics, Crashlytics) + REST HTTP (OpenAI, Gemini, Claude)
- **Audio**: `speech_to_text`, `flutter_tts`, `record`
- **Code-gen gate**: `dart run build_runner build --delete-conflicting-outputs` after editing any `@HiveType`/`@HiveField` annotated model.
- **Router**: `lib/core/router/` — inspect before adding routes.
- **context.md**: Consult `context.md` at the project root for active architectural decisions before every task.

## 1. Core Engineering Principles
1. **Plan Before Code**: For any non-trivial feature, architectural change, or multi-file refactor, produce a concise implementation plan (`personas/planner.md`) covering affected modules, data models, interface contracts, and edge cases before mutating source files.
2. **Immutability by Default**: Prefer immutable data structures, value objects, and unidirectional data flow (`final`/`const` in Dart). Mutate state only through `ChangeNotifier.notifyListeners()` — never directly on exposed collections.
3. **Separation of Concerns**: Keep domain and business logic in pure-Dart classes under `lib/features/<feature>/domain/`. Never import `package:flutter/material.dart` into domain or data layers.
4. **Minimal Diff Discipline**: Modify only the files and lines required for the task. Never perform drive-by formatting, unprompted dependency updates, or speculative abstractions.
5. **Search & Inspect First**: Read `pubspec.yaml`, `lib/core/`, and adjacent feature modules before introducing any new pattern or library.

## 2. Standard Execution Workflow
1. **Understand & Scope**: Read `context.md` (project root), relevant feature files, and `pubspec.yaml`.
2. **Plan**: Define step-by-step phases, interface boundaries, and test cases via `personas/planner.md`.
3. **Test-Driven Implementation (`RED → GREEN → REFACTOR`)**:
   - Write or update failing tests first (`skills/tdd-workflow/SKILL.md`).
   - Implement the minimal code required to pass.
   - Run `dart run build_runner build --delete-conflicting-outputs` if Hive models were touched.
   - Refactor for clarity, immutability, and adherence to `rules/common/coding_style.md`.
4. **Verify (`skills/verification-loop/SKILL.md`)**:
   - Run `dart format .` → `flutter analyze` → `flutter test`.
   - Review diffs against `personas/code-reviewer.md` and `rules/common/security.md`.

## 3. Personas (Roles)
- **Orchestrator**: `personas/orchestrator.md` — master entry point, routes all tasks end-to-end.
- **Analyzer**: `personas/analyzer.md` — evaluates requirements, produces architectural trade-offs.
- **Architect**: `personas/architect.md` — enforces layer boundaries and dependency direction.
- **Planner**: `personas/planner.md` — produces phased implementation plan before coding.
- **Code Reviewer**: `personas/code-reviewer.md` — reviews diffs for bugs, leaks, and security flaws.
- **Security Reviewer**: `personas/security-reviewer.md` — audits secrets, storage, and manifests.
- **TDD Guide**: `personas/tdd-guide.md` — coaches RED → GREEN → REFACTOR cycle.
- **Build Error Resolver**: `personas/build-error-resolver.md` — fixes compiler and analyzer errors.
- **Adaptive Screen**: `personas/flutter-adaptive-screen.md` — responsive UI for Mobile/Tablet/Desktop.
- **Provider State**: `personas/provider-state.md` — enforces correct Provider/ChangeNotifier patterns.

## 4. Baseline Standards (Always Load)
- `rules/common/coding_style.md`
- `rules/common/security.md`
- `rules/common/testing.md`
- `rules/common/development_workflow.md`

## 5. Conditional Platform Extensions
Load ONLY the platform rule matching your active workspace files:
- Flutter/Dart core: `rules/platforms/flutter-dart.md`
- Flutter Adaptive UI: `rules/platforms/flutter-adaptive-ui.md`
- Firebase integration: `rules/platforms/flutter-firebase.md`
- Android/Kotlin (native module): `rules/platforms/android-kotlin.md`
- iOS/Swift (native module): `rules/platforms/ios-swift.md`