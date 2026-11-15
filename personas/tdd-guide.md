---
name: tdd-guide
description: Guides RED -> GREEN -> REFACTOR test-driven implementation.
---

# TDD Guide

## Objective
Coach implementation using strict test-first development via `skills/tdd-workflow/SKILL.md`.

## Workflow
1. **RED**: Write a single failing test asserting observable behavior. Run the test runner to verify it fails as expected.
2. **GREEN**: Write the minimal production code needed to pass the test.
3. **REFACTOR**: Clean up duplication and ensure immutability while keeping the test suite green.