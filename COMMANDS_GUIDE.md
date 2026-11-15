# Daily Engineering Commands Guide (`COMMANDS_GUIDE.md`)

> A practical guide for developers and AI agents explaining **which command to use, when to use it in daily production work, and why** — with concrete Flutter/Dart technical examples.

---

## 🧭 Quick Decision Matrix: "What do you want to do?"

| Situation / Problem | Recommended Command | What It Does (In 5 Words) |
| :--- | :--- | :--- |
| **"I have a big task and want everything handled end-to-end."** | `/run` | Autonomous end-to-end project manager |
| **"I have a new feature idea or architecture question."** | `/analyze` | Compares trade-offs with pros & cons |
| **"I know what to build, now I need a step-by-step roadmap."** | `/plan` | Detailed phased blueprint before coding |
| **"I want an inspection of flaws, bugs, and UI issues."** | `/code-review` | Non-destructive audit by severity level |
| **"I already know the exact bug; just fix the code directly."** | `/fix` | Fast, surgical targeted code change |
| **"I want to build a feature or fix a bug with unit tests first."** | `/tdd` | Test-first (Red → Green → Refactor) |
| **"My screen looks stretched or broken on tablet/landscape."** | `/adaptive-ui` | Phone, Tablet & Landscape layout fix |
| **"I'm about to push code to GitHub or publish to the Play Store."** | `/security` | Scans for leaked keys, tokens, secrets |
| **"flutter analyze / build_runner failed with red errors."** | `/build-fix` | Surgically resolves compiler/codegen errors |
| **"I want to verify all tests and analysis pass before committing."** | `/verify` | Automated quality & regression gate |
| **"I need to update AGENTS.md, context.md, or Architecture docs."** | `/document` | Auto-generates clean project documentation |

---

## 1. 🧑‍✈️ `/run` — The Master Orchestrator

### In Simple Words
Think of `/run` as your **Senior Project Manager**. Instead of running 5 separate commands in order, you tell `/run` your goal. It asks you two quick questions (What to do? Which screens?), then autonomously chains planning, coding, responsive design, testing, and verification from start to finish without you orchestrating each step.

### When to Use in Daily Production
- When starting a major feature and you want the agent to handle the full pipeline.
- When doing a whole-app quality cleanup (bug audit + UI + security in one shot).
- When you're in a hurry and don't want to decide which sub-commands to invoke.

### Technical Example
```
/run
```
> **Prompt Dialogue:**
> *Agent:* "What would you like me to do?"
> *Developer:* `2` *(Implement a New Feature)*
> *Agent:* "What is the target scope?"
> *Developer:* `lib/features/voice_speech/`
>
> **Result:** The agent reads `context.md` + `AGENTS.md`, loads `flutter-dart.md` + `flutter-firebase.md` + `provider-state.md`, runs the analyzer to understand the existing `VoiceNotifier`, creates a phased plan, implements it with TDD, and runs the full verification loop — producing a **Final Handover Report**.

### What It Asks You (The 2-Question Intake)

> **Question 1 — What to do?** (pick one or combine, e.g. `1 + 5`)
> 1. Audit & Fix Bugs / Crashes
> 2. Implement a New Feature
> 3. UI/UX Redesign & Adaptive Layout
> 4. Holistic Screen Testing (TDD)
> 5. Public GitHub Security & Readiness Audit
>
> **Question 2 — Target Scope?**
> - Specific file: `lib/features/chat/presentation/chat_screen.dart`
> - Feature module: `voice_speech`
> - Entire app: `all` *(processes module-by-module)*

---

## 2. 🏛️ `/analyze` — The System Architect

### In Simple Words
Think of `/analyze` as a **Senior Architect brainstorm session**. Before anyone writes code, `/analyze` looks at your existing codebase, challenges weak assumptions, and presents **2–3 different ways to solve the problem** — each with concrete Pros, Cons, and a declared winner. It writes **zero production code**.

