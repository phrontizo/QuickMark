# Structured Data Viewer QuickLook Extension

## Overview

Add a new QuickLook extension to QuickMark that provides syntax-highlighted previews with line numbers for `.yml`, `.yaml`, `.json`, and `.toml` files. Uses highlight.js (already bundled for the Markdown extension).

**Use cases:** GitHub Actions workflows, Kubernetes manifests, docker-compose files, general config files.

## Architecture

### New Target: `QuickMarkStructured`

Follows the same pattern as `QuickMarkDrawio` — a standalone app-extension target with its own resources.

### Files

```
Structured/
├── PreviewViewController.swift    # Reads file, detects language, builds HTML, loads WKWebView
├── Info.plist
├── Structured.entitlements
├── Resources/
│   ├── highlight.min.js           # Copy from Markdown/Resources
│   └── hljs-themes.css            # Copy from Markdown/Resources
└── style.css                      # Line numbers, monospace, dark/light mode
```

### PreviewViewController

- Reads the file with UTF-8 / ISO Latin 1 fallback (same pattern as Markdown/DrawIO)
- Detects language from file extension: `.yml`/`.yaml` → `yaml`, `.json` → `json`, `.toml` → `toml`
- Builds a minimal HTML document:
  - `<pre><code class="language-{lang}">` with HTML-escaped file content
  - Loads `highlight.min.js` which auto-highlights the code block
  - A small inline script splits the highlighted output into numbered lines
- Loads via `loadFileURL` with the same sandboxed temp file pattern

### HTML Template

Inline in PreviewViewController (no HTMLBuilder needed — the template is simple and fixed):

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <link rel="stylesheet" href="{hljs-themes.css}">
  <link rel="stylesheet" href="{style.css}">
</head>
<body>
  <pre><code class="language-{lang}">{escaped-content}</code></pre>
  <script src="{highlight.min.js}"></script>
  <script>
    hljs.highlightAll();
    // Split into numbered lines
    var code = document.querySelector('code');
    var lines = code.innerHTML.split('\n');
    code.innerHTML = lines.map(function(line, i) {
      return '<span class="line"><span class="line-number">' + (i + 1) + '</span>' + line + '</span>';
    }).join('\n');
  </script>
</body>
</html>
```

### Style (style.css)

CSS variables for dark/light mode (matching the Markdown extension's palette):
- Monospace font (`ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace`)
- Line numbers: dimmed, right-aligned, with a subtle border separator
- No wrapping (horizontal scroll for long lines)
- Comfortable padding

### UTTypes (QLSupportedContentTypes)

- `public.json` — system-defined
- `public.yaml` — system-defined on macOS 14+
- `org.toml.toml` — imported type declaration for `.toml`

### Entitlements

Same as other extensions:
- `ENABLE_APP_SANDBOX: YES`
- `ENABLE_HARDENED_RUNTIME: YES`
- `ENABLE_OUTGOING_NETWORK_CONNECTIONS: YES`
- `ENABLE_USER_SELECTED_FILES: readonly`
- Temp exception: read-only `/`

### Host App Changes

- Add `structuredAppearance` to `AppearancePreference` (new key, same System/Light/Dark picker)
- Add third column in ContentView for "Structured Data" with feature list and appearance picker
- Check extension registration for `com.quickmark.QuickMark.QuickMarkStructured`

### download-libs.sh

Add a step to copy `highlight.min.js` and `hljs-themes.css` to `Structured/Resources/`.

### project.yml

New target `QuickMarkStructured`:
- Type: `app-extension`
- Sources: `Shared`, `Structured` (excluding Resources), `Structured/Resources` (as resources)
- Dependency of `QuickMark` (embed + codesign)
- Same entitlements pattern as other extensions

## Testing

### Unit Tests

- Language detection from file extension (yaml, yml, json, toml, unknown)
- HTML escaping of file content (verify `<`, `>`, `&`, `"` are escaped)

### Integration Tests (WKWebView)

- Verify highlight.js produces syntax-highlighted output (check for `.hljs-attr` or similar class)
- Verify line numbers are present

### Test Files

- Add `TestFiles/sample.yml`, `TestFiles/sample.json`, `TestFiles/sample.toml`

## Security

- File content is HTML-escaped before embedding in the template
- No user-controlled HTML injection possible (content goes inside `<code>`)
- Same sandbox model as other extensions
- highlight.js processes escaped text content only
