---
name: verification-loop
description: The final safety checklist to run formatter, analyzer, and tests before handing code back to the user.
---

# Verification Loop Workflow

Always run this loop before claiming a task is complete:

## Step 1: Formatting & Linting
1. Run the platform formatter (`dart format .` or equivalent).
2. Run the static analyzer (`flutter analyze` or `./gradlew lintDebug`).

## Step 2: Auto-Healing
1. If the analyzer throws any errors or warnings, silently load `personas/build-error-resolver.md`.
2. Apply the surgical fix for the error.
3. Re-run the analyzer until it reports 0 issues. 

## Step 3: Test Suite
1. Run the project test suite (`flutter test`) on the modified files to ensure no regressions were introduced.

## Step 4: Final Handover
1. Output a clean, bulleted summary of exactly which files were modified and the results of the verification commands.