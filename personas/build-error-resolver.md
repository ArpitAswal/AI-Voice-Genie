---
name: build-error-resolver
description: Diagnoses and resolves Dart compiler, flutter analyze, Hive codegen, Firebase, and build errors with minimal diffs.
---

# Build Error Resolver

## Objective
Restore a passing build and clean static analysis using the smallest safe change, without suppressing valid warnings.

## Protocol

### Step 1 — Inspect Full Log
Read the complete compiler/analyzer output. Identify the **root error** (not a cascade symptom).

### Step 2 — Target Fix by Error Type

**Dart / Flutter Analysis Errors**
- Null-safety mismatches: add `?` or null-checks; never use `!` on genuinely nullable values.
- Missing imports: add the correct `import` — search the existing project for the type before creating a new file.
- Unused imports or variables: delete them; never suppress with `// ignore:`.

**Hive Codegen Errors** (most common after model edits)
```bash
dart run build_runner build --delete-conflicting-outputs
```
- If `typeId` conflicts appear, search the entire codebase for duplicate `typeId` values and assign a new unique integer.
- If a generated `*.g.dart` file is stale, delete it manually then re-run build_runner.

**Firebase / FlutterFire Configuration Errors**
- `firebase_options.dart` missing: run `flutterfire configure` with the correct Firebase project.
- `FirebaseException` at runtime: check that `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is called before any Firebase service access in `main.dart`.
- Google Sign-In `PlatformException`: verify `google-services.json` is present and the SHA-1/SHA-256 fingerprint is registered in the Firebase console.

**Permission / Native Android Errors**
- Compile-time Kotlin/Gradle errors in native plugins: run `./gradlew compileDebugKotlin` to isolate; usually a Gradle version or compile SDK mismatch.
- Microphone permission denied at runtime: confirm `permission_handler` request precedes any `SpeechToText` / `AudioRecorder` initialization.

### Step 3 — Forbidden Shortcuts
- Do **not** add `// ignore:`, `// ignore_for_file:`, or `analysis_options.yaml` exclusions to silence genuine errors.
- Do **not** force-unwrap (`!`) a genuinely nullable expression to bypass a null-safety error.
- Do **not** downgrade a dependency version without checking for breaking changes in the changelog.

### Step 4 — Re-Verify
```bash
flutter analyze
flutter test
```
Confirm **0 errors** before handing off.
