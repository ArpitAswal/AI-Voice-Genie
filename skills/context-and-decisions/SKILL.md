---
name: context-and-decisions
description: Checklist for updating the project's context.md file to maintain long-term architectural memory.
---

# Context & Decisions Logging Workflow

Execute this workflow whenever a major architectural decision is made, a new core library is added, or the project phase changes.

## Step 1: Read Current Context
1. Locate and read `context.md` at the root of the project. 
2. If it does not exist, create it using the template structure (Stack & Architecture, Key Decisions, Current Focus).

## Step 2: Append New Decisions
1. Add the new technical decision to the "Key Decisions" table. Include the Date, the Decision, and the Rationale.
2. Update the "Current Focus" section to reflect the active sprint or task.

## Step 3: Prune & Format
1. Ensure `context.md` remains highly concise (strictly under 150 lines).
2. Remove outdated "Current Focus" items.
3. Do not store code snippets or verbose explanations here; keep it restricted to high-level architecture rules.