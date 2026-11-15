---
description: Run the 5-gate pre-completion verification loop (diff audit, format, analyze, test, report)
---

1. Load `skills/verification-loop/SKILL.md`.
2. Run all 5 gates in sequence:
   - Gate 1: Git diff + secret scan (`rules/common/security.md`) — confirm no API keys, tokens, or `.env` files are staged.
   - Gate 2: `dart format .` — zero residual formatting diff.
   - Gate 3: Hive codegen check — if any `@HiveType`/`@HiveField` model was modified, run `dart run build_runner build --delete-conflicting-outputs` before analysis.
   - Gate 4: `flutter analyze` — must report 0 issues. If errors appear, auto-load `personas/build-error-resolver.md`, fix the root cause, and re-run.
   - Gate 5: `flutter test` — must be 100% green. Report the test count and any failures.
3. Output a gate-by-gate pass/fail table and a final **STATUS: READY TO COMMIT ✅** or **STATUS: BLOCKED ❌** verdict.