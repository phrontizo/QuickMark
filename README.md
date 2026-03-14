# QuickMark

A macOS QuickLook extension that renders Markdown and draw.io files with full formatting — select a `.md` or `.drawio` file in Finder, press Space, and get a rich preview instead of raw text.

## Why

macOS has no built-in Markdown preview. QuickLook shows `.md` files as plain text, which is useless for documents with diagrams, code, or math. Existing solutions either cost money, lack features, or haven't been updated for recent macOS versions. QuickMark fills this gap as a lightweight, open-source alternative.

## What it renders

### Markdown

- **Formatted Markdown** — headings, lists, tables, blockquotes, links, inline HTML
- **Syntax-highlighted code blocks** — via highlight.js
- **LaTeX math** — inline (`$...$`) and display (`$$...$$`) via KaTeX + texmath
- **Mermaid diagrams** — flowcharts, sequence diagrams, etc.
- **Task lists & footnotes** — via markdown-it plugins
- **Embedded draw.io diagrams** — `![diagram](file.drawio)` references rendered inline
- **Local images** — SVG, PNG, JPEG, GIF, WebP resolved from relative paths
- **Linked Markdown files** — clicking a `.md` link renders the target inline
- **Dark mode** — adapts to system appearance

### Draw.io

- **All diagram types** — UML, BPMN, network, flowcharts, ERD, architecture diagrams, etc.
- **Auto-fit to window** — diagram scales to fit the QuickLook window
- **Pinch-to-zoom** — native trackpad zoom with scrollbars when zoomed
- **Multi-page diagrams** — page navigation for multi-page files
- **Dark mode** — adapts to system appearance

## Requirements

- macOS 12.0+
- Xcode 15.0+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Building

```bash
# Generate the Xcode project
xcodegen generate

# Download JS/CSS dependencies (run once)
./scripts/fetch-resources.sh

# Open in Xcode and build
open QuickMark.xcodeproj
```

Build and run the **QuickMark** scheme. The host app shows the status of both extensions and links to System Settings if either needs enabling.

## How it works

QuickMark is a macOS app bundle containing two QuickLook preview extensions:

**Markdown Preview** — when Finder invokes QuickLook on a `.md` file:

1. **PreviewViewController** reads the file from disk
2. **MarkdownProcessor** resolves draw.io references (inlined as viewer divs)
3. **HTMLBuilder** assembles a self-contained HTML page with all JS/CSS inlined
4. A `<base>` tag is injected so relative image paths resolve correctly
5. The HTML is loaded via `WKWebView.loadFileURL` for local file access
6. **render.js** (client-side) parses the Markdown with markdown-it and its plugins

**Draw.io Preview** — when Finder invokes QuickLook on a `.drawio` file:

1. **PreviewViewController** reads the XML and embeds it in an HTML page with viewer-static.min.js
2. The diagram is rendered, measured, and scaled to fit the QuickLook window
3. `preferredContentSize` is set from the diagram dimensions so the window opens at the right size

All rendering happens locally with no network requests.

## Project structure

```
QuickMark/                  # Host app (SwiftUI)
Markdown/                   # Markdown QuickLook extension
  ├── PreviewViewController.swift
  ├── MarkdownProcessor.swift
  ├── HTMLBuilder.swift
  └── Resources/            # JS/CSS dependencies + render.js
DrawIO/                     # Draw.io QuickLook extension
  ├── PreviewViewController.swift
  └── Resources/            # viewer-static.min.js
QuickMarkTests/             # Unit tests
project.yml                 # XcodeGen project definition
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
