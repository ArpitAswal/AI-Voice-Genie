---
description: Generate or update project documentation — context.md, README.md, or CHANGELOG.md — with strict quality gates that prevent implementation bloat and ensure every entry is architecture-level.
---

## Step 0 — Quality Gate (Mandatory — Run Before Any Write)

Load `skills/context-and-decisions/SKILL.md` and pass every piece of information through its three filters:

1. **WHY vs WHAT**: Include architectural rationale (why a technology was chosen). Reject implementation mechanics (widget names, pixel math, layout percentages).
2. **Stability**: Include decisions stable over months. Reject volatile data (API pricing, endpoint URLs, sprint-specific details).
3. **Audience**: Include content that orients a developer to the architecture. Reject OS history tutorials and blog-style Q&A sections.

**If any information fails any filter → reject it. Do not write it into the document. Move on.**

---

## Step 1 — Identify Target Document

Determine which document the user needs updated:

| Document | Trigger | Persona to Load |
|---|---|---|
| `context.md` | New library added, architectural pattern changed, project phase shift | `personas/documentation-writer.md` |
| `CHANGELOG.md` | New version being released, feature merged, bug shipped | `personas/documentation-writer.md` |
| `README.md` | New feature visible to external developers, setup steps changed | `personas/documentation-writer.md` |

---

## Step 2 — Read Current State

1. Read the full current content of the target file.
2. Read `context.md` for current project architectural context.
3. For `CHANGELOG.md`: run `git log --oneline -20` to gather commit messages — use them as raw input, then distil them through the quality gate before writing.
4. Never overwrite content that is still accurate.

---

## Step 3 — Write Using Per-Document Rules

### `context.md` Gate
Before adding any row to the Key Decisions table, verify:
- [ ] The entry explains a *why* (trade-off, constraint, choice), not a *what* (class name, widget, pixel value).
- [ ] No pixel dimensions appear (`dp`, `px`, `%` layout ratios).
- [ ] No widget class names appear (`PageView`, `NestedScrollView`, `CustomPainter`, `Consumer`).
- [ ] No chart or drawing implementation details appear.
- [ ] File length stays **under 150 lines** after the addition.

### `CHANGELOG.md` Gate
Before writing any bullet, verify:
- [ ] The bullet describes a **user-visible outcome**, not a code change.
- [ ] No code variable names (`lineEndX`, `outerExtent`, `CustomPainter`).
- [ ] No literal API prices (`\$2.50 prompt`, `\$10.00 completion per 1M tokens`).
- [ ] No pixel math or exact layout ratios (`1×4 KPI row`, `38% left pane`, `380dp max-width`).
- [ ] No enumerated parameter lists (`1:1, 16:9, 9:16` or `Day 01, Day 05… Day 30/31`).
- [ ] No GitHub release artifact prose. Use a hyperlink to the GitHub Releases page.

### `README.md` Gate
Before writing any section, verify:
- [ ] No "Cost Metrics" or pricing column in any feature/model table. State *"costs tracked dynamically"* instead.
- [ ] No tutorial or Q&A section teaching OS history (Android storage deprecation, iOS entitlement explanations). Link to official docs instead.
- [ ] No duplicate feature lists. If a feature is described in one section, it must not be described again under a different heading.
- [ ] No widget-tree-level content in architecture diagrams.

---

## Step 4 — Apply and Review

1. Apply all changes to the target file.
2. Re-read the full file and apply the three filters from Step 0 one final time on the complete output.
3. If any violation survived → fix it before proceeding.

---

## Step 5 — Report and Stop for Review

Output a summary of changes:
- What was added / changed / removed.
- How many quality violations were rejected and what category they fell into (WHY/WHAT, Stability, Audience).
- Current line count for `context.md`.

**Stop here. Do not finalize until the user reviews the summary.**
