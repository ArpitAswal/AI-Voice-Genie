---
name: tdd-workflow
description: Step-by-step checklist for executing the RED -> GREEN -> REFACTOR test-driven cycle.
---

# TDD Execution Workflow

Follow this strict pipeline when writing new logic:

## Step 1: RED (Write the Test First)
1. Identify the observable behavior or contract to test.
2. Write a single failing unit or widget test covering this behavior.
3. Run the test command (`flutter test` or `./gradlew test`) to confirm it fails. Do NOT write production code yet.

## Step 2: GREEN (Make it Pass)
1. Write the absolute minimum production code required to make the failing test pass.
2. Do not add speculative features or optimize yet.
3. Re-run the test to confirm it turns green.

## Step 3: REFACTOR (Clean it Up)
1. Refactor the passing code to improve readability, enforce immutability, and remove duplication.
2. Ensure you follow `rules/common/coding-style.md`.
3. Re-run all tests to ensure they stay green after refactoring.