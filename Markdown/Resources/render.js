(function() {
    "use strict";

    // Detect dark mode for mermaid theme
    var isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

    // Initialize markdown-it with plugins
    var md = markdownit({
        html: false,
        linkify: true,
        typographer: false,
        highlight: function(str, lang) {
            if (lang && typeof hljs !== "undefined" && hljs.getLanguage(lang)) {
                try {
                    return hljs.highlight(str, { language: lang }).value;
                } catch (_) {}
            }
            return "";
        }
    });

    // Register plugins
    // Note: the global name may be markdownItTaskLists (capital I) depending on
    // the version downloaded. Verify against the actual .min.js file and adjust.
    var taskListPlugin = window.markdownitTaskLists || window.markdownItTaskLists;
    if (taskListPlugin) md.use(taskListPlugin, { enabled: true, label: true });
    if (typeof markdownitFootnote !== "undefined") md.use(markdownitFootnote);

    if (typeof texmath !== "undefined" && typeof katex !== "undefined") {
        md.use(texmath, { engine: katex, delimiters: "dollars", katexOptions: { throwOnError: false } });
    }

    // Custom fence rule: render mermaid blocks as divs instead of <pre><code>
    // HTML-escape the content to prevent injection; mermaid reads textContent
    // so it sees the original unescaped text (arrows like --> work correctly).
    var defaultFence = md.renderer.rules.fence.bind(md.renderer.rules);
    md.renderer.rules.fence = function(tokens, idx, options, env, self) {
        var token = tokens[idx];
        if (token.info.trim() === "mermaid") {
            return '<div class="mermaid">' + md.utils.escapeHtml(token.content) + "</div>\n";
        }
        return defaultFence(tokens, idx, options, env, self);
    };

    // Decode base64 markdown source (UTF-8 aware) and render
    var sourceEl = document.getElementById("markdown-source");
    var contentEl = document.getElementById("content");
    if (!sourceEl || !contentEl) { return; }
    try {
        var bytes = Uint8Array.from(atob(sourceEl.textContent.trim()), function(c) { return c.charCodeAt(0); });
        var source = new TextDecoder().decode(bytes);
        contentEl.innerHTML = md.render(source);
    } catch (e) {
        contentEl.textContent = "Failed to render markdown: " + e.message;
        return;
    }

    // Initialize mermaid (if loaded)
    if (typeof mermaid !== "undefined") {
        try {
            mermaid.initialize({
                startOnLoad: false,
                theme: isDark ? "dark" : "default",
                securityLevel: "strict"
            });
            mermaid.run().catch(function(e) {
                console.error("Mermaid rendering failed:", e);
            });
        } catch (e) {
            console.error("Mermaid initialization failed:", e);
        }
    }

    // Initialize draw.io viewer (if any .mxgraph elements exist)
    if (typeof GraphViewer !== "undefined" && document.querySelector(".mxgraph")) {
        try {
            GraphViewer.processElements();
        } catch (e) {
            console.error("Draw.io viewer initialization failed:", e);
        }
    }
})();
