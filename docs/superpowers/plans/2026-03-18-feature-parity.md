# Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six features to QuickMark's markdown preview: heading anchors, ToC sidebar, target heading animation, GitHub Alerts, RTL text direction, and XML syntax highlighting.

**Architecture:** All markdown features modify `render.js` (client-side JS) and `style.css`. One new library (`markdown-it-anchor`) is added via `download-libs.sh`. GitHub Alerts are implemented as a custom markdown-it plugin in `render.js` (no external dependency). XML highlighting wires an existing UTType to the Structured extension. Each task is committed independently.

**Tech Stack:** JavaScript (markdown-it plugins, IntersectionObserver, DOM APIs), CSS (logical properties, keyframe animations, flexbox), Swift (HTMLBuilder, project.yml), Bash (download-libs.sh)

**Spec:** `docs/superpowers/specs/2026-03-18-feature-parity-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/download-libs.sh` | Modify | Add markdown-it-anchor download + SHA-256 verification |
| `Markdown/Resources/render.js` | Modify | Anchor plugin init, ToC builder, scroll tracking, resize, heading animation, GitHub Alerts plugin, RTL detection |
| `Markdown/Resources/style.css` | Modify | ToC layout, alert styling, heading animation, logical properties for RTL |
| `Markdown/HTMLBuilder.swift` | Modify | Add nav element, add anchor script to resource list |
| `THIRD-PARTY-NOTICES` | Modify | markdown-it-anchor licence |
| `project.yml` | Modify | Add public.xml to Structured UTTypes |
| `Structured/PreviewViewController.swift` | Modify | Map xml extension to language |
| `QuickMarkTests/RenderingTests.swift` | Modify | Tests for anchors, ToC, alerts, animation, RTL, XML |
| `QuickMarkTests/StructuredTests.swift` | Modify | XML language detection test |

---

## Task 1: Heading Anchors

**Files:**
- Modify: `scripts/download-libs.sh`
- Modify: `Markdown/Resources/render.js` (plugin registration block)
- Modify: `Markdown/HTMLBuilder.swift` (`scriptResources` array)
- Modify: `THIRD-PARTY-NOTICES`
- Modify: `QuickMarkTests/RenderingTests.swift`

- [ ] **Step 1: Add markdown-it-anchor to download-libs.sh**

Add version pin, hash placeholder, and download command after the footnote plugin section:

```bash
# After FOOTNOTE_HASH line (~line 17):
ANCHOR_VER="9.2.0"
ANCHOR_HASH="PLACEHOLDER"
```

```bash
# After footnote download block (~line 84):
curl -sfLo "$RESOURCES_DIR/markdownItAnchor.umd.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-anchor@$ANCHOR_VER/dist/markdownItAnchor.umd.js"
verify_hash "$RESOURCES_DIR/markdownItAnchor.umd.js" "$ANCHOR_HASH" "markdown-it-anchor"
echo "  markdown-it-anchor@$ANCHOR_VER ✓"
```

- [ ] **Step 2: Run download-libs.sh --rehash to get the real hash**

Run: `cd /Users/kiril/Dev/QuickMark && ./scripts/download-libs.sh --rehash`

Copy the printed hash for `markdown-it-anchor` and replace `PLACEHOLDER` in the script.

- [ ] **Step 3: Run download-libs.sh to verify the hash**

Run: `./scripts/download-libs.sh`

Expected: All libraries download with checkmarks, no hash mismatch errors.

- [ ] **Step 4: Add anchor script to HTMLBuilder.swift**

In `scriptResources` array, add the anchor plugin after `markdown-it-footnote.min` and before `katex.min`:

```swift
private static let scriptResources: [(name: String, ext: String)] = [
    ("markdown-it.min", "js"),
    ("markdown-it-task-lists.min", "js"),
    ("markdown-it-footnote.min", "js"),
    ("markdownItAnchor.umd", "js"),           // ← NEW
    ("katex.min", "js"),
    ("texmath.min", "js"),
    ("highlight.min", "js"),
    ("mermaid.min", "js"),
    ("viewer-static.min", "js"),
    ("render", "js"),
]
```

- [ ] **Step 5: Initialise anchor plugin in render.js**

After the `texmath` plugin registration (the `if (typeof texmath !== "undefined" ...` block), add:

