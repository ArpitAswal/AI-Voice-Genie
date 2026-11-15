---
description: Generate or update project documentation — context.md, README.md, or CHANGELOG.md — based on the current codebase and architectural decisions.
---

1. Load `skills/context-and-decisions/SKILL.md` as the execution protocol for updating `context.md`.
2. Determine which document to update based on the user's request:
   - **`context.md`**: Add a new Key Decision row (Date / Decision / Rationale). Prune stale "Current Focus" items. Keep the file strictly under 150 lines.
   - **`README.md`**: Reflect any new features, changed setup steps, or new AI model integrations. Preserve existing installation and contribution sections.
   - **`CHANGELOG.md`**: Add a new version entry following the Keep-a-Changelog format: `[version] - YYYY-MM-DD` with `Added`, `Changed`, `Fixed`, `Removed` subsections.
3. Read the current state of the target file before writing — never overwrite content that is still accurate.
4. Apply the Conventional Commits log (`git log --oneline -20`) to inform CHANGELOG entries.
5. Output a brief summary of what was added, changed, or pruned. Stop for user review before finalizing.
