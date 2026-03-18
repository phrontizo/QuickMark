# Feature Parity with QL-Win/QuickLook

**Date:** 2026-03-18
**Status:** Draft

## Overview

Add seven features to QuickMark that QL-Win/QuickLook already provides, closing the feature gap for markdown rendering and expanding structured data coverage. Each feature is an independent commit.

## Features

### 1. Heading Anchors

**Goal:** Generate stable `id` attributes on all headings (h1-h6) so they can be linked to from the ToC and fragment URLs.

**Changes:**
- Add `markdown-it-anchor` plugin (pinned version, SHA-256 hash via `download-libs.sh`)
- `HTMLBuilder.swift`: add `<script>` tag after other markdown-it plugins
- `render.js`: initialise `md.use(markdownItAnchor, { slugify })` with a Unicode-aware slugify function (important for RTL content)
- `THIRD-PARTY-NOTICES`: add licence entry

**Testing:** Rendering test verifying headings receive `id` attributes.

**Dependencies:** None. Prerequisite for features 2 and 4.

---

### 2. Table of Contents Sidebar

**Goal:** Sticky left sidebar with scroll tracking, resizable width, and auto-hide for short documents.

**Layout change:** Body becomes `display: flex` with two children: `<nav id="toc">` and the existing `<article id="content">`. When fewer than 2 headings exist, the ToC is hidden and layout falls back to the current single centred column.

**Changes:**
- `render.js`:
  - After markdown-it renders, scan all h1-h6 elements (which have `id` from feature 1)
  - Build nested list, inject into `<nav id="toc">`
  - `IntersectionObserver` on headings highlights the active ToC entry (`.active` class) and auto-scrolls the ToC to keep it visible
  - Mousedown near the ToC right edge starts resize drag; width saved to `localStorage` and restored on load
  - Hide ToC if fewer than 2 headings
- `style.css`:
  - `body { display: flex }` when ToC is visible
  - `#toc { position: sticky; top: 0; height: 100vh; overflow-y: auto; width: var(--toc-width) }`
  - Article remains `max-width: 880px` in the flex content area
  - Collapse/hide ToC below a minimum viewport width to avoid squishing content
  - Use CSS logical properties (`margin-inline-start`, `border-inline-start`) to support RTL flipping (feature 5)
- `HTMLBuilder.swift`: add empty `<nav id="toc"></nav>` before `<article>` in the HTML template

**Considerations:**
- CSS logical properties used from the start so RTL (feature 5) works without rework
- ToC colours reuse `--link` for active state, existing theme variables for backgrounds/borders

**Testing:** Rendering tests verifying:
- ToC element exists and contains correct heading links
- ToC is hidden for a document with only one heading

**Dependencies:** Feature 1 (heading anchors).

---

### 3. GitHub Alerts

**Goal:** Render `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]` blockquote syntax as styled alert boxes.

**Changes:**
- Add `markdown-it-github-alerts` plugin (pinned version, SHA-256 hash)
- `HTMLBuilder.swift`: add `<script>` tag after other markdown-it plugins
- `render.js`: initialise `md.use(markdownItGithubAlerts)`
- `style.css`: alert-type-specific styling:
  - NOTE: blue left border
  - TIP: green left border
  - IMPORTANT: purple left border
  - WARNING: yellow left border
  - CAUTION: red left border
  - Dark mode variants via `prefers-color-scheme`
- `THIRD-PARTY-NOTICES`: add licence entry

**Testing:** Rendering test with a `[!WARNING]` blockquote, verifying the correct alert class is applied.

**Dependencies:** None.

---

### 4. Target Heading Animation

**Goal:** Brief highlight fade when navigating to a heading via hash link (ToC click or fragment URL).

**Changes:**
- `style.css`: `:target` pseudo-class with `@keyframes` animation — background fades from `--link` at 20% opacity to transparent over ~1 second. Falls back gracefully (no animation if unsupported).
- If `:target` proves insufficient with `scrollIntoView`-based ToC navigation, add a `.targeted` class applied/removed in the ToC click handler in `render.js`.

**No new dependencies.**

**Testing:** Low risk — manual verification. Could optionally assert the CSS class is applied.

**Dependencies:** Feature 1 (heading anchors). Best implemented alongside feature 2 (ToC).

---

### 5. RTL Text Direction

**Goal:** Correct rendering of Arabic, Hebrew, Persian, and other RTL markdown, with the ToC flipping to the right side.

**Changes:**
- `render.js`: after rendering, inspect the first meaningful text content for RTL Unicode ranges (`\u0600-\u06FF` Arabic, `\u0590-\u05FF` Hebrew, etc.). If predominantly RTL, set `dir="rtl"` on `<html>`.
- `style.css`: convert physical properties to CSS logical equivalents:
  - `margin-left` -> `margin-inline-start`
  - `border-left` -> `border-inline-start`
  - `padding-left` -> `padding-inline-start`
  - Applies to: blockquotes, lists, ToC sidebar, footnotes
  - Code blocks retain `direction: ltr; text-align: left` for code content, but the block container flows with the document direction (right-aligned in RTL)
- ToC sidebar: flex layout flips automatically with `dir="rtl"` when using logical properties; resize handle moves to the opposite edge

**No new dependencies.**

**Mixed content:** Documents with both LTR and RTL text rely on the browser's Unicode Bidirectional Algorithm. Setting the base direction is sufficient.

**Testing:** Rendering test with Arabic heading text, verifying `dir="rtl"` on the root element.

**Dependencies:** None, but feature 2 (ToC) should use logical properties from the start.

---

### 6. XML Syntax Highlighting

**Goal:** Add `.xml` files to the Structured extension with syntax highlighting and line numbers.

**Changes:**
- `project.yml`: add `public.xml` UTType to QuickMarkStructured's `QLSupportedContentTypes`
- `Structured/PreviewViewController.swift`: map XML UTType to highlight.js `language-xml`

highlight.js already includes XML support. **No new dependencies, no CSS changes, no new files.**

**Testing:** Rendering test loading an XML file, verifying syntax highlighting classes.

**Dependencies:** None.

---

### 7. CSV/TSV Table Preview

**Goal:** New extension target rendering CSV and TSV files as HTML tables.

**New target:** `QuickMarkCSV` in `project.yml`, following the existing extension pattern (App Sandbox, hardened runtime, network entitlement).

**Changes:**
- `CSV/` directory with:
  - `PreviewViewController.swift` — reads file, passes to JS renderer via WKWebView
  - `CSV.entitlements` — same sandbox entitlements as other extensions
  - `Info.plist` — declares supported UTTypes
  - `Resources/render.js` — lightweight CSV parser in JS:
    - Detect delimiter (comma vs tab) by frequency analysis
    - Handle quoted fields with escaped quotes
    - First row treated as header (`<thead>`)
    - Cap at 10,000 rows with "showing first N of M rows" message
  - `Resources/style.css` — reuses existing table styling (alternating rows, borders, cell padding) plus line-number gutter column matching Structured extension style
- `project.yml`:
  - New `QuickMarkCSV` extension target
  - UTTypes: `public.comma-separated-values-text`, `public.tab-separated-values-text`
  - Host app embeds the new extension
- `Shared/AppearancePreference.swift`:
  - Add `csvAppearance` storage key
  - Add `AppearancePreference.csv` computed property (getter/setter)
- `QuickMark/ContentView.swift`:
  - Add fourth column for CSV extension status and appearance picker
- Dark mode via CSS custom properties, same pattern as other extensions

**No third-party dependencies.**

**Testing:** Rendering test loading a CSV file, verifying `<table>` with correct row/column count.

**Dependencies:** None.

---

## Implementation Order

Features are independent commits but should be implemented in this order to avoid rework:

1. **Heading anchors** — prerequisite for 2 and 4
2. **ToC sidebar** — uses logical properties from the start (prepares for 5)
3. **Target heading animation** — layers on top of 1 and 2
4. **GitHub Alerts** — independent
5. **RTL text direction** — converts remaining physical properties to logical
6. **XML syntax highlighting** — independent, trivial
7. **CSV/TSV table preview** — independent, largest scope

## Security

- All new markdown-it plugins run with `html: false` — no change to the security model
- New libraries pinned with SHA-256 hashes via `download-libs.sh`
- CSV parsing is pure JS with no `eval` or `innerHTML` from user content — table cells are text-content only
- No new network access or entitlement changes required

## New Dependencies

| Library | Licence | Used by |
|---|---|---|
| markdown-it-anchor | MIT | Heading anchors |
| markdown-it-github-alerts | MIT | GitHub Alerts |