```javascript
// Heading anchors
if (typeof markdownItAnchor !== "undefined") {
    md.use(markdownItAnchor, {
        slugify: function(s) {
            return "heading-" + s.trim().toLowerCase()
                .replace(/\s+/g, "-")
                .replace(/[^\w\u0590-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F\u0780-\u07BF\u08A0-\u08FF-]/g, "");
        },
        permalink: false
    });
}
```

The `heading-` prefix avoids collisions with existing element IDs (`content`, `toc`, `markdown-source`). The regex preserves Unicode characters for RTL scripts.

- [ ] **Step 6: Write the failing test**

Add to `RenderingTests.swift`:

```swift
func testHeadingsHaveAnchorIds() throws {
    try loadMarkdown("# First\n\n## Second\n\n### Third")

    let id1 = evaluateJS("document.querySelector('#content h1')?.id") as? String
    let id2 = evaluateJS("document.querySelector('#content h2')?.id") as? String
    let id3 = evaluateJS("document.querySelector('#content h3')?.id") as? String

    XCTAssertEqual(id1, "heading-first", "H1 should have slugified anchor id")
    XCTAssertEqual(id2, "heading-second", "H2 should have slugified anchor id")
    XCTAssertEqual(id3, "heading-third", "H3 should have slugified anchor id")
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Note: you may need to run `xcodegen` first if project.yml has changed. Expected: all tests pass including `testHeadingsHaveAnchorIds`.

- [ ] **Step 8: Add licence to THIRD-PARTY-NOTICES**

Append after the existing highlight.js entry (before the draw.io entry):

```
================================================================================

markdown-it-anchor v9.2.0
https://github.com/valeriangalliat/markdown-it-anchor

Copyright (c) Valérian Galliat

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Note: Verify the exact copyright holder name from the package's `LICENSE` file. The version above is indicative.

- [ ] **Step 9: Commit**

```bash
git add scripts/download-libs.sh Markdown/Resources/markdownItAnchor.umd.js \
  Markdown/Resources/render.js Markdown/HTMLBuilder.swift \
  THIRD-PARTY-NOTICES QuickMarkTests/RenderingTests.swift
git commit -m "feat: add heading anchors via markdown-it-anchor"
```

---

## Task 2: Table of Contents Sidebar

**Files:**
- Modify: `Markdown/HTMLBuilder.swift` (`assembleHTML()` body section)
- Modify: `Markdown/Resources/render.js`
- Modify: `Markdown/Resources/style.css`
- Modify: `QuickMarkTests/RenderingTests.swift`

- [ ] **Step 1: Add nav element to HTMLBuilder.swift**

In `assembleHTML()`, add the nav element before the article:

```swift
html += "</head>\n<body>\n"
html += "<nav id=\"toc\"></nav>\n"          // ← NEW
html += "<article id=\"content\"></article>\n"
```

- [ ] **Step 2: Write failing tests**

Add to `RenderingTests.swift`:

```swift
func testTocGeneratedForMultipleHeadings() throws {
    try loadMarkdown("# One\n\n## Two\n\n## Three")

    let tocLinks = evaluateJS("document.querySelectorAll('#toc a').length") as? Int
    XCTAssertEqual(tocLinks, 3, "ToC should have 3 links for 3 headings")

    let firstHref = evaluateJS("document.querySelector('#toc a')?.getAttribute('href')") as? String
    XCTAssertEqual(firstHref, "#heading-one", "First ToC link should point to heading anchor")
}

func testTocHiddenForSingleHeading() throws {
    try loadMarkdown("# Only One Heading\n\nSome text")

    let display = evaluateJS("getComputedStyle(document.getElementById('toc')).display") as? String
    XCTAssertEqual(display, "none", "ToC should be hidden when fewer than 2 headings")
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Expected: both new tests fail (ToC is empty, not hidden).

- [ ] **Step 4: Add ToC CSS to style.css**

Add after the `:root` dark mode block, before the `* { box-sizing }` rule:

```css
/* --- Table of Contents --- */

:root {
    --toc-width: 220px;
}

body.has-toc {
    display: flex;
    padding: 0;
}

body.has-toc #toc {
    display: block;
    position: sticky;
    top: 0;
    height: 100vh;
    width: var(--toc-width);
    min-width: 140px;
    max-width: 40vw;
    overflow-y: auto;
    padding: 16px 0;
    border-inline-end: 1px solid var(--border);
    font-size: 0.8125em;
    line-height: 1.4;
    flex-shrink: 0;
    cursor: default;
}

