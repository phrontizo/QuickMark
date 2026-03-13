# QuickMark

A macOS QuickLook extension that renders Markdown files with full formatting — select a `.md` file in Finder, press Space, and get a rich preview instead of raw text.

## Why

macOS has no built-in Markdown preview. QuickLook shows `.md` files as plain text, which is useless for documents with diagrams, code, or math. Existing solutions either cost money, lack features, or haven't been updated for recent macOS versions. QuickMark fills this gap as a lightweight, open-source alternative.

## What it renders

- **Formatted Markdown** — headings, lists, tables, blockquotes, links, inline HTML
- **Syntax-highlighted code blocks** — via highlight.js
- **LaTeX math** — inline (`$...$`) and display (`$$...$$`) via KaTeX + texmath
- **Mermaid diagrams** — flowcharts, sequence diagrams, etc.
- **Task lists & footnotes** — via markdown-it plugins
- **Draw.io diagrams** — embedded `.drawio` file references rendered inline
- **Local images** — SVG, PNG, JPEG, GIF, WebP resolved from relative paths
- **Dark mode** — adapts to system appearance
- **Linked Markdown files** — clicking a `.md` link renders the target inline

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

Build and run the **QuickMark** scheme. The host app shows whether the extension is active and links to System Settings if it needs enabling.

## How it works

QuickMark is a macOS app bundle containing a QuickLook preview extension (`.appex`). When Finder invokes QuickLook on a Markdown file:

1. **PreviewViewController** reads the `.md` file from disk
2. **MarkdownProcessor** resolves draw.io references (inlined as viewer divs)
3. **HTMLBuilder** assembles a self-contained HTML page with all JS/CSS inlined
4. A `<base>` tag is injected so relative image paths resolve correctly
5. The HTML is loaded via `WKWebView.loadFileURL` for local file access
6. **render.js** (client-side) parses the Markdown with markdown-it and its plugins

All rendering happens locally with no network requests.

## Project structure

```
QuickMark/                  # Host app (SwiftUI)
QuickMarkPreview/           # QuickLook extension
  ├── PreviewViewController.swift
  ├── MarkdownProcessor.swift
  ├── HTMLBuilder.swift
  └── Resources/            # JS/CSS dependencies + render.js
QuickMarkTests/             # Unit tests
project.yml                 # XcodeGen project definition
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