### When to Use in Daily Production
- Before adding a significant feature that touches multiple files or layers.
- When unsure whether to extend an existing `ChangeNotifier` or create a new one.
- When evaluating storage strategy (Hive vs Firestore vs `flutter_secure_storage`).

### Technical Example
```
/analyze The voice_speech and chat features both need the same "currently selected AI model". Should we share one ChangeNotifier, use a Hive setting, or pass it as a constructor argument?
```
> **Result:** The agent outputs an Architectural Report:
> - **Approach A (Shared ModelSelectionNotifier):** Pros (reactive, all widgets update instantly). Cons (ChangeNotifier coupling across feature boundaries).
> - **Approach B (Hive Setting + local read):** Pros (persistent across restarts, no cross-feature dependency). Cons (not reactive — requires manual refresh on model change).
> - **Approach C (Constructor injection from HomeScreen):** Pros (simple, explicit). Cons (deep prop-drilling, breaks if feature is opened from a notification deep link).
>
> *Architect's Recommendation:* Approach A with a dedicated `ModelSelectionNotifier` registered at `MultiProvider` root — reactive, testable, no prop-drilling.

---

## 3. 📐 `/plan` — The Blueprint Planner

### In Simple Words
Think of `/plan` as the **Construction Blueprint before the first brick is laid**. Once you've approved an architecture decision, `/plan` maps out the exact steps: which files will be created, which Hive type IDs to assign, what interface contracts look like, and in what order to write tests — before a single line of production code is written.

### When to Use in Daily Production
- Right after `/analyze` selects an approach.
- Before any multi-file feature implementation.
- Before fixing a bug that touches more than 2 files.

### Technical Example
```
/plan Add streaming support for the OpenAI endpoint in ChatNotifier using Option A from the analysis.
```
> **Result:** Generates a 5-part implementation plan:
> 1. **Problem & Scope:** Add SSE streaming to OpenAI only. Out of scope: Gemini/Claude streaming.
> 2. **Impact Analysis:** `openai_data_source.dart` (modify), `chat_notifier.dart` (modify), `stream_failure.dart` (create). No `build_runner` run needed.
> 3. **Interface Contract:** `Stream<String> streamResponse(String prompt);` on the repository interface. `sealed class StreamFailure { StreamTimeout | StreamAborted }`.
> 4. **TDD Phases:** Phase 1 → `StreamFailure` sealed class. Phase 2 → `OpenAiDataSource` with `MockClient`. Phase 3 → `ChatNotifier.streamResponse()` with `FakeRepository`. Phase 4 → `StreamBuilder` in `ChatScreen`.
> 5. **Verification:** `dart format .` → `flutter analyze` → `flutter test`.

---

## 4. 🔍 `/code-review` — The Quality Inspector

### In Simple Words
Think of `/code-review` as a **Thorough Building Inspector**. It reads your code and flags bugs, memory leaks, security holes, and async hazards. It is **100% read-only** — it never modifies your files without permission. Findings are grouped by severity so you know exactly what must be fixed vs. what is optional polish.

### When to Use in Daily Production
- Before every git commit or pull request.
- After completing a feature implementation — catch edge cases you missed.
- When you suspect a memory leak or missing `mounted` check.

### Technical Example
```
/code-review Review lib/features/chat/presentation/chat_screen.dart and lib/features/chat/domain/chat_notifier.dart
```
> **Result:** Categorized report:
>
> **[CRITICAL]**
> - `chat_notifier.dart:67` — `StreamSubscription` opened but never cancelled in `dispose()`. This holds the microphone open after navigation.
>   ```dart
>   // Fix: add to dispose()
>   _streamSub?.cancel();
>   ```
>
> **[HIGH]**
> - `chat_screen.dart:112` — `Navigator.push()` called after `await _notifier.send()` without `mounted` check. Will throw on fast navigation.
>   ```dart
>   if (!context.mounted) return;
>   Navigator.push(context, ...);
>   ```
>
> **[MEDIUM]**
> - `chat_screen.dart:18` — `Consumer<ChatNotifier>` wraps the entire `Scaffold`. Move it to wrap only the `MessageList` widget to avoid rebuilding the `AppBar` on every message.
>
> **[LOW / NIT]**
> - `chat_notifier.dart:34` — Variable `msgs` is misleadingly short; prefer `messages` for clarity.