body.has-toc article {
    flex: 1;
    min-width: 0;
    padding: 32px;
    margin: 0 auto;
}

#toc {
    display: none;
}

#toc ul {
    list-style: none;
    margin: 0;
    padding: 0;
}

#toc li {
    margin: 0;
}

#toc a {
    display: block;
    padding: 3px 16px;
    color: var(--secondary);
    text-decoration: none;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

#toc a:hover {
    color: var(--text);
}

#toc a.active {
    color: var(--link);
    font-weight: 600;
}

/* Indent nested levels */
#toc li[data-level="2"] a { padding-inline-start: 32px; }
#toc li[data-level="3"] a { padding-inline-start: 48px; }
#toc li[data-level="4"] a { padding-inline-start: 64px; }
#toc li[data-level="5"] a { padding-inline-start: 80px; }
#toc li[data-level="6"] a { padding-inline-start: 96px; }

/* Resize handle */
#toc .toc-resize-handle {
    position: absolute;
    top: 0;
    inset-inline-end: 0;
    width: 4px;
    height: 100%;
    cursor: col-resize;
}

/* Hide ToC in narrow viewports */
@media (max-width: 1000px) {
    body.has-toc {
        display: block;
        padding: 32px;
    }
    body.has-toc #toc {
        display: none !important;
    }
}
```

- [ ] **Step 5: Add ToC builder and scroll tracking to render.js**

After the content rendering block (after `contentEl.innerHTML = md.render(source);`) and before the `// Initialize mermaid` comment, add:

```javascript
// --- Table of Contents ---
(function() {
    var tocEl = document.getElementById("toc");
    if (!tocEl) return;

    var headings = contentEl.querySelectorAll("h1, h2, h3, h4, h5, h6");
    if (headings.length < 2) return;

    // Build ToC list
    var ul = document.createElement("ul");
    for (var i = 0; i < headings.length; i++) {
        var h = headings[i];
        if (!h.id) continue;
        var level = parseInt(h.tagName.charAt(1), 10);
        var li = document.createElement("li");
        li.setAttribute("data-level", level);
        var a = document.createElement("a");
        a.href = "#" + h.id;
        a.textContent = h.textContent;
        li.appendChild(a);
        ul.appendChild(li);
    }

    // Resize handle
    var handle = document.createElement("div");
    handle.className = "toc-resize-handle";
    tocEl.appendChild(handle);

    tocEl.appendChild(ul);
    tocEl.style.display = "";
    document.body.classList.add("has-toc");

    // Restore saved width (best-effort — localStorage may not persist in sandbox)
    try {
        var saved = localStorage.getItem("quickmark-toc-width");
        if (saved) tocEl.style.width = saved;
    } catch (e) {}

    // Scroll tracking
    var tocLinks = tocEl.querySelectorAll("a");
    var observer = new IntersectionObserver(function(entries) {
        entries.forEach(function(entry) {
            if (entry.isIntersecting) {
                for (var j = 0; j < tocLinks.length; j++) {
                    var isActive = tocLinks[j].getAttribute("href") === "#" + entry.target.id;
                    tocLinks[j].classList.toggle("active", isActive);
                    if (isActive) {
                        tocLinks[j].scrollIntoView({ block: "nearest", behavior: "smooth" });
                    }
                }
            }
        });
    }, { rootMargin: "0px 0px -70% 0px" });

    for (var k = 0; k < headings.length; k++) {
        observer.observe(headings[k]);
    }

    // ToC link click — smooth scroll
    tocEl.addEventListener("click", function(e) {
        var link = e.target.closest("a");
        if (!link) return;
        e.preventDefault();
        var targetId = link.getAttribute("href").slice(1);
        var target = document.getElementById(targetId);
        if (target) target.scrollIntoView({ behavior: "smooth" });
    });

    // Resize drag
    var isResizing = false;
    handle.addEventListener("mousedown", function(e) {
        isResizing = true;
        e.preventDefault();
    });
    document.addEventListener("mousemove", function(e) {
        if (!isResizing) return;
        var isRTL = document.documentElement.dir === "rtl";
        var newWidth = isRTL
            ? (document.documentElement.clientWidth - e.clientX)
            : e.clientX;
        newWidth = Math.max(140, Math.min(newWidth, window.innerWidth * 0.4));
        tocEl.style.width = newWidth + "px";
    });
    document.addEventListener("mouseup", function() {
        if (!isResizing) return;
        isResizing = false;
        try { localStorage.setItem("quickmark-toc-width", tocEl.style.width); } catch (e) {}
    });
})();
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Expected: all tests pass including the two new ToC tests.

- [ ] **Step 7: Commit**

```bash
git add Markdown/HTMLBuilder.swift Markdown/Resources/render.js \
  Markdown/Resources/style.css QuickMarkTests/RenderingTests.swift
