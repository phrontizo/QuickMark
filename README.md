# QuickMark

A macOS QuickLook extension that renders Markdown, draw.io, and structured data files with full formatting — select a file in Finder, press Space, and get a rich preview instead of raw text.

## Why

macOS has no built-in Markdown preview. QuickLook shows `.md` files as plain text, which is useless for documents with diagrams, code, or math. Similarly, structured data files (JSON, YAML, TOML) and draw.io diagrams get no syntax highlighting or visual rendering. Existing solutions either cost money, lack features, or haven't been updated for recent macOS versions. QuickMark fills this gap as a lightweight, open-source alternative.

## What it renders

### Markdown

- **Formatted Markdown** — headings, lists, tables, blockquotes, links, images
- **Syntax-highlighted code blocks** — via highlight.js
- **LaTeX math** — inline (`$...$`) and display (`$$...$$`) via KaTeX + texmath
- **Mermaid diagrams** — flowcharts, sequence diagrams, etc.
- **Task lists & footnotes** — via markdown-it plugins
- **Embedded draw.io diagrams** — `![diagram](file.drawio)` references rendered inline, with optional fragment to select a page by name (`![](file.drawio#Key Derivation)`) or 0-based index (`![](file.drawio#2)`)
- **Local images** — SVG, PNG, JPEG, GIF, WebP resolved from relative paths
- **Linked Markdown files** — clicking a `.md` link renders the target inline
- **Dark mode** — adapts to system appearance

### Draw.io

- **All diagram types** — UML, BPMN, network, flowcharts, ERD, architecture diagrams, etc.
- **Auto-fit to window** — diagram scales to fit the QuickLook window
- **Pinch-to-zoom** — native trackpad zoom with scrollbars when zoomed
- **Multi-page diagrams** — named tab bar for switching pages
- **Dark mode** — adapts to system appearance

### Structured Data

- **JSON, YAML, TOML, XML** — syntax-highlighted previews
- **Line numbers** — for easy reference
- **Dark mode** — adapts to system appearance

## Install

Download the latest DMG from [Releases](https://github.com/phrontizo/QuickMark/releases), open it, and drag QuickMark to Applications. Then open QuickMark and follow the prompts to enable the extensions in System Settings.

## Requirements

- macOS 14.0+
- Xcode 15.3+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Building

```bash
# Generate the Xcode project
xcodegen generate

# Download JS/CSS dependencies (run once)
./scripts/download-libs.sh

# Open in Xcode and build
open QuickMark.xcodeproj
```

Build and run the **QuickMark** scheme. The host app shows the status of all three extensions and links to System Settings if any need enabling.

## How it works

QuickMark is a macOS app bundle containing three QuickLook preview extensions:

**Markdown Preview** — when Finder invokes QuickLook on a `.md` file:

1. **PreviewViewController** reads the file from disk
2. **MarkdownProcessor** resolves draw.io references (converted to fenced code blocks)
3. **HTMLBuilder** assembles an HTML page referencing bundled JS/CSS by URL, with a `<base>` tag for relative image paths
4. The HTML is loaded via `WKWebView.loadFileURL` for local file access
5. **render.js** (client-side) parses the Markdown with markdown-it and its plugins

**Draw.io Preview** — when Finder invokes QuickLook on a `.drawio` file:

1. **PreviewViewController** reads the XML and embeds it in an HTML page with viewer-static.min.js
2. The diagram is rendered, measured, and scaled to fit the QuickLook window
3. `preferredContentSize` is set from the diagram dimensions so the window opens at the right size

**Structured Data Preview** — when Finder invokes QuickLook on a `.json`, `.yaml`/`.yml`, `.toml`, or `.xml` file:

1. **PreviewViewController** reads the file and applies syntax highlighting via highlight.js
2. Line numbers are added for easy reference
3. The result is rendered in a WKWebView with light/dark theme support

All rendering happens locally with no network requests.

## Project structure

```
QuickMark/                  # Host app (SwiftUI)
Shared/                     # Code shared between extensions
SharedResources/            # Resources shared between extensions
Markdown/                   # Markdown QuickLook extension
  ├── PreviewViewController.swift
  ├── MarkdownProcessor.swift
  ├── HTMLBuilder.swift
  └── Resources/            # JS/CSS dependencies + render.js
DrawIO/                     # Draw.io QuickLook extension
  └── PreviewViewController.swift
Structured/                 # Structured data QuickLook extension (JSON/YAML/TOML/XML)
  ├── PreviewViewController.swift
  └── Resources/            # structured-render.js, structured-style.css
QuickMarkTests/             # Unit + integration tests
project.yml                 # XcodeGen project definition
```

## Licence

MIT — see [LICENCE.txt](LICENCE.txt).