---

## 5. 🔧 `/fix` — The Surgical Mechanic

### In Simple Words
Think of `/fix` as a **Fast Mechanic**. When you already know what is broken and don't need an architecture discussion or 5-step plan, `/fix` jumps straight to the exact file, changes only the required lines, runs `flutter analyze`, and confirms the build is clean.

### When to Use in Daily Production
- Fixing a specific bug identified by `/code-review`.
- Quick corrections: adding a null check, fixing a typo, correcting a Hive field index.
- Applying a Crashlytics-reported crash fix when the cause is already known.

### When NOT to Use
- If the fix requires touching 3+ files or redesigning a data flow → use `/plan` first.
- If you're unsure of the root cause → use `/analyze` first.

### Technical Example
```
/fix Add missing mounted check in chat_screen.dart:112 before the Navigator.push call
```
> **Result:** Opens `chat_screen.dart`, inserts `if (!context.mounted) return;` at line 112, runs `dart format` and `flutter analyze` to confirm zero issues, outputs a 2-line diff summary.

```
/fix The VoiceNotifier dispose() is missing _speechSubscription.cancel() — add it
```
> **Result:** Applies the one-line fix, re-runs `flutter analyze`. Done.

---

## 6. 🧪 `/tdd` — The Test-First Engineer

### In Simple Words
Think of `/tdd` as a **Test Lab Scientist**. The golden rule: **the test is written before the solution exists**. This forces clear thinking about what the code must do before how it does it, and guarantees every new feature or bug fix is covered by a test that proves it works.

### When to Use in Daily Production
- When adding any new `ChangeNotifier` state class.
- When adding a new Hive data mapper or repository.
- When adding a new AI endpoint integration (OpenAI / Gemini / Claude).
- When fixing a reported crash — write a test that *reproduces* the crash first.

### When NOT to Use
- Pure UI layout changes with no logic (use `/adaptive-ui` instead).
- Renaming variables or extracting widgets with zero logic change.

### Technical Example
```
/tdd Write tests for VoiceNotifier — it should transition Idle → Listening → Processing → Done
```

> **RED Phase** *(write first, must fail)*:
> ```dart
> // test/features/voice_speech/voice_notifier_test.dart
> test('transitions to Listening when startListening() is called', () {
>   final notifier = VoiceNotifier(FakeSpeechService());
>   notifier.startListening();
>   expect(notifier.state, isA<VoiceListening>());
> });
> // flutter test → ❌ FAIL: type 'VoiceIdle' is not a subtype of 'VoiceListening'
> ```

> **GREEN Phase** *(minimum code to pass)*:
> ```dart
> // lib/features/voice_speech/domain/voice_notifier.dart
> void startListening() {
>   _state = const VoiceListening();
>   notifyListeners();
> }
> // flutter test → ✅ PASS
> ```

> **REFACTOR Phase** *(clean up, stay green)*:
> ```dart
> // Extract _setState(), add mounted guard, enforce immutability
> // flutter test → ✅ All tests still green after refactor
> ```

---

## 7. 📱 `/adaptive-ui` — The Responsive Layout Engineer

### In Simple Words
Think of `/adaptive-ui` as a **Responsive Design Specialist**. It makes your app look professional on everything from a compact budget phone in landscape mode, to a 10-inch tablet in portrait, to a large tablet in landscape — all by applying a strict 3-tier breakpoint system while **never touching your business logic, state, or routes**.

