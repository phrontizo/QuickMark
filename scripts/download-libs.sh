#!/usr/bin/env bash
set -euo pipefail

# ─── Pinned versions and expected SHA-256 hashes ───────────────────────
# To upgrade a library: bump the version, then run:
#   ./scripts/download-libs.sh --rehash
# This downloads everything and prints new hashes to paste below.
# ───────────────────────────────────────────────────────────────────────

MARKDOWN_IT_VER="14.1.0"
MARKDOWN_IT_HASH="c833317a56b17b17cc1910f3b7004447573487cd1fed4c1bcef90afbcbf5c234"

TASK_LISTS_VER="2.1.1"
TASK_LISTS_HASH="4f3b23f41bb3787957da2602fbccc4df0d017928c1fce62583159e096b832a81"

FOOTNOTE_VER="4.0.0"
FOOTNOTE_HASH="d6fee58a3b56c5742fa18f3e01f1d317cc99975683ebd39c9195cb2aff0c2e42"

TEXMATH_VER="1.0.0"
TEXMATH_JS_HASH="b01b706e6d23e8270a55228fdba35b557127b6f2af5b4c23ca22b15bdbd1c09d"
TEXMATH_CSS_HASH="8d886ea32b7d159ca2fe4acf396d227a539edb0b474a3d166d6afb6da3834d40"

HLJS_VER="11.11.1"
HLJS_HASH="c4a399dd6f488bc97a3546e3476747b3e714c99c57b9473154c6fb8d259b9381"
HLJS_LIGHT_HASH="3a9a5def8b9c311e5ae43abde85c63133185eed4f0d9f67fea4b00a8308cf066"
HLJS_DARK_HASH="9f208d022102b1d0c7aebfecd8e42ca7997d5de636649d2b31ea63093d809019"

KATEX_VER="0.16.21"
KATEX_HASH="1b68624f8f96870496011de546fad33805b112e1e1c0f7fa675ede6baa47136c"
KATEX_CSS_HASH="f787891b550d554c214aa8902f39ac46df2dbd48fdec500a2040a5dce1e8ab58"

MERMAID_VER="11.4.1"
MERMAID_HASH="3e2002bf333907fae7c1d6860bbc78f5da417bc70b64f3d2268581ba0ba8b96a"

# draw.io viewer has no semver — hash-only verification
DRAWIO_VIEWER_HASH="24bb4c9c9dae09644e8c9b29bbaaf7af37eca5e0533b3e992f57bf0fd1c63467"

# ──────────────────────────────────────────────────────────────────────

RESOURCES_DIR="Markdown/Resources"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

REHASH=false
if [[ "${1:-}" == "--rehash" ]]; then
  REHASH=true
  echo "Running in rehash mode — downloading and printing new hashes..."
  echo ""
fi

# Verify SHA-256 hash of a downloaded file. In --rehash mode, prints the new hash instead.
verify_hash() {
  local file="$1" expected="$2" name="$3"
  local actual
  actual=$(shasum -a 256 "$file" | awk '{print $1}')
  if $REHASH; then
    echo "  $name: $actual"
    return
  fi
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: SHA-256 mismatch for $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    echo "  Run './scripts/download-libs.sh --rehash' after updating version pins."
    exit 1
  fi
}

echo "Downloading JS/CSS libraries..."

# --- markdown-it and plugins ---
curl -sfLo "$RESOURCES_DIR/markdown-it.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it@$MARKDOWN_IT_VER/dist/markdown-it.min.js"
verify_hash "$RESOURCES_DIR/markdown-it.min.js" "$MARKDOWN_IT_HASH" "markdown-it"
echo "  markdown-it@$MARKDOWN_IT_VER ✓"

curl -sfLo "$RESOURCES_DIR/markdown-it-task-lists.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@$TASK_LISTS_VER/dist/markdown-it-task-lists.min.js"
verify_hash "$RESOURCES_DIR/markdown-it-task-lists.min.js" "$TASK_LISTS_HASH" "task-lists"
echo "  markdown-it-task-lists@$TASK_LISTS_VER ✓"

curl -sfLo "$RESOURCES_DIR/markdown-it-footnote.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-footnote@$FOOTNOTE_VER/dist/markdown-it-footnote.min.js"
verify_hash "$RESOURCES_DIR/markdown-it-footnote.min.js" "$FOOTNOTE_HASH" "footnote"
echo "  markdown-it-footnote@$FOOTNOTE_VER ✓"

