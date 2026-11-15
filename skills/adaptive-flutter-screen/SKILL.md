---
name: adaptive-flutter-screen
description: Step-by-step execution checklist for auditing, modularizing, coding, and verifying an adaptive Flutter screen across Mobile, Tablet, and Desktop.
---

# Adaptive Flutter Screen Execution Workflow

Follow this exact 4-step pipeline for every screen request[cite: 7]:

## Step 1: Non-Destructive Project & Screen Discovery
1. **Verify Target Path & Mode:**
   - **Refactor Mode (File Exists):** Open the target screen Dart file and trace its direct widget hierarchy, controllers, and state listeners[cite: 7].
   - **Greenfield Mode (New Screen):** Create the target Dart file under the feature's presentation folder, establish state providers/controllers, and register the route[cite: 7].
2. **Audit Project Capabilities:**
   - Check `main.dart`, `AndroidManifest.xml`, and `Info.plist` for locked vs. unlocked device orientations[cite: 7].
   - Check for existing theme files, `BuildContext` extensions, responsive helpers, and localization delegates[cite: 7].
   - Identify the state management solution used by the feature[cite: 7].
3. **Identify Preservation Targets (Refactor Mode):** List all existing callbacks, navigation calls, controllers, and business logic that must remain untouched[cite: 7].

## Step 2: Responsive Layout Planning
Map the screen components against the blueprint in `skills/adaptive-flutter-screen/templates/design.md` (do not overwrite `design.md`)[cite: 7]:
1. **Compact (`width < 600 || height <= 550`):** Plan a single scrollable column with compact dynamic spacing (`12dp–16dp`) and safe keyboard clearance[cite: 7].
2. **Medium (`600 <= width <= 840 && height > 550`):** Plan a centered, width-constrained layout (`maxWidth: 600`) or responsive `Wrap`/`Grid` with medium dynamic spacing (`20dp–24dp`)[cite: 7].
3. **Expanded (`width > 840 && height > 550`):** Plan a split-screen or multi-pane layout (`Row` + `Expanded` + constrained content panes) that balances visual anchors with ergonomic reading/input widths[cite: 7].

## Step 3: Modular & Commented Code Implementation
1. **Modularize:** Split bulky UI trees into clean, `const`-friendly sub-widgets or separate local widget files so there is minimal boilerplate[cite: 7].
2. **Apply Dynamic Spacing & Scroll Safety:** Use `LayoutBuilder` constraints to scale paddings/gaps smoothly, and wrap content in `SingleChildScrollView` / `CustomScrollView` to handle small heights and keyboard popups[cite: 7].
3. **Wire State & Theme:** Connect existing state via narrow selectors (`context.select` / `Selector` / `BlocSelector` / `ValueListenableBuilder`) and apply semantic `Theme.of(context)` colors and text styles[cite: 6, 7].
4. **Document in Code:** Add clear inline comments (`// ...`) above responsive branches, dynamic spacing helpers, and state bindings[cite: 7].

## Step 4: Static Verification & Handover
1. Run `dart format <modified_files>` to ensure clean formatting[cite: 7].
2. Run `flutter analyze <modified_files>` to verify zero syntax, typing, or unused-import issues[cite: 7].
3. Run through this final self-check before responding[cite: 7]:
   - [ ] Existing business logic, controllers, and routes are 100% preserved[cite: 7].
   - [ ] `templates/design.md` was NOT overwritten with screen-specific hardcoded data[cite: 7].
   - [ ] `width < 600 || height <= 550` is properly handled without vertical or horizontal overflow[cite: 7].
   - [ ] Existing localization, theme tokens, and helper extensions are reused[cite: 7].
   - [ ] Code is split into clean sub-widgets with inline explanatory comments[cite: 7].
4. Output a brief summary of changes and stop for user review[cite: 7].