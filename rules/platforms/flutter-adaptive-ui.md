# Adaptive Flutter UI Engineering Rules

> **Activation**: Apply whenever creating, refactoring, or reviewing responsive/adaptive Flutter screens across Mobile, Tablet, and Desktop viewports.

## 1. Responsive Breakpoints & Constraint Logic

- **Shell vs. Component Constraints:**
  - Use `MediaQuery.sizeOf(context)` and `MediaQuery.orientationOf(context)` at the top-level screen scaffold to decide macro-composition (e.g., single-pane vs. split-pane, bottom nav vs. side rail) based only on orientations enabled in the app's configuration[cite: 6].
  - Use `LayoutBuilder` for inner sections, forms, cards, and grids so widgets adapt to their actual parent space rather than global device flags[cite: 6].
- **Standard Viewport Envelopes:**
  - **Compact (`width < 600` OR `height <= 550`):**
    - Single vertical scrollable column[cite: 6].
    - The `height <= 550` rule protects landscape phones, split-screen windows, and small viewports from vertical crushing[cite: 6]. When triggered, reduce vertical gaps, collapse decorative headers, and enforce scrollability[cite: 6].
  - **Landscape Phone Guard:** If `orientation == Orientation.landscape` but `height <= 550` (or `constraints.maxHeight <= 550`), treat the device strictly as **Compact** (single-column scrollable), NEVER as Expanded (2-column desktop)[cite: 6].
  - **Medium (`width >= 600 && width <= 840` AND `height > 550`):**
    - Center primary forms or narrow content inside a `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600))` so fields and buttons never stretch unnaturally across tablet portraits[cite: 6].
    - Use `Wrap` or responsive `GridView` (`SliverGridDelegateWithMaxCrossAxisExtent`) for multi-card content[cite: 6].
  - **Expanded (`width > 840` AND `height > 550`):**
    - Multi-pane composition (e.g., `Row` with two `Expanded` panes: a hero/context pane on the left and a `ConstrainedBox(maxWidth: 480)` form/content pane on the right, or an adaptive multi-column dashboard)[cite: 6].
    - For tablet and desktop breakpoints, prioritize visual balance and screen real estate. Do not leave large empty columns in the centre; use responsive grids to distribute cards evenly and anchor primary action buttons (like a microphone) as FABs or within the nav rail.

## 2. Dynamic Spacing, Padding & Margin

- **No Rigid Pixel Gaps:** Never use large fixed `SizedBox(height: 80)` spacers that break on smaller screens or when the keyboard opens[cite: 6].
- **Adaptive Spacing Math:** Calculate padding and gaps dynamically from available constraints or project spacing tokens[cite: 6]:
  - *Compact / Short Height (`height <= 550`):* Horizontal padding `16dp`, vertical padding `12dp–16dp`, item gaps `12dp`[cite: 6].
  - *Medium:* Horizontal padding `24dp–32dp`, vertical padding `24dp`, item gaps `16dp–20dp`[cite: 6].
  - *Expanded:* Horizontal padding `32dp–48dp`, vertical padding `32dp`, item gaps `20dp–24dp`[cite: 6].
- **Consume Project Extensions & Avoid Floating Math:** Always prioritize using the project's centralized `BuildContext` extensions: `context.isCompact`, `context.isMedium`, `context.isExpanded`, `context.horizontalPadding`, `context.verticalSpacing`, `context.iconDense`, `context.iconStandard`, `context.iconAvatar`[cite: 6]. Never use raw floating-point percentage math on child dimensions (e.g., `maxWidth * 0.1` or `maxWidth * 0.01`)[cite: 6].

## 3. Scrolling & Keyboard Safety

- **Content-Driven Scrolling:** Always evaluate whether child widgets can exceed available vertical space—especially when the virtual keyboard opens (`MediaQuery.viewInsetsOf(context).bottom > 0`) or system font scaling is enlarged[cite: 6].
- **Overflow Prevention:**
  - Wrap forms and vertical flows in `SingleChildScrollView(physics: const ClampingScrollPhysics())` or `CustomScrollView` with `SliverFillRemaining(hasScrollBody: false)` when bottom-pinned buttons are needed[cite: 6].
  - Never place an unconstrained `Expanded` inside a `SingleChildScrollView` unless wrapped in `LayoutBuilder` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight`[cite: 6].
  - Never introduce nested vertical scrollables along the same axis without explicit physics management[cite: 6].

## 4. Reuse of Project Theme, Localization & Utilities

- **Inspect Before Creating:** Before writing custom styling or helper math, check the codebase for existing[cite: 6]:
  - Theme tokens (`Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, custom theme extensions)[cite: 6].
  - Localization files (`AppLocalizations`, `.arb` delegates, string constants)[cite: 6]. Never hardcode raw UI strings if localization is active[cite: 6].
  - Existing `BuildContext` extensions, spacing utilities, or custom shared widgets[cite: 6].
- **Light & Dark Mode Parity:** Consume semantic color roles (`surface`, `onSurface`, `primary`, `outlineVariant`)[cite: 6]. When placing text over background images, always apply a contrast scrim or themed card surface[cite: 6].
- **Touch Targets & Typography:** Keep interactive tap targets at a minimum of `48x48dp`[cite: 6]. Respect system `TextScaler` without clamping font sizes[cite: 6].
- **Zero-Padding Touch Targets & Feedback:** Do not use raw `GestureDetector` on clickable actions[cite: 6]. Wrap custom buttons in `InkWell` or `IconButton` with `constraints: BoxConstraints(minWidth: 48, minHeight: 48)` and `padding: EdgeInsets.zero` to ensure accessible tap areas, ink ripple feedback on mobile, and hover/focus states on desktop/web[cite: 6].

## 5. State Management & Rebuild Discipline

- **Follow the Project's Existing Pattern:** Inspect what the project uses (`Provider`, `Riverpod`, `Bloc`, `GetX`, or `ValueNotifier`) and strictly adhere to it[cite: 6].
- **Narrow Rebuild Boundaries:**
  - Trigger methods and events using non-listening access (e.g., `context.read<T>()`)[cite: 6].
  - Wrap only the specific leaf widget that needs updating in `Selector`, `context.select`, `BlocSelector`, or `ValueListenableBuilder`[cite: 6].
  - Never call `setState` at the top of a screen if it forces background images, layout shells, or unaffected form fields to rebuild[cite: 6]. If no external state management is used for a local UI toggle (e.g., password visibility), isolate it inside a dedicated small stateful child widget or `ValueNotifier`[cite: 6].

## 6. Clean Code, Modularity & Verification Scope

- **Break Down Large Files:** Keep the main screen widget focused on high-level layout switching[cite: 6]. Extract distinct sections (Header, FormCard, ActionButtons, SideBanner) into private `_Widget` classes or separate files in the feature's `widgets/` folder[cite: 6].
- **Comment Every Key Decision:** Add concise inline comments explaining[cite: 6]:
  1. Why a specific breakpoint or `height <= 550` branch is triggered[cite: 6].
  2. How keyboard insets and scrolling are handled[cite: 6].
  3. Which state slice a `Selector` or listener is observing[cite: 6].
- **UI-Pass Verification Boundary:** During a dedicated adaptive UI refactor pass, do not create, edit, or run widget/unit tests unless explicitly requested; verify layout changes via `dart format` and `flutter analyze`[cite: 6].