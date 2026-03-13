# QuickMark — Design Spec

## Overview

A clean, from-scratch macOS QuickLook extension for markdown files. Uses a JavaScript rendering stack running in WKWebView, with zero native dependencies.

## Goals

- Preview markdown files in Finder QuickLook with full GFM support
- Render SVG images, mermaid diagrams, LaTeX math, draw.io diagrams, and syntax-highlighted code blocks
- Clicking a link to another `.md` file opens QuickLook on that file
- Minimal host app (required to install the extension, nothing more)
- Zero C code, zero submodules, zero autotools

## Non-Goals

- User-configurable settings or preferences UI
- CLI tool
- Thumbnail generation
- Remote image fetching

---

## Architecture

```
QuickMark.app
├── QuickMark (host app target)
│   └── Minimal SwiftUI app — "Extension installed" screen
└── QuickMarkPreview (QuickLook extension target, .appex)
    ├── PreviewViewController.swift — QLPreviewingController
    ├── Resources/
    │   ├── preview.html          — HTML template
    │   ├── markdown-it.min.js    — Markdown parser
    │   ├── highlight.min.js      — Syntax highlighting
    │   ├── mermaid.min.js        — Diagram rendering
    │   ├── katex.min.js + CSS    — LaTeX math
    │   ├── drawio-viewer.min.js  — draw.io diagram rendering
    │   └── style.css             — Light/dark theme
    └── Info.plist
```

Two Xcode targets. No SPM dependencies. No XPC services. All JS libraries bundled as static resources.

---

## Rendering Pipeline

### Step 1: Load markdown file

`PreviewViewController` receives the file URL from QuickLook. It reads the markdown text as UTF-8.

### Step 2: Resolve local assets

Before passing markdown to the JS renderer, the extension resolves local image/asset references to absolute `file://` paths. This is necessary because the HTML is loaded without a meaningful base URL in the data-based preview path.

For standard images (png, jpg, gif, svg): rewrite relative paths to absolute `file:///` URLs.

For `.drawio` files referenced as images (`![](diagram.drawio)`): read the XML content, base64-encode it, and replace the image reference with a `<div class="mxgraph" data-mxgraph="...">` block.

This rewriting happens in Swift before the HTML is assembled.

### Step 3: Build HTML document

Assemble a complete HTML document:

```
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>[bundled CSS]</style>
  <link rel="stylesheet" href="[katex.min.css]">
</head>
<body>
  <article id="content"></article>
  <script>[markdown-it.min.js]</script>
  <script>[highlight.min.js]</script>
  <script>[katex.min.js]</script>
  <script>[mermaid.min.js]</script>
  <script>[drawio viewer.min.js]</script>
  <script>
    const md = markdownit({ html: true, highlight: ... });
    // register plugins
    document.getElementById('content').innerHTML = md.render(`MARKDOWN_CONTENT`);
    mermaid.initialize({ startOnLoad: true, theme: ... });
  </script>
</body>
</html>
```

All JS and CSS is inlined into the HTML string — no external file loads needed.

### Step 4: Return to QuickLook

On macOS 12+: return HTML data via `QLPreviewReply(dataOfContentType: .html, ...)`.

On older macOS: load HTML into WKWebView via `loadHTMLString(_:baseURL:)` with the file's parent directory as base URL.

---

## Feature Details

### Images (including SVG)

Local image paths are rewritten to absolute `file:///` URLs in the Swift preprocessing step. SVGs render natively in HTML — no base64 encoding, no MIME detection, no libmagic.

For the `QLPreviewReply` path (macOS 12+), images need to be base64-encoded as data URIs since there's no base URL. SVGs are inlined directly as `<svg>` elements for better rendering fidelity. Raster images are base64-encoded as `data:image/png;base64,...` etc.

MIME type is determined by file extension (a simple Swift dictionary mapping) — no libmagic needed.

### Mermaid Diagrams