### When to Use in Daily Production
- A screen's cards or input fields stretch unnaturally wide on tablet.
- The soft keyboard covers form fields with no scroll escape.
- A new screen needs to be built responsive from scratch.
- The landscape phone view is vertically crushed and unreadable.

### When NOT to Use
- Fixing a bug in a `ChangeNotifier` or repository — use `/tdd` or `/fix`.
- Changing navigation logic — use `/plan` first.

### Technical Example
```
/adaptive-ui Refactor lib/features/chat/presentation/chat_screen.dart for tablet portrait and tablet landscape
```
> **What runs internally (the 4-step pipeline):**
>
> **Step 1 — Non-Destructive Discovery**
> Opens `chat_screen.dart`, traces all `ChatNotifier` listeners, `TextEditingController`s, navigation calls, and state bindings. These are **locked** — nothing about them will change.
>
> **Step 2 — Responsive Layout Planning**
> Plans the 3-tier layout using `skills/adaptive-flutter-screen/templates/adaptive-screen-blueprint-design.md`:
> | Viewport | Condition | Layout Plan |
> |----------|-----------|-------------|
> | Compact | `width < 600 \|\| height <= 550` | Full-screen column + `SingleChildScrollView` |
> | Landscape Phone Guard | `height <= 550` even if wide | Treat as Compact — never 2-column |
> | Medium | `600 <= width <= 840` | `ConstrainedBox(maxWidth: 600)` around message list |
> | Expanded | `width > 840` | `Row( MessageList \| Divider \| ChatInput pane )` |
>
> **Step 3 — Modular Implementation**
> ```dart
> @override
> Widget build(BuildContext context) {
>   final size = MediaQuery.sizeOf(context);
>   final isCompact = size.width < 600 || size.height <= 550;
>   final isExpanded = size.width > 840 && size.height > 550;
>
>   return Scaffold(
>     body: LayoutBuilder(
>       builder: (ctx, constraints) {
>         if (isExpanded) return _ExpandedLayout(constraints: constraints);
>         if (!isCompact) return _MediumLayout(constraints: constraints);
>         return _CompactLayout(constraints: constraints); // default + landscape phone
>       },
>     ),
>   );
> }
> ```
> Sub-widgets are extracted to `lib/features/chat/presentation/widgets/`:
> - `_CompactChatLayout` → scrollable column, keyboard-safe
> - `_MediumChatLayout` → centred ConstrainedBox
> - `_ExpandedChatLayout` → 2-pane Row
>
> **Step 4 — Verification**
> ```bash
> dart format lib/features/chat/presentation/
> flutter analyze lib/features/chat/presentation/
> ```
> Self-check before finishing:
> - ✅ `ChatNotifier` listeners untouched
> - ✅ Navigation calls untouched
> - ✅ `design.md` blueprint NOT overwritten
> - ✅ Landscape phone guard (`height <= 550`) handled

> **Final summary output:**
> ```
> ✅ Adaptive UI Pass — chat_screen.dart
> Modified: chat_screen.dart, widgets/compact_chat_layout.dart (new),
>           widgets/medium_chat_layout.dart (new), widgets/expanded_chat_layout.dart (new)
> Preserved: ChatNotifier, TextEditingController, all Navigator calls
> dart format → ✅   flutter analyze → ✅ 0 issues
> ```

---

## 8. 🔒 `/security` — The Vault Guard

### In Simple Words
Think of `/security` as the **Airport Security Checkpoint before boarding**. Before your code goes public to GitHub or the Play Store, `/security` scans every file for accidentally committed API keys, insecure storage of credentials, overly permissive Firebase rules, missing HTTPS enforcement, and broken `.gitignore` coverage.

### When to Use in Daily Production
- Before every `git push origin main`.
- After adding a new AI model integration (new API key surface).
- When adding Firebase Storage or Firestore collections to verify rules.
- Before submitting to the Google Play Store.

