# Antigravity Workspace Instructions

This project is **AI Voice Genie** — a Flutter/Dart multi-model AI voice assistant.
Active stack: Provider · Hive · Firebase · flutter_secure_storage · HTTP REST.

## 1. Primary Orchestration
- Always read and follow `@AGENTS.md` at the project root as the canonical source of engineering principles.
- Always consult `@context.md` (project root) for the latest architectural decisions before starting any task.

## 2. Common Rules
- Code style & size limits: `@rules/common/coding_style.md`
- Security & storage: `@rules/common/security.md`
- Testing & coverage: `@rules/common/testing.md`
- Development lifecycle: `@rules/common/development_workflow.md`

## 3. Platform Rules (load only the matching one)
- Flutter / Dart core: `@rules/platforms/flutter-dart.md`
- Flutter Adaptive UI: `@rules/platforms/flutter-adaptive-ui.md`
- Firebase integration: `@rules/platforms/flutter-firebase.md`
- Android / Kotlin (native modules only): `@rules/platforms/android-kotlin.md`
- iOS / Swift (native modules only): `@rules/platforms/ios-swift.md`

## 4. Personas
- Orchestrator (master router): `@personas/orchestrator.md`
- Analyzer (architecture trade-offs): `@personas/analyzer.md`
- Provider State (ChangeNotifier patterns): `@personas/provider-state.md`

## 5. Workflows (Slash Commands)
- /run: `@.agent/workflows/run.md`
- /analyze: `@.agent/workflows/analyze.md`
- /plan: `@.agent/workflows/plan.md`
- /fix: `@.agent/workflows/fix.md`
- /tdd: `@.agent/workflows/tdd.md`
- /adaptive-ui: `@.agent/workflows/adaptive-ui.md`
- /code-review: `@.agent/workflows/code-review.md`
- /security: `@.agent/workflows/security.md`
- /build-fix: `@.agent/workflows/build-fix.md`
- /verify: `@.agent/workflows/verify.md`
- /document: `@.agent/workflows/document.md`