Mermaid code blocks (` ```mermaid `) are detected by markdown-it's fence renderer. The code block content is placed in a `<div class="mermaid">` and mermaid.js renders it after page load. Theme (light/dark) is set based on `prefers-color-scheme`.

### Math (LaTeX)

KaTeX is used for LaTeX rendering (faster than MathJax, fully bundleable). Inline math (`$...$`) and display math (`$$...$$`) are handled via a markdown-it plugin (`markdown-it-katex` or equivalent). KaTeX CSS and fonts are bundled.

### Syntax Highlighting

highlight.js runs inside markdown-it's `highlight` option. When markdown-it encounters a fenced code block, it passes the code and language hint to highlight.js, which returns highlighted HTML. Common language grammars are bundled.

### Draw.io Diagrams

When preprocessing detects an image reference ending in `.drawio`:
1. Read the XML file content
2. Encode as a data attribute
3. Replace the markdown image with an HTML div: `<div class="mxgraph" data-mxgraph='{"xml":"..."}'></div>`
4. The diagrams.net viewer JS renders it

### Markdown Link Navigation

`WKNavigationDelegate.webView(_:decidePolicyFor:)` intercepts link clicks:
- Links to `.md` files: cancel navigation, open QuickLook on the linked file
- Links to other local files: cancel, open with default app via `NSWorkspace`
- External URLs: cancel, open in default browser via `NSWorkspace`

For the `QLPreviewReply` path (no WKWebView), link interception is handled by injecting JavaScript that intercepts clicks and communicates via a custom URL scheme or `window.webkit.messageHandlers`.

### Supported File Types

Same UTI list as current project:
- `public.markdown`, `net.daringfireball.markdown`, `net.ia.markdown`
- `com.unknown.md`, `io.typora.markdown`, `com.nutstore.down`
- `com.rstudio.rmarkdown`, `org.quarto.qmarkdown`
- `org.apiblueprint.file`, `org.textbundle.package`

### Light/Dark Mode

Single CSS file using `@media (prefers-color-scheme: dark)`. Mermaid theme switches between `default` and `dark`. highlight.js theme switches similarly. No user configuration needed.

---

## Host App

Minimal SwiftUI application:
- Single screen: app icon, name, brief instructions ("This app provides a QuickLook preview extension for Markdown files. It's already active — just select a .md file in Finder and press Space.")
- No preferences, no settings, no menu items beyond defaults
- Exists solely because macOS requires a host app to distribute an app extension

---

## Project Structure

```
QuickMark/
├── QuickMark.xcodeproj
├── QuickMark/                     # Host app target
│   ├── QuickMarkApp.swift
│   ├── ContentView.swift
│   ├── Assets.xcassets
│   └── Info.plist
├── QuickMarkPreview/              # QuickLook extension target
│   ├── PreviewViewController.swift
│   ├── MarkdownProcessor.swift    # Asset resolution, preprocessing
│   ├── Resources/
│   │   ├── preview.html
│   │   ├── markdown-it.min.js
│   │   ├── markdown-it-*.js       # Plugins (task lists, footnotes, etc.)
│   │   ├── highlight.min.js
│   │   ├── katex.min.js
│   │   ├── katex.min.css
│   │   ├── mermaid.min.js
│   │   ├── drawio-viewer.min.js
│   │   └── style.css
│   ├── Info.plist
│   └── QuickMarkPreview.entitlements
└── docs/
```

---

## Entitlements

**QuickMarkPreview.entitlements:**
- `com.apple.security.app-sandbox: true`
- `com.apple.security.files.user-selected.read-only: true`
- `com.apple.security.temporary-exception.files.absolute-path.read-only: ["/"]` (needed to read images referenced in markdown files anywhere on disk)

**Host app:** default sandbox, no special entitlements.

---

## Bundled JS Libraries

| Library | Purpose | Approximate Size |
|---------|---------|-----------------|
| markdown-it | Markdown → HTML | ~100 KB |
| highlight.js (common langs) | Syntax highlighting | ~300 KB |
| KaTeX | LaTeX math | ~300 KB + fonts |
| mermaid.js | Diagrams | ~1.5 MB |
| diagrams.net viewer | Draw.io rendering | ~2 MB |

Total bundle: ~4 MB. Acceptable for a QuickLook extension.

---

## Testing Strategy

- Manual testing with a collection of markdown files exercising each feature
- Test files: basic GFM, tables, task lists, code blocks (multiple languages), mermaid diagrams, LaTeX math, inline/referenced SVGs, draw.io diagrams, linked .md files
- Light and dark mode verification
- Test with both macOS 12+ data-based preview path and older WKWebView path
