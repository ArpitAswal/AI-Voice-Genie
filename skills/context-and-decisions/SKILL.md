---
name: context-and-decisions
description: Protocol for updating context.md, README.md, and CHANGELOG.md with quality-gated, architecture-level content only. Prevents implementation bloat in all project documentation.
---

# Context & Decisions Skill

Execute this skill whenever a major architectural decision is made, a new core library is integrated, the project phase changes, or any project documentation file needs updating.

---

## ⛔ STEP 0 — Quality Classifier (Run Before Every Write)

Before writing a single word to any documentation file, classify each piece of information through the three filters below. **Reject anything that fails.**

### Filter 1 — WHY vs WHAT Test
Ask: *Does this explain a technology choice or trade-off (WHY), or does it describe implementation mechanics (WHAT)?*

| ✅ INCLUDE (WHY) | ❌ REJECT (WHAT) |
|---|---|
| "Chose Provider over Riverpod for lower complexity" | "Using `ChangeNotifierProvider` with `Consumer<T>`" |
| "Hive chosen for zero-network local persistence" | "`HiveType(typeId: 3)` with `HiveField` annotations" |
| "Enforced Material 3 Window Size Classes for tablet scaling" | "38% left pane, 62% right pane split" |
| "Adaptive layout across Mobile/Tablet/Desktop" | "3-page `PageView.builder` with `NestedScrollView`" |

### Filter 2 — Stability Test
Ask: *Is this information stable over months, or will it change with the next feature sprint?*

| ✅ INCLUDE (Stable) | ❌ REJECT (Volatile) |
|---|---|
| "Firebase Auth is the single source of user identity" | "Current sprint: implementing PDF page caching" |
| "All AI keys stored in `flutter_secure_storage`" | "OpenAI GPT-4o costs \$2.50 per 1M prompt tokens" |
| "Crashlytics enabled for non-fatal AI error tracking" | "API endpoint: `https://api.openai.com/v1/chat`" |

### Filter 3 — Audience Test
Ask: *Does this help a developer understand the architecture, or does it teach them general OS/framework history?*

| ✅ INCLUDE | ❌ REJECT |
|---|---|
| "Scoped Storage adopted — no broad storage permission" | "Android 13 deprecated `READ_EXTERNAL_STORAGE` because…" |
| "Dynamic cost tracking — no hardcoded pricing" | "GPT-4o charges \$2.50 prompt / \$10.00 completion per 1M tokens" |
| "Uses Gemini Flash for image generation" | "Gemini Flash supports 1:1, 16:9, 9:16 at 1K, 2K, 4K quality" |

---

## Step 1 — Read Before Writing

1. Locate and read the target file (`context.md`, `README.md`, or `CHANGELOG.md`) in full.
2. If `context.md` does not exist, create it using the template: Stack & Architecture table → Feature Modules table → Key Decisions table → Current Focus list.
3. Never overwrite content that is still accurate. Only append or prune.

---

## Step 2 — Per-Document Writing Rules

### `context.md` Rules
- **Allowed**: Technology name, the alternative rejected, the rationale in one sentence.
- **Forbidden**: Widget class names, pixel values (`380dp`, `44dp`), layout percentages (`38/62`), day/interval enumerations, chart drawing details, and any code that belongs in source comments.
- **Format**: New decisions go in the Key Decisions table as `YYYY-MM | Decision title | One-sentence rationale`.
- **Length gate**: File must stay **strictly under 150 lines**. If adding a row would exceed the limit, prune the oldest "Current Focus" item or merge two related decisions into one row first.

### `CHANGELOG.md` Rules
- Follow Keep-a-Changelog format: `## [version] - YYYY-MM-DD` with `Added / Changed / Fixed / Removed` subsections.
- **Fixed entries must describe user-visible behaviour**, not code mechanics.
  - ❌ `Fixed lineEndX > 0 check in CustomPainter` → ✅ `Fixed trend line rendering direction on narrow screens`
  - ❌ `Resolved NestedScrollView outer-extent physics` → ✅ `Eliminated empty scroll space on mobile boundaries`
- **No code variable names, class names, or method names** in any changelog bullet.
- **No literal API pricing** (`\$2.50 prompt / \$10.00 completion`). Use: `AI cost tracking updated — pricing fetched dynamically`.
- **No pixel math or exact layout ratios** in changelog bullets (`1×4 KPI`, `38% left pane`). Use: `Redesigned dashboard grid for tablet layouts`.
- **No enumerated parameter lists** (`Day 01, Day 05… Day 30/31`). Use: `Chart date axis now adapts to monthly data ranges`.
- **No GitHub release artifact prose** (`Assets Included Below: Please download the APK`). Use a hyperlink to the GitHub Releases page instead.

### `README.md` Rules
- **No "Cost Metrics" or pricing columns** in feature/model tables. If cost tracking is a feature, state: *"Tracks AI usage costs dynamically"* — do not list dollar amounts.
- **No tutorial or Q&A sections** that explain operating system history (Android storage permission deprecation, iOS entitlement changes). Instead, link to official platform documentation.
- **No duplicate feature sections.** If a capability is already described in one section (e.g., Executive Overview), it must not be listed again under a different heading (e.g., Strategic Capabilities). Delete the duplicate section entirely.
- **No implementation detail in architecture diagrams.** Diagrams show layers and flow, not widget trees.

---

## Step 3 — Prune & Format

1. After writing, re-read the full file and apply Filter 1–3 again to the final output.
2. Remove any "Current Focus" items in `context.md` older than the active sprint.
3. Run a final length check on `context.md` — must remain under 150 lines.
4. Confirm no code variable names, pricing data, or OS tutorial content survived the edit.

---

## Step 4 — Report

Output a brief summary table:

| Document | Action | Lines Added | Lines Removed | Quality Issues Rejected |
|---|---|---|---|---|
| `context.md` | Appended 1 decision | 1 | 0 | 2 (pixel math, layout %) |
