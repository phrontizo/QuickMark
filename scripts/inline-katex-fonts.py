#!/usr/bin/env python3
"""Inline font url() references in KaTeX CSS as base64 data URIs."""
import base64
import re
import sys
from pathlib import Path

def main():
    css_path = Path(sys.argv[1])
    css = css_path.read_text()

    def replace_url(match):
        raw = match.group(1).strip().strip("'\"")
        if not raw.startswith("fonts/"):
            return match.group(0)
        font_path = css_path.parent / raw
        if not font_path.exists():
            print(f"Warning: font not found: {font_path}", file=sys.stderr)
            return match.group(0)
        data = base64.b64encode(font_path.read_bytes()).decode()
        ext = font_path.suffix.lstrip(".")
        mime = {"woff2": "font/woff2", "woff": "font/woff", "ttf": "font/ttf"}.get(ext, f"font/{ext}")
        return f'url("data:{mime};base64,{data}")'

    result = re.sub(r"url\(([^)]+)\)", replace_url, css)
    sys.stdout.write(result)

if __name__ == "__main__":
    main()
