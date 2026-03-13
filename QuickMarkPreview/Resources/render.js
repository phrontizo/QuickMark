(function() {
    "use strict";

    // Detect dark mode for mermaid theme
    var isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;

    // Initialize markdown-it with plugins
    var md = markdownit({
        html: true,
        linkify: true,
        typographer: false,
        highlight: function(str, lang) {
            if (lang && hljs.getLanguage(lang)) {
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
    md.use(markdownitFootnote);

    md.use(texmath, { engine: katex, delimiters: "dollars", katexOptions: { throwOnError: false } });

    // Custom fence rule: render mermaid blocks as divs instead of <pre><code>
    // Mermaid expects raw diagram text — do NOT HTML-escape (arrows like --> would break)
    var defaultFence = md.renderer.rules.fence.bind(md.renderer.rules);
    md.renderer.rules.fence = function(tokens, idx, options, env, self) {
        var token = tokens[idx];
        if (token.info.trim() === "mermaid") {
            return '<div class="mermaid">' + token.content + "</div>\n";
        }
        return defaultFence(tokens, idx, options, env, self);
    };

    // Decode base64 markdown source and render
    var sourceEl = document.getElementById("markdown-source");
    var source = atob(sourceEl.textContent.trim());
    document.getElementById("content").innerHTML = md.render(source);

    // Initialize mermaid
    mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? "dark" : "default",
        securityLevel: "strict"
    });
    mermaid.run();

    // Initialize draw.io viewer (if any .mxgraph elements exist)
    if (typeof GraphViewer !== "undefined" && document.querySelector(".mxgraph")) {
        GraphViewer.processElements();
    }
})();
