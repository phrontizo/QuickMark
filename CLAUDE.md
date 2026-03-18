# QuickMark Development Notes

## Git

Commit automatically after every fix. Pushing and releasing are separate steps — only do them when explicitly instructed.

## WKWebView in Sandboxed Extensions

- **`ENABLE_OUTGOING_NETWORK_CONNECTIONS: YES` is required** for WKWebView to function in a sandboxed QuickLook extension. The WebContent process uses IPC that the sandbox classifies as network activity. Removing this entitlement causes blank/white previews.

- **Content Security Policy (CSP) meta tags don't work reliably** with `loadFileURL()` in sandboxed extensions. File:// origins are treated as opaque — `'self'` doesn't match scripts loaded from the bundle's Resources directory. Don't use CSP in the generated HTML.

- **`allowingReadAccessTo: URL(fileURLWithPath: "/")` is intentional.** The extension needs access to both the temp directory (for the HTML file) and the original file's directory (for images/assets). WKWebView's `loadFileURL` only accepts a single directory. The sandbox entitlement (read-only) limits this to read access.

## Security Model

Security relies on:
1. `html: false` in markdown-it — prevents `<script>`, `<img onerror>`, etc. in crafted .md files
2. URL scheme allowlist (http/https only) — prevents custom scheme abuse via links
3. Pinned library versions with SHA-256 verification — supply chain protection
4. Fenced code blocks for draw.io embedding — avoids raw HTML injection

Do NOT re-add CSP or remove the network entitlement — both break WKWebView rendering.

## Draw.io in Markdown

Draw.io diagrams referenced as `![alt](file.drawio)` are converted to `` ```drawio `` fenced code blocks by `MarkdownProcessor`. An optional fragment selects a page by name or 0-based index: `![](file.drawio#Page Name)` or `![](file.drawio#2)`, producing `` ```drawio page=Page Name ``. The `render.js` fence rule creates a `<div class="mxgraph">` with a tab bar for multi-page diagrams, and uses `GraphViewer.createViewerForElement` with a callback to wire up page switching. This is necessary because `html: false` would escape raw HTML divs injected pre-rendering.

## SharedResources

`SharedResources/` contains resources used by multiple extension targets (`viewer-static.min.js` for Markdown and DrawIO; `highlight.min.js` and `hljs-themes.css` for Markdown and Structured). Each target references the single copy in `project.yml` — Xcode bundles it into each extension at build time. Do NOT duplicate shared resources into individual extension `Resources/` directories.

## Versioning & Releases

Version is managed via `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` build settings in `project.yml`. Info.plist files reference `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` — do NOT hardcode version strings there. XcodeGen regenerates plists from `project.yml`, so version properties must be set in the `info.properties` section of each target.

Releases are tag-driven: push a `v*` tag (e.g., `git tag v1.1.0 && git push origin v1.1.0`) and the release workflow builds, tests, creates a DMG, and publishes a GitHub release. CI injects the version from the tag at build time — no files are modified during the release.

## Testing

- Tests run under App Sandbox with the same entitlements as the extensions (`ENABLE_APP_SANDBOX`, `ENABLE_HARDENED_RUNTIME`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, read-only `/`)
- `RenderingTests` load HTML in a real WKWebView and verify content renders — catches CSP, sandbox, and script-loading regressions
- Run `./scripts/download-libs.sh --rehash` after bumping library versions to update SHA-256 hashes
