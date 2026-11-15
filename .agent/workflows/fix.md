---
description: Apply a fast, surgical targeted fix to a known bug or issue — without a full plan or analysis cycle.
---

1. Load `personas/code-reviewer.md` to verify the exact problem location before touching any file.
2. Load the active platform rule (`rules/platforms/flutter-dart.md`) and `rules/common/coding_style.md`.
3. Apply the **smallest safe change** that resolves the stated issue:
   - Touch only the file(s) and line(s) directly responsible.
   - Do not refactor, reformat, or improve surrounding unrelated code.
4. Forbidden shortcuts: do NOT add `// ignore:` or `!` force-unwraps to bypass the error.
5. Run `dart format <modified_file>` and `flutter analyze <modified_file>` to confirm the fix is clean.
6. Output a concise diff summary: file changed, line changed, before/after snippet. Stop for user review.