### Technical Example
```
/security Scan the entire project before the v1.0 release push
```
> **Result:**
>
> **[CRITICAL]** `lib/features/key_setup/data/key_repository_impl.dart:34` — API key read from a Hive box instead of `flutter_secure_storage`. Key is stored unencrypted.
> ```dart
> // Fix: replace
> final key = _box.get('openai_key');         // ❌
> // with
> final key = await _secureStorage.read(key: 'openai_key'); // ✅
> ```
>
> **[HIGH]** Firestore rule `allow read, write: if true;` found in `firestore.rules`. All user data is publicly readable.
> Fix: `allow read, write: if request.auth.uid == resource.data.userId;`
>
> **[HIGH]** `lib/features/chat/data/openai_client.dart:22` — `x-api-key` header printed to debug console. Must be removed before release.
>
> **[MEDIUM]** `android/app/src/main/AndroidManifest.xml` has no `android:allowBackup="false"`. Auto-backup could expose Hive files.
>
> **[OK]** `.gitignore` covers `.env`, `local.properties`, `*.jks`, `*.keystore` ✅
> **[OK]** `no_screenshot` active on `key_setup_screen.dart` ✅
> **[OK]** All REST calls use `https://` endpoints ✅

---

## 9. 🏗️ `/build-fix` — The Emergency Doctor

### In Simple Words
Think of `/build-fix` as the **Emergency Room Doctor**. When `flutter analyze` reports red errors, `build_runner` fails with conflicting outputs, or `firebase_options.dart` is missing, `/build-fix` reads the full error log, identifies the **root cause** (not a cascade symptom), applies the smallest safe fix, and re-runs the tool to confirm it passes — without suppressing any warnings.

### When to Use in Daily Production
- `flutter analyze` reports errors after a merge or model edit.
- `build_runner` fails with `"conflicting outputs"` or `"unresolved typeId"`.
- Firebase initialization crashes at runtime with `"No Firebase App '[DEFAULT]'"`.
- After pulling changes that edited a Hive model and you get `"Undefined class XyzAdapter"`.

### Technical Example
```
/build-fix build_runner is failing — "Conflicting outputs for message.g.dart"
```
> **Result:**
> 1. Reads full error output.
> 2. Identifies: `message.g.dart` is a stale generated file from an old model version.
> 3. Applies fix: deletes `message.g.dart`, re-runs:
>    ```bash
>    dart run build_runner build --delete-conflicting-outputs
>    ```
> 4. Re-runs `flutter analyze` → ✅ 0 errors.

```
/build-fix The app crashes on launch: "No Firebase App '[DEFAULT]' has been created"
```
> **Result:** Finds that `Firebase.initializeApp()` is called after `runApp()`. Moves the call to `main()` before `runApp()`, confirms the fix with `flutter analyze`.

**Common Errors This Command Fixes:**

| Error Message | Root Cause | Fix Applied |
|---|---|---|
| `Undefined class MessageAdapter` | `build_runner` not run after `@HiveType` edit | `dart run build_runner build --delete-conflicting-outputs` |
| `Conflicting outputs for x.g.dart` | Stale generated file | Delete `.g.dart`, re-run build_runner |
| `Duplicate typeId '3'` | Two `@HiveType` classes share the same ID | Find duplicate, assign next unused integer |
| `No Firebase App '[DEFAULT]'` | `Firebase.initializeApp()` not awaited | Move `await Firebase.initializeApp()` before `runApp()` |
| `PlatformException: sign_in_failed` | SHA-1 not in Firebase console | Register SHA fingerprint, re-download `google-services.json` |
| `BuildContext used after async gap` | Missing `mounted` check | Add `if (!context.mounted) return;` after `await` |

---

## 10. ✅ `/verify` — The Final Quality Gate

### In Simple Words
Think of `/verify` as the **Flight Pre-Check before takeoff**. It runs the entire local quality pipeline — formatting, codegen check, static analysis, and the full test suite — producing a clear pass/fail per gate. If any gate fails, it auto-loads the Build Error Resolver and fixes it, then re-runs until everything is green.

