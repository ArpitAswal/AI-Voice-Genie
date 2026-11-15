---
description: Deeply analyze a new requirement against the current architecture, evaluate edge cases, and propose solutions with pros and cons before writing any code.
---

1. Load `personas/analyzer.md` and `personas/architect.md`.
2. Load the active platform rules from `rules/platforms/`.
3. Read the user's requirement and any provided input data/samples. Do NOT generate production code.
4. Critically evaluate the requirement against the current codebase architecture. Do not blindly accept the user's proposed approach; if it lacks scalability, breaks separation of concerns, or introduces heavy technical debt, challenge it and propose a better pattern.
5. Output a structured Architectural Report containing:
   - **Current State & Limitations**: How the app currently works and why it struggles with the new requirement.
   - **Proposed Solutions**: Provide 2-3 approaches to solve the problem. For each, list concrete **Pros** and **Cons** (factor in performance, maintainability, and platform idioms).
   - **Architect's Recommendation**: The single best approach and why it wins.
   - **High-Level Implementation Plan**: How the recommended solution maps to the data layer, domain layer, and UI layer.
6. Pause and wait for the user to select or refine a solution before moving to `/plan` or implementation.