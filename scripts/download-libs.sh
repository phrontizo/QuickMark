#!/usr/bin/env bash
set -euo pipefail

RESOURCES_DIR="QuickMarkPreview/Resources"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Downloading JS/CSS libraries..."

# --- markdown-it and plugins ---
curl -sLo "$RESOURCES_DIR/markdown-it.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js"
echo "  markdown-it ✓"

curl -sLo "$RESOURCES_DIR/markdown-it-task-lists.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2/dist/markdown-it-task-lists.min.js"
echo "  markdown-it-task-lists ✓"

curl -sLo "$RESOURCES_DIR/markdown-it-footnote.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-footnote@4/dist/markdown-it-footnote.min.js"
echo "  markdown-it-footnote ✓"

# --- markdown-it-texmath ---
curl -sLo "$RESOURCES_DIR/texmath.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-texmath@1/texmath.min.js"
curl -sLo "$RESOURCES_DIR/texmath.min.css" \
  "https://cdn.jsdelivr.net/npm/markdown-it-texmath@1/css/texmath.min.css"
echo "  texmath ✓"

# --- highlight.js ---
HLJS_VER="11"
curl -sLo "$RESOURCES_DIR/highlight.min.js" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/highlight.min.js"
curl -sLo "$TEMP_DIR/github.min.css" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/styles/github.min.css"
curl -sLo "$TEMP_DIR/github-dark.min.css" \
  "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@$HLJS_VER/build/styles/github-dark.min.css"

# Combine hljs themes into media-query-wrapped stylesheet
{
  echo "@media (prefers-color-scheme: light) {"
  cat "$TEMP_DIR/github.min.css"
  echo "}"
  echo "@media (prefers-color-scheme: dark) {"
  cat "$TEMP_DIR/github-dark.min.css"
  echo "}"
} > "$RESOURCES_DIR/hljs-themes.css"
echo "  highlight.js ✓"

# --- KaTeX ---
KATEX_VER="0.16"
KATEX_BASE="https://cdn.jsdelivr.net/npm/katex@$KATEX_VER/dist"
curl -sLo "$RESOURCES_DIR/katex.min.js" "$KATEX_BASE/katex.min.js"
curl -sLo "$TEMP_DIR/katex.min.css" "$KATEX_BASE/katex.min.css"

# Download all fonts referenced in the CSS
mkdir -p "$TEMP_DIR/fonts"
grep -oE 'url\([^)]*fonts/[^)]+\)' "$TEMP_DIR/katex.min.css" | \
  sed 's/url(//;s/)//;s/"//g;s/'"'"'//g' | sort -u | while read -r font_path; do
    curl -sLo "$TEMP_DIR/$font_path" "$KATEX_BASE/$font_path"
done

# Inline fonts as base64 data URIs
python3 scripts/inline-katex-fonts.py "$TEMP_DIR/katex.min.css" \
  > "$RESOURCES_DIR/katex-inlined.min.css"
echo "  KaTeX (with inlined fonts) ✓"

# --- mermaid ---
curl -sLo "$RESOURCES_DIR/mermaid.min.js" \
  "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"
echo "  mermaid ✓"

# --- draw.io viewer ---
curl -sLo "$RESOURCES_DIR/viewer-static.min.js" \
  "https://viewer.diagrams.net/js/viewer-static.min.js"
echo "  draw.io viewer ✓"

echo ""
echo "All libraries downloaded to $RESOURCES_DIR/"
ls -lh "$RESOURCES_DIR/"