git commit -m "feat: add table of contents sidebar with scroll tracking"
```

---

## Task 3: Target Heading Animation

**Files:**
- Modify: `Markdown/Resources/render.js` (ToC click handler)
- Modify: `Markdown/Resources/style.css`

- [ ] **Step 1: Add animation CSS to style.css**

Add after the ToC section:

```css
/* --- Heading target animation --- */

@keyframes heading-highlight {
    from { background-color: color-mix(in srgb, var(--link) 20%, transparent); }
    to { background-color: transparent; }
}

.targeted {
    animation: heading-highlight 1s ease-out;
}
```

- [ ] **Step 2: Update ToC click handler in render.js**

In the ToC click handler (the `tocEl.addEventListener("click", ...)` block), after `target.scrollIntoView`, add:

```javascript
if (target) {
    target.scrollIntoView({ behavior: "smooth" });
    // Heading highlight animation
    target.classList.remove("targeted");
    void target.offsetWidth; // force reflow to restart animation
    target.classList.add("targeted");
    target.addEventListener("animationend", function() {
        target.classList.remove("targeted");
    }, { once: true });
}
```

Replace the existing simpler `if (target) target.scrollIntoView(...)` block.

- [ ] **Step 3: Verify manually**

Build and preview a markdown file with multiple headings. Click a ToC entry — the target heading should flash with a brief blue highlight that fades out over ~1 second.

- [ ] **Step 4: Commit**

```bash
git add Markdown/Resources/render.js Markdown/Resources/style.css
git commit -m "feat: add target heading animation on ToC navigation"
```

---

## Task 4: GitHub Alerts

**Files:**
- Modify: `Markdown/Resources/render.js`
- Modify: `Markdown/Resources/style.css`
- Modify: `QuickMarkTests/RenderingTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `RenderingTests.swift`:

```swift
func testGitHubAlertRendersWithClass() throws {
    try loadMarkdown("> [!WARNING]\n> This is a warning message")

    let alertClass = evaluateJS(
        "document.querySelector('.markdown-alert-warning') !== null"
    ) as? Bool
    XCTAssertEqual(alertClass, true, "Warning alert should have .markdown-alert-warning class")

    let markerRemoved = evaluateJS(
        "document.querySelector('.markdown-alert-warning')?.textContent?.indexOf('[!WARNING]') === -1"
    ) as? Bool
    XCTAssertEqual(markerRemoved, true, "[!WARNING] marker should be stripped from rendered text")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' -only-testing:'QuickMarkTests/RenderingTests/testGitHubAlertRendersWithClass' 2>&1 | tail -20`

Expected: FAIL — no `.markdown-alert-warning` element exists.

- [ ] **Step 3: Add custom GitHub Alerts plugin to render.js**

Add after the anchor plugin registration and before the `// Custom fence rules` comment:

```javascript
// GitHub-style alerts: [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION]
md.core.ruler.after("block", "github-alerts", function(state) {
    var tokens = state.tokens;
    for (var i = 0; i < tokens.length; i++) {
        if (tokens[i].type !== "blockquote_open") continue;

        // Find the first inline token inside this blockquote
        var inlineIdx = -1;
        for (var j = i + 1; j < tokens.length; j++) {
            if (tokens[j].type === "blockquote_close" && tokens[j].level === tokens[i].level) break;
            if (tokens[j].type === "inline") { inlineIdx = j; break; }
        }
        if (inlineIdx === -1) continue;

        var inlineToken = tokens[inlineIdx];
        var match = inlineToken.content.match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n?/);
        if (!match) continue;

        var alertType = match[1].toLowerCase();

        // Strip the marker from the inline content
        inlineToken.content = inlineToken.content.slice(match[0].length);
        if (inlineToken.children && inlineToken.children.length > 0) {
            // Remove marker from child text tokens
            var remaining = match[0].length;
            for (var c = 0; c < inlineToken.children.length && remaining > 0; c++) {
                var child = inlineToken.children[c];
                if (child.type === "text") {
                    if (child.content.length <= remaining) {
                        remaining -= child.content.length;
                        child.content = "";
                    } else {
                        child.content = child.content.slice(remaining);
                        remaining = 0;
                    }
                } else if (child.type === "softbreak") {
                    remaining -= 1;
                }
            }
        }

        // Add alert classes to the blockquote_open token
        tokens[i].attrJoin("class", "markdown-alert markdown-alert-" + alertType);
    }
});
```

