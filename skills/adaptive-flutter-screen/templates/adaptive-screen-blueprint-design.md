---
name: adaptive-screen-blueprint-design
description: Read-only structural blueprint used to plan responsive layouts per screen. Do not overwrite this file with hardcoded screen data.
---

# Adaptive Screen Blueprint Schema (Read-Only Template)

> **IMPORTANT AGENT RULE:** Do NOT overwrite or edit this file with specific screen paths or hardcoded UI details[cite: 5]. Use this template as your internal planning structure before refactoring the target Dart file[cite: 5].

## 1. Screen Context & Preservation Contract
- **Target Dart File:** `<path_to_target_screen.dart>`[cite: 5]
- **Visual / Audit Source:** `<Side-Window Audit Notes | Figma/Screenshot | Widget-Tree Extraction>`[cite: 5]
- **Preserved Logic & Controllers:** `<List all controllers, callbacks, routes, and state providers that must not be broken>`[cite: 5]
- **Project Utilities Reused:** `<Theme tokens, L10n delegates, responsive extensions, shared widgets>`[cite: 5]

## 2. Responsive Composition Matrix

| Viewport Tier | Condition | Layout Structure | Dynamic Spacing (Pad / Gap) | Scroll & Keyboard Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Compact / Short** | `width < 600 \|\| height <= 550` | Single vertical column; collapse or backdrop-scrim heavy imagery | Horizontal: `16dp`<br>Vertical: `12–16dp`<br>Gap: `12dp` | Full `SingleChildScrollView`; pad bottom by `viewInsets.bottom` |
| **Medium (Tablet Portrait)** | `600 <= width <= 840 && height > 550` | Centered `ConstrainedBox(maxWidth: 600)` or 2-column `Wrap`/Grid | Horizontal: `24–32dp`<br>Vertical: `24dp`<br>Gap: `16–20dp` | Contained scrollable card/column |
| **Expanded (Desktop / Tablet Landscape)** | `width > 840 && height > 550` | 2-pane `Row` (`Expanded` visual/overview pane + constrained content pane) | Horizontal: `32–48dp`<br>Vertical: `32dp`<br>Gap: `20–24dp` | Independent scrollable content pane |

## 3. Modular Widget Breakdown Plan
- **Primary Screen Shell:** Handles `LayoutBuilder` / `MediaQuery` breakpoint switching and scaffold background[cite: 5].
- **Extracted Sub-Widgets (Private or Local Files):**
  - `_HeaderSection` / `_BrandingPane`: Visual anchor and titles[cite: 5].
  - `_MainContentSection` / `_FormSection`: Core interactive fields and cards[cite: 5].
  - `_ActionFooter`: Primary CTAs and secondary actions with `>= 48dp` touch targets[cite: 5].