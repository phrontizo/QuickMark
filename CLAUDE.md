# QuickMark Development Notes

## Git

Commit locally when asked, but **never push** — pushing is always manual.

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

Draw.io diagrams referenced as `![alt](file.drawio)` are converted to ` ```drawio` fenced code blocks by `MarkdownProcessor`. The `render.js` fence rule then creates the `<div class="mxgraph">` at render time. This is necessary because `html: false` would escape raw HTML divs injected pre-rendering.

## SharedResources

`SharedResources/` contains resources used by multiple extension targets (currently `viewer-static.min.js` for Markdown and DrawIO). Each target references the single copy in `project.yml` — Xcode bundles it into each extension at build time. Do NOT duplicate shared resources into individual extension `Resources/` directories.

## Testing

- Tests run under App Sandbox with the same entitlements as the extensions (`ENABLE_APP_SANDBOX`, `ENABLE_HARDENED_RUNTIME`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, read-only `/`)
- `RenderingTests` load HTML in a real WKWebView and verify content renders — catches CSP, sandbox, and script-loading regressions
- Run `./scripts/download-libs.sh --rehash` after bumping library versions to update SHA-256 hashes
