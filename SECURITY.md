# Security Policy

## Threat Model

QuickMark renders untrusted files (Markdown, draw.io XML, JSON, YAML, TOML) in sandboxed QuickLook extensions via WKWebView. The primary risk is a crafted file executing arbitrary code or exfiltrating data.

### Mitigations

- **No inline HTML** — markdown-it runs with `html: false`, blocking `<script>`, `<img onerror>`, and all raw HTML injection
- **Link allowlist** — only `http://` and `https://` links are navigable; `javascript:`, `data:`, and custom schemes are blocked
- **App Sandbox** — all extensions run with hardened runtime and read-only filesystem access
- **Pinned dependencies** — all JS/CSS libraries are version-pinned with SHA-256 hash verification (`scripts/download-libs.sh`)
- **No network requests** — all rendering is local; the `ENABLE_OUTGOING_NETWORK_CONNECTIONS` entitlement exists solely for WKWebView's internal IPC

## Reporting a Vulnerability

If you discover a security issue, please report it privately:

1. **GitHub Security Advisories** (preferred): [Report a vulnerability](https://github.com/phrontizo/QuickMark/security/advisories/new)
2. **Email**: security@phrontizo.com

Please include:
- Description of the vulnerability
- Steps to reproduce (a crafted test file is ideal)
- Impact assessment

I aim to acknowledge reports within 48 hours and provide a fix or mitigation plan within 7 days.

## Supported Versions

Only the latest release is supported with security updates.