- [ ] **Step 4: Add alert CSS to style.css**

Add after the blockquote section:

```css
/* --- GitHub Alerts --- */

.markdown-alert {
    padding: 8px 1em;
    margin-bottom: 16px;
    border-inline-start-width: 0.25em;
    border-inline-start-style: solid;
    color: var(--text);
}

.markdown-alert p:last-child {
    margin-bottom: 0;
}

.markdown-alert-note      { border-inline-start-color: #0969da; background: rgba(9, 105, 218, 0.05); }
.markdown-alert-tip       { border-inline-start-color: #1a7f37; background: rgba(26, 127, 55, 0.05); }
.markdown-alert-important { border-inline-start-color: #8250df; background: rgba(130, 80, 223, 0.05); }
.markdown-alert-warning   { border-inline-start-color: #9a6700; background: rgba(154, 103, 0, 0.05); }
.markdown-alert-caution   { border-inline-start-color: #cf222e; background: rgba(207, 34, 46, 0.05); }

@media (prefers-color-scheme: dark) {
    .markdown-alert-note      { border-inline-start-color: #58a6ff; background: rgba(88, 166, 255, 0.08); }
    .markdown-alert-tip       { border-inline-start-color: #3fb950; background: rgba(63, 185, 80, 0.08); }
    .markdown-alert-important { border-inline-start-color: #a371f7; background: rgba(163, 113, 247, 0.08); }
    .markdown-alert-warning   { border-inline-start-color: #d29922; background: rgba(210, 153, 34, 0.08); }
    .markdown-alert-caution   { border-inline-start-color: #f85149; background: rgba(248, 81, 73, 0.08); }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Expected: all tests pass including `testGitHubAlertRendersWithClass`.

- [ ] **Step 6: Commit**

```bash
git add Markdown/Resources/render.js Markdown/Resources/style.css \
  QuickMarkTests/RenderingTests.swift
git commit -m "feat: add GitHub Alerts ([!NOTE], [!WARNING], etc.)"
```

---

## Task 5: RTL Text Direction

**Files:**
- Modify: `Markdown/Resources/render.js`
- Modify: `Markdown/Resources/style.css`
- Modify: `QuickMarkTests/RenderingTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `RenderingTests.swift`:

