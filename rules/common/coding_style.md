# Common Coding Style & Maintainability Rules

## 1. Immutability & Data Modeling
- Default all variables, properties, and collections to immutable references (`final`/`const` in Dart, `val` in Kotlin, `let` in Swift, `const` in TypeScript).
- Represent state transitions by returning new copies (e.g., `copyWith` in Dart) rather than mutating shared objects in place.
- Model finite states explicitly using algebraic data types (Dart 3 sealed classes, Swift enums, TS discriminated unions) instead of multiple boolean flags (`isLoading`, `isError`).

## 2. Naming Conventions
- Types/Classes/Widgets: `PascalCase`
- Functions/Methods/Variables/Parameters: `camelCase`
- Constants: `camelCase` (Dart/Swift) or `UPPER_SNAKE_CASE` (Kotlin `const val`)
- Files: `snake_case.dart` (Dart), `PascalCase.kt` (Kotlin), `PascalCase.swift` (Swift)
- Private members: prefix with `_` (Dart convention: `_privateField`)

## 3. Function & File Size Guidelines
- **Functions**: Target **≤ 40–50 lines**, single level of abstraction.
- **Files**: Target **≤ 300–400 lines**.
- **Documented Exceptions**:
  1. Declarative UI trees (Flutter `build` methods) when extracting sub-widgets reduces readability.
  2. Exhaustive pattern-matching `switch` statements on sealed types.
  3. Generated code (`*.g.dart`, KSP/Room outputs).

## 4. Control Flow & Error Handling
- Use guard clauses and early returns; keep indentation ≤ 3 levels.
- Never swallow exceptions silently (`catch (_) {}`). Surface a typed domain failure or rethrow.
- Never use `dynamic` or `Object` as a return type unless wrapping a genuinely polymorphic API boundary.

## 5. Static Analysis (Dart-Specific)
- The project's `analysis_options.yaml` enforces `flutter_lints`. Always run `flutter analyze` before completing a task.
- Never add `// ignore:` or `// ignore_for_file:` comments to suppress genuine lint warnings. Fix the root cause instead.
- Treat all analyzer warnings as errors during development — do not leave the codebase in a "warnings OK" state.