# --- markdown-it-texmath ---
curl -sfLo "$RESOURCES_DIR/texmath.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-texmath@$TEXMATH_VER/texmath.min.js"
verify_hash "$RESOURCES_DIR/texmath.min.js" "$TEXMATH_JS_HASH" "texmath.js"
curl -sfLo "$RESOURCES_DIR/texmath.min.css" \
  "https://cdn.jsdelivr.net/npm/markdown-it-texmath@$TEXMATH_VER/css/texmath.min.css"
verify_hash "$RESOURCES_DIR/texmath.min.css" "$TEXMATH_CSS_HASH" "texmath.css"
echo "  texmath@$TEXMATH_VER ✓"

# --- highlight.js (shared between Markdown and Structured extensions) ---
curl -sfLo "SharedResources/highlight.min.js" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/highlight.min.js"
verify_hash "SharedResources/highlight.min.js" "$HLJS_HASH" "highlight.js"
curl -sfLo "$TEMP_DIR/github.min.css" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/styles/github.min.css"
verify_hash "$TEMP_DIR/github.min.css" "$HLJS_LIGHT_HASH" "hljs-light-theme"
curl -sfLo "$TEMP_DIR/github-dark.min.css" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/styles/github-dark.min.css"
verify_hash "$TEMP_DIR/github-dark.min.css" "$HLJS_DARK_HASH" "hljs-dark-theme"

# Combine hljs themes into media-query-wrapped stylesheet
{
  echo "@media (prefers-color-scheme: light) {"
  cat "$TEMP_DIR/github.min.css"
  echo "}"
  echo "@media (prefers-color-scheme: dark) {"
  cat "$TEMP_DIR/github-dark.min.css"
  echo "}"
} > "SharedResources/hljs-themes.css"
echo "  highlight.js@$HLJS_VER ✓"

# --- KaTeX ---
KATEX_BASE="https://cdn.jsdelivr.net/npm/katex@$KATEX_VER/dist"
curl -sfLo "$RESOURCES_DIR/katex.min.js" "$KATEX_BASE/katex.min.js"
verify_hash "$RESOURCES_DIR/katex.min.js" "$KATEX_HASH" "katex.js"
curl -sfLo "$TEMP_DIR/katex.min.css" "$KATEX_BASE/katex.min.css"
verify_hash "$TEMP_DIR/katex.min.css" "$KATEX_CSS_HASH" "katex.css"

# Download all fonts referenced in the CSS
mkdir -p "$TEMP_DIR/fonts"
grep -oE 'url\([^)]*fonts/[^)]+\)' "$TEMP_DIR/katex.min.css" | \
  sed 's/url(//;s/)//;s/"//g;s/'"'"'//g' | sort -u | while read -r font_path; do
    curl -sfLo "$TEMP_DIR/$font_path" "$KATEX_BASE/$font_path"
done

# Inline fonts as base64 data URIs
python3 scripts/inline-katex-fonts.py "$TEMP_DIR/katex.min.css" \
  > "$RESOURCES_DIR/katex-inlined.min.css"
echo "  KaTeX@$KATEX_VER (with inlined fonts) ✓"

# --- mermaid ---
curl -sfLo "$RESOURCES_DIR/mermaid.min.js" \
  "https://cdn.jsdelivr.net/npm/mermaid@$MERMAID_VER/dist/mermaid.min.js"
verify_hash "$RESOURCES_DIR/mermaid.min.js" "$MERMAID_HASH" "mermaid.js"
echo "  mermaid@$MERMAID_VER ✓"

# --- draw.io viewer (shared between Markdown and DrawIO extensions) ---
mkdir -p "SharedResources"
curl -sfLo "SharedResources/viewer-static.min.js" \
  "https://viewer.diagrams.net/js/viewer-static.min.js"
verify_hash "SharedResources/viewer-static.min.js" "$DRAWIO_VIEWER_HASH" "viewer-static.js"
echo "  draw.io viewer ✓"

echo ""
echo "All libraries downloaded to $RESOURCES_DIR/ and SharedResources/"
ls -lh "$RESOURCES_DIR/"
