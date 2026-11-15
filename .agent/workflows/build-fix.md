---
description: Diagnose and fix compiler, analyzer, codegen, or typecheck errors with minimal diffs
---

1. Load `personas/build-error-resolver.md`.
2. Run the platform analyzer/build command to capture exact compiler errors.
3. Identify the root error and apply the smallest safe fix without suppressing warnings or touching unrelated code.
4. Re-run the build command to ensure clean completion.