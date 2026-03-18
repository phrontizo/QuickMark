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

    // Custom fence rules: render mermaid and drawio blocks as divs instead of <pre><code>
    var defaultFence = md.renderer.rules.fence.bind(md.renderer.rules);
    md.renderer.rules.fence = function(tokens, idx, options, env, self) {
        var token = tokens[idx];
        var info = token.info.trim();

        if (info === "mermaid") {
            // HTML-escape the content to prevent injection; mermaid reads textContent
            // so it sees the original unescaped text (arrows like --> work correctly).
            return '<div class="mermaid">' + md.utils.escapeHtml(token.content) + "</div>\n";
        }

        if (info === "drawio" || info.lastIndexOf("drawio ", 0) === 0) {
            // Parse optional page selector: "drawio page=Name" or "drawio page=2"
            var pageParam = null;
            var pageMatch = info.match(/^drawio\s+page=(.+)$/);
            if (pageMatch) pageParam = pageMatch[1];

            var xml = token.content.replace(/\n$/, "");
            var data = JSON.stringify({highlight: "#0000ff", nav: true, resize: true, xml: xml});
            var escaped = data.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#x27;");
            // Generate tab bar if multiple pages
            var tabsHtml = "";
            var doc = new DOMParser().parseFromString(xml, "text/xml");
            var diagrams = doc.querySelectorAll("diagram");
            if (diagrams.length > 1) {
                // Resolve page param to 0-based index
                var initialPage = 0;
                if (pageParam !== null) {
                    var asInt = parseInt(pageParam, 10);
                    if (!isNaN(asInt) && asInt >= 0 && asInt < diagrams.length) {
                        initialPage = asInt;
                    } else {
                        for (var p = 0; p < diagrams.length; p++) {
                            if (diagrams[p].getAttribute("name") === pageParam) { initialPage = p; break; }
                        }
                    }
                }
                tabsHtml = '<div class="drawio-tabs" data-initial-page="' + initialPage + '">';
                for (var k = 0; k < diagrams.length; k++) {
                    var name = diagrams[k].getAttribute("name") || "Page " + (k + 1);
                    tabsHtml += '<button class="drawio-tab' + (k === initialPage ? ' active' : '') + '" data-page="' + k + '">'
                        + md.utils.escapeHtml(name) + '</button>';
                }
                tabsHtml += '</div>';
            }
            return tabsHtml + '<div class="mxgraph" data-mxgraph="' + escaped + '"></div>\n';
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
            var mxEls = document.querySelectorAll(".mxgraph");
            for (var di = 0; di < mxEls.length; di++) {
                (function(el) {
                    var tabBar = el.previousElementSibling;
                    var hasTabs = tabBar && tabBar.classList.contains("drawio-tabs");
                    el.innerText = "";
                    GraphViewer.createViewerForElement(el, function(viewer) {
                        if (!hasTabs) return;
                        var initial = parseInt(tabBar.getAttribute("data-initial-page"), 10) || 0;
                        if (initial > 0) viewer.selectPage(initial);
                        tabBar.addEventListener("click", function(e) {
                            var tab = e.target.closest(".drawio-tab");
                            if (!tab) return;
                            var page = parseInt(tab.getAttribute("data-page"), 10);
                            viewer.selectPage(page);
                            var tabs = tabBar.querySelectorAll(".drawio-tab");
                            for (var j = 0; j < tabs.length; j++)
                                tabs[j].classList.toggle("active", j === page);
                        });
                    });
                })(mxEls[di]);
            }
        } catch (e) {
            console.error("Draw.io viewer initialization failed:", e);
        }
    }
})();
