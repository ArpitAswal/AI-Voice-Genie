---
description: Create a structured implementation plan and architectural blueprint before coding
---

1. Read `AGENTS.md`, `context.md`, and `personas/planner.md`.
2. Inspect the target feature files, `pubspec.yaml`, and the active platform rules in `rules/platforms/`.
3. Produce the 5-part implementation plan defined in `personas/planner.md`:
   - Problem Statement & Scope
   - Impact & Dependency Analysis (exact file paths + build_runner gate if Hive models are touched)
   - Interface Contracts & Data Models (ChangeNotifier state, Hive typeId, HTTP contracts, typed failures)
   - Phased TDD Implementation (Phase 1 Domain → Phase 2 Data → Phase 3 State → Phase 4 UI)
   - Edge Cases & Verification Plan (CLI commands to run)
4. Pause and wait for user confirmation before modifying any project files.