# Feature Parity with QL-Win/QuickLook

**Date:** 2026-03-18
**Status:** Draft

## Overview

Add six features to QuickMark that QL-Win/QuickLook already provides, closing the feature gap for markdown rendering and expanding structured data coverage. Each feature is an independent commit. CSV/TSV table preview is deferred to a potential 1.3 release.

## Features

### 1. Heading Anchors

**Goal:** Generate stable `id` attributes on all headings (h1-h6) so they can be linked to from the ToC and fragment URLs.

**Changes:**
- Add `markdown-it-anchor` plugin — download `dist/markdownItAnchor.umd.js` from CDN (unminified, ~6.5 KB, small enough to use as-is). Pin version with SHA-256 hash via `download-libs.sh`.
- `HTMLBuilder.swift`: add `<script>` tag in `scriptResources` after other markdown-it plugins but before `render.js` (render.js is an IIFE that runs immediately, so all plugins must be loaded first)
- `render.js`: initialise `md.use(markdownItAnchor, { slugify })` with a Unicode-aware slugify function (important for RTL content). The slugify function must avoid producing `id` values that collide with existing element IDs (`content`, `toc`, `markdown-source`) — use a `heading-` prefix.
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
  - `IntersectionObserver` on headings with `rootMargin: "0px 0px -70% 0px"` highlights the heading nearest the top of the viewport. Active item gets `.active` class. The ToC auto-scrolls to keep the active item visible.
  - Mousedown near the ToC right edge (inline-end) starts resize drag; width saved to `localStorage` and restored on load. **Note:** `localStorage` persistence in WKWebView sandbox is best-effort (file:// origins may be treated as opaque). The CSS default (`--toc-width: 220px`) must work as a sensible fallback when the saved value is unavailable.
  - Hide ToC if fewer than 2 headings
- `style.css`:
  - `body { display: flex }` when ToC is visible
  - `#toc { position: sticky; top: 0; height: 100vh; overflow-y: auto; width: var(--toc-width) }`
  - Article remains `max-width: 880px` in the flex content area
  - Hide ToC when viewport is below ~1000px to avoid squishing content (QuickLook windows can be narrow)
  - Use CSS logical properties (`margin-inline-start`, `border-inline-start`) from the start to support RTL flipping (feature 5)
- `HTMLBuilder.swift`: add `<nav id="toc"></nav>` before `<article>` in the `assembleHTML()` method (not just `build()`) so tests that call `assembleHTML` directly also have the ToC container

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

**Approach:** The `markdown-it-github-alerts` npm package is ESM-only with no UMD/IIFE browser bundle. Since QuickMark loads all scripts as classic `<script>` tags with no bundler, we implement the alert parsing as a **custom markdown-it plugin directly in `render.js`**. The transformation is straightforward: detect `[!TYPE]` at the start of a blockquote's first paragraph token, rewrite the token tree to wrap in an alert container with the appropriate class. This avoids the dependency entirely and keeps class naming under our control.

**Changes:**
- `render.js`: custom markdown-it plugin function that:
  - Hooks into `core` rules after parsing
  - Finds `blockquote_open` tokens where the first inline content starts with `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, or `[!CAUTION]`
  - Wraps the blockquote in a `<div class="markdown-alert markdown-alert-note">` (etc.)
  - Strips the `[!TYPE]` marker from the rendered text
- `style.css`: alert-type-specific styling:
  - NOTE: blue left border
  - TIP: green left border
  - IMPORTANT: purple left border
  - WARNING: yellow left border
  - CAUTION: red left border
  - Dark mode variants via `prefers-color-scheme`

**No new dependencies. No changes to `THIRD-PARTY-NOTICES`.**

**Testing:** Rendering test with a `[!WARNING]` blockquote, verifying the correct alert class is applied.

**Dependencies:** None.

---

### 4. Target Heading Animation

**Goal:** Brief highlight fade when navigating to a heading via hash link (ToC click or fragment URL).

**Approach:** Use a `.targeted` class as the primary mechanism (not `:target`), because the ToC uses `scrollIntoView({ behavior: 'smooth' })` which does not change `location.hash` and therefore does not trigger `:target`.

**Changes:**
- `render.js`: ToC click handler adds `.targeted` class to the destination heading, removes it after the animation completes (~1 second) via `animationend` event listener
- `style.css`: `.targeted` class with `@keyframes` animation — background fades from `--link` at 20% opacity to transparent over ~1 second

**No new dependencies.**

**Testing:** Low risk — manual verification. Could optionally assert the CSS class is applied in a rendering test.

**Dependencies:** Feature 1 (heading anchors). Best implemented alongside feature 2 (ToC).

---

### 5. RTL Text Direction

**Goal:** Correct rendering of Arabic, Hebrew, Persian, and other RTL markdown, with the ToC flipping to the right side.

**Changes:**
- `render.js`: after rendering, inspect the first meaningful text content for RTL Unicode ranges:
  - Arabic: `\u0600-\u06FF`
  - Arabic Supplement/Extended: `\u0750-\u077F`, `\u08A0-\u08FF`
  - Hebrew: `\u0590-\u05FF`
  - Thaana: `\u0780-\u07BF`
  - Syriac: `\u0700-\u074F`
  - If predominantly RTL, set `dir="rtl"` on `<html>`
- `style.css`: convert any remaining physical properties to CSS logical equivalents (most should already be logical from feature 2):
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
- Verify at runtime that `hljs.getLanguage('xml')` is truthy (XML is in the default highlight.js common bundle)

**UTType precedence note:** The custom UTType `com.jgraph.drawio` conforms to `public.xml`. macOS will prefer the more specific UTType for `.drawio` files, so they will continue to be handled by the DrawIO extension, not Structured. No conflict.

**No new dependencies, no CSS changes, no new files.**

**Testing:** Rendering test loading an XML file, verifying syntax highlighting classes.

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

After implementation, update `CLAUDE.md` to document the new features and patterns (ToC, CSS logical properties).

## Security

- All new markdown-it plugins run with `html: false` — no change to the security model
- `markdown-it-anchor` slugify uses a `heading-` prefix to avoid `id` collisions with existing elements (`content`, `toc`, `markdown-source`)
- GitHub Alerts implemented as a custom plugin (no external dependency) operating within the markdown-it token stream
- New library (markdown-it-anchor) pinned with SHA-256 hash via `download-libs.sh`
- No new network access or entitlement changes required

## New Dependencies

| Library | Licence | Used by |
|---|---|---|
| markdown-it-anchor | MIT | Heading anchors |