### When to Use in Daily Production
- **Always** — after every code change, before saying the task is done.
- Before every `git commit` or `git push`.
- After `/tdd`, `/adaptive-ui`, or any implementation work.

### The 5 Gates It Runs
```
Gate 1 — Diff & Secret Check
  ├── git diff --stat  (see what changed)
  └── Scan for API key patterns (rules/common/security.md)

Gate 2 — Formatter
  └── dart format .  (zero formatting diff must remain)

Gate 3 — Hive Codegen Check
  └── If any @HiveType model was modified:
      dart run build_runner build --delete-conflicting-outputs

Gate 4 — Static Analysis
  └── flutter analyze  (must report 0 issues)

Gate 5 — Test Suite
  └── flutter test  (must be 100% green)
```

### Technical Example
```
/verify
```
> **Result:**
> ```
> Verification Report
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> Gate 1 — Diff & Secrets   ✅  No secrets detected. 3 files changed.
> Gate 2 — dart format .    ✅  No formatting changes needed.
> Gate 3 — Codegen          ✅  build_runner clean (1 Hive model regenerated).
> Gate 4 — flutter analyze  ✅  No issues found.
> Gate 5 — flutter test     ✅  22 tests passed. 0 failed.
>
> STATUS: READY TO COMMIT ✅
> ```

> **If a gate fails:**
> ```
> Gate 4 — flutter analyze  ❌
>   → Loading personas/build-error-resolver.md
>   → Root cause: unused import in chat_screen.dart:3
>   → Fix applied. Re-running flutter analyze...
>   → ✅ 0 issues found.
> ```

---

## 11. 📝 `/document` — The Project Biographer

### In Simple Words
Think of `/document` as your **Project Biographer and Wiki Author**. It inspects the codebase, feature list, `context.md`, and git history, then generates or updates clean professional documentation: `context.md` (architectural decisions), `README.md` (project overview), and `CHANGELOG.md` (version history).

### When to Use in Daily Production
- After completing a major feature milestone to log the architectural decision in `context.md`.
- When `context.md` is getting stale or over 150 lines (prune it).
- When onboarding a new developer or AI session that needs project memory.
- After a significant refactor to update `README.md`.

### Technical Example
```
/document Log the decision to add SSE streaming for OpenAI in context.md
```
> **Result:** Opens `context.md`, adds a new row to the Key Decisions table:
> ```markdown
> | 2026-11 | OpenAI SSE streaming via Stream<String> | Reduces perceived latency; Gemini/Claude still use blocking HTTP |
> ```
> Prunes any stale "Current Focus" items. Keeps file under 150 lines.

```
/document Update README.md to reflect the new Claude 3.5 integration and voice export feature
```
> **Result:** Rewrites the Features section of `README.md`, adds usage instructions for the new features, keeps existing setup/installation steps intact.

---

## 💡 Typical Daily Workflow

Here is how to chain commands together during a normal production workday:

```
1. 💡 New idea or requirement           →  /analyze  (evaluate 2–3 options with trade-offs)
2. 📐 Architecture approved             →  /plan     (produce phased blueprint with file list)
3. 🧪 Core logic implementation         →  /tdd      (Red → Green → Refactor with tests first)
4. 📱 Responsive UI layout              →  /adaptive-ui (make it look good on all screen sizes)
5. 🔍 Quality inspection                →  /code-review (catch bugs, leaks, async hazards)
6. 🔒 Pre-push security check           →  /security  (no secrets, no broken Firebase rules)
7. ✅ Final quality gate                →  /verify   (format + analyze + test suite — all green)
8. 📝 Log architectural decision        →  /document  (update context.md + README if needed)
```

**Short-circuit path for small fixes**:
```
Bug reported → /fix → /verify → commit
```

**Short-circuit path for the agent to do everything**:
```
/run → answer 2 questions → sit back
```

---

## 🗂️ Files Behind Every Command