```swift
func testRTLContentSetsDirection() throws {
    try loadMarkdown("# \u{0645}\u{0631}\u{062D}\u{0628}\u{0627}\n\n\u{0647}\u{0630}\u{0627} \u{0646}\u{0635} \u{0639}\u{0631}\u{0628}\u{064A}")

    let dir = evaluateJS("document.documentElement.dir") as? String
    XCTAssertEqual(dir, "rtl", "Arabic content should set dir=rtl on <html>")
}

func testLTRContentDoesNotSetDirection() throws {
    try loadMarkdown("# Hello\n\nThis is English text")

    let dir = evaluateJS("document.documentElement.dir") as? String
    XCTAssertTrue(dir == nil || dir == "" || dir == "ltr",
                  "English content should not set dir=rtl")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `testRTLContentSetsDirection` fails (dir is not "rtl").

- [ ] **Step 3: Add RTL detection to render.js**

After the ToC builder block and before mermaid initialisation, add:

```javascript
// --- RTL detection ---
(function() {
    var rtlPattern = /[\u0590-\u05FF\u0600-\u06FF\u0700-\u074F\u0750-\u077F\u0780-\u07BF\u08A0-\u08FF]/;
    // Sample the first meaningful text node
    var walker = document.createTreeWalker(contentEl, NodeFilter.SHOW_TEXT, null, false);
    var rtlCount = 0, ltrCount = 0, sampled = 0;
    while (sampled < 200) {
        var node = walker.nextNode();
        if (!node) break;
        var text = node.textContent.trim();
        if (!text) continue;
        for (var ci = 0; ci < text.length && sampled < 200; ci++) {
            var ch = text.charAt(ci);
            if (rtlPattern.test(ch)) rtlCount++;
            else if (/[a-zA-Z]/.test(ch)) ltrCount++;
            sampled++;
        }
    }
    if (rtlCount > ltrCount) {
        document.documentElement.dir = "rtl";
    }
})();
```

- [ ] **Step 4: Convert physical CSS properties to logical**

In `style.css`, make these changes:

Blockquote:
```css
/* Before: */
border-left: 0.25em solid var(--blockquote-border);
/* After: */
border-inline-start: 0.25em solid var(--blockquote-border);
```

Lists:
```css
/* Before: */
ul, ol { padding-left: 2em; margin-bottom: 16px; }
/* After: */
ul, ol { padding-inline-start: 2em; margin-bottom: 16px; }
```

Task lists:
```css
/* Before: */
.task-list-item { list-style-type: none; margin-left: -1.5em; }
/* After: */
.task-list-item { list-style-type: none; margin-inline-start: -1.5em; }
```

Footnotes:
```css
/* Before: */
.footnotes ol { padding-left: 1.5em; }
/* After: */
.footnotes ol { padding-inline-start: 1.5em; }
```

Checkbox:
```css
/* Before: */
.task-list-item input[type="checkbox"] { margin-right: 0.5em; ... }
/* After: */
.task-list-item input[type="checkbox"] { margin-inline-end: 0.5em; ... }
```

Note: GitHub Alerts CSS was already written with `border-inline-start-*` in Task 4 — no conversion needed.

Add code block direction override:

```css
/* Code is always LTR regardless of document direction */
pre, code {
    direction: ltr;
    text-align: left;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Expected: all tests pass including both RTL tests.

- [ ] **Step 6: Commit**

```bash
git add Markdown/Resources/render.js Markdown/Resources/style.css \
  QuickMarkTests/RenderingTests.swift
git commit -m "feat: add RTL text direction detection and CSS logical properties"
```

---

## Task 6: XML Syntax Highlighting

**Files:**
- Modify: `project.yml` (QuickMarkStructured `QLSupportedContentTypes`)
- Modify: `Structured/PreviewViewController.swift` (`language(for:)` switch)
- Modify: `QuickMarkTests/StructuredTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `StructuredTests.swift`:

```swift
func testXmlExtension() {
    XCTAssertEqual(PreviewViewController.language(for: "xml"), "xml")
}

func testXmlCaseInsensitive() {
    XCTAssertEqual(PreviewViewController.language(for: "XML"), "xml")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' -only-testing:'QuickMarkTests/StructuredTests/testXmlExtension' 2>&1 | tail -20`

Expected: FAIL — returns "plaintext" instead of "xml".

- [ ] **Step 3: Add XML to language detection**

In `Structured/PreviewViewController.swift`, in the `language(for:)` switch:

```swift
nonisolated static func language(for pathExtension: String) -> String {
    switch pathExtension.lowercased() {
    case "yml", "yaml": return "yaml"
    case "json": return "json"
    case "toml": return "toml"
    case "xml": return "xml"           // ← NEW
    default: return "plaintext"
    }
}
```

- [ ] **Step 4: Add public.xml to project.yml**

In the `QuickMarkStructured` target's `QLSupportedContentTypes`, add `public.xml`:

```yaml
QLSupportedContentTypes:
  - public.json
  - public.yaml
  - org.toml.toml
  - public.xml              # ← NEW
```

Note: `.drawio` files use `com.jgraph.drawio` which is more specific than `public.xml`, so macOS will still route `.drawio` files to the DrawIO extension.

- [ ] **Step 5: Regenerate Xcode project and run tests**

Run: `xcodegen && xcodebuild test -project QuickMark.xcodeproj -scheme QuickMark -destination 'platform=macOS' 2>&1 | tail -20`

Expected: all tests pass including both XML tests.

- [ ] **Step 6: Commit**

```bash
git add project.yml Structured/PreviewViewController.swift \
  QuickMarkTests/StructuredTests.swift
git commit -m "feat: add XML syntax highlighting to Structured extension"
```

---

## Post-Implementation

- [ ] **Update CLAUDE.md** to mention ToC sidebar, CSS logical properties convention, GitHub Alerts, and RTL support
- [ ] **Run full test suite** one final time to verify nothing is broken
- [ ] **Commit CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with new features"
```