```
📁 .agent/workflows/        ← The slash commands live here
│   ├── run.md              → /run
│   ├── analyze.md          → /analyze
│   ├── plan.md             → /plan
│   ├── tdd.md              → /tdd
│   ├── adaptive-ui.md      → /adaptive-ui
│   ├── code-review.md      → /code-review
│   ├── verify.md           → /verify
│   └── build-fix.md        → /build-fix

📁 personas/                ← Who the AI "becomes" for each task
│   ├── orchestrator.md     → /run
│   ├── analyzer.md         → /analyze (architecture trade-offs)
│   ├── architect.md        → /analyze (layer design)
│   ├── planner.md          → /plan (phase breakdown — Provider/Hive/Firebase aware)
│   ├── provider-state.md   → /run option 2 (ChangeNotifier patterns)
│   ├── tdd-guide.md        → /tdd (test coaching)
│   ├── flutter-adaptive-screen.md → /adaptive-ui
│   ├── code-reviewer.md    → /code-review
│   ├── security-reviewer.md → /security and /run option 5
│   └── build-error-resolver.md → /build-fix and /verify auto-heal

📁 rules/common/            ← Always-on universal standards
│   ├── coding_style.md     → naming, file size, linting, no // ignore:
│   ├── security.md         → keys, storage, Firebase rules, networking
│   ├── testing.md          → pyramid, Hive mocking, Firebase fakes, coverage
│   └── development_workflow.md → lifecycle, build_runner gate, git hygiene

📁 rules/platforms/         ← Load only the matching one per task
│   ├── flutter-dart.md     → Provider, Hive, audio lifecycle, async safety ← PRIMARY
│   ├── flutter-adaptive-ui.md → breakpoints, spacing, scroll safety
│   ├── flutter-firebase.md → init order, Firestore scoping, Crashlytics ← ALWAYS for Firebase
│   ├── android-kotlin.md   → native Android modules only
│   └── ios-swift.md        → native iOS modules only

📁 skills/                  ← Step-by-step execution checklists
│   ├── tdd-workflow/SKILL.md          → RED→GREEN→REFACTOR steps
│   ├── verification-loop/SKILL.md     → 5-gate pre-completion check
│   ├── adaptive-flutter-screen/SKILL.md → 4-step responsive pipeline
│   ├── hive-database/SKILL.md         → Hive model → codegen → registration
│   ├── api-design/SKILL.md            → HTTP contract → DTO → repository
│   └── context-and-decisions/SKILL.md → How to update context.md

📄 AGENTS.md                ← Master project identity (always loaded)
📄 context.md               ← Active architectural decisions (always loaded)
📄 .gemini/GEMINI.md        ← Antigravity workspace configuration
📄 .codex/config.toml       ← Codex workspace configuration
```

---

## ⚡ CLI Quick Reference (Manual Commands)

For when you want to run something directly without the agent:

```bash
# Format all Dart files
dart format .

# Static analysis — must show 0 issues before committing
flutter analyze

# Run all tests
flutter test

# Run with coverage (generates lcov.info)
flutter test --coverage

# Run a specific test file
flutter test test/features/chat/chat_notifier_test.dart

# Run tests matching a name pattern
flutter test --name "ChatNotifier"

# Regenerate Hive type adapters (run after every @HiveType edit)
dart run build_runner build --delete-conflicting-outputs

# Clean and fully regenerate all codegen
dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs

# Regenerate firebase_options.dart (after changing Firebase project)
flutterfire configure

# Check SHA-1 fingerprint (needed for Google Sign-In Firebase setup)
./gradlew signingReport

# Android native compile check
./gradlew compileDebugKotlin

# Android lint
./gradlew lintDebug
```

---

> **Last updated**: 2026-11-14
> **Maintained by**: Project developer — update this file when a new command, persona, or skill is added.
> **Related files**: `AGENTS.md` · `context.md` · `personas/orchestrator.md`
