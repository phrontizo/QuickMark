import Foundation

/// Shared utilities for draw.io diagram embedding.
enum MxGraphHelper {

    /// Creates an HTML div that the draw.io viewer will render.
    ///
    /// Escaping strategy:
    /// 1. JSON-encode the config object using JSONSerialization (handles all
    ///    control characters, backslashes, quotes, etc.)
    /// 2. HTML-attribute-escape the JSON string (escape &, <, >, and ")
    static func drawioDiv(xml: String) -> String {
        let config: [String: Any] = [
            "highlight": "#0000ff",
            "nav": true,
            "resize": true,
            "xml": xml
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]),
              let json = String(data: jsonData, encoding: .utf8) else {
            return "<div class=\"mxgraph\" data-mxgraph=\"{}\"></div>"
        }

        let htmlEscaped = json.htmlEscaped

        return "<div class=\"mxgraph\" data-mxgraph=\"\(htmlEscaped)\"></div>"
    }

    /// Builds a complete HTML document for rendering a draw.io diagram.
    static func buildHTML(xml: String, viewerURL: URL) -> String {
        let div = drawioDiv(xml: xml)
        let escapedURL = viewerURL.absoluteString.htmlEscaped

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        html, body { margin: 0; padding: 0; }
        .drawio-tabs {
            display: none; margin: 0; padding: 0;
            border-bottom: 1px solid #d0d0d0;
            background: #f5f5f5;
            overflow-x: auto;
            font-family: -apple-system, system-ui, sans-serif;
        }
        .drawio-tab {
            padding: 5px 14px; cursor: pointer; border: none;
            background: transparent; border-bottom: 2px solid transparent;
            white-space: nowrap; color: #666; font-size: 12px;
        }
        .drawio-tab.active { color: #1a1a1a; border-bottom-color: #0969da; font-weight: 600; }
        @media (prefers-color-scheme: dark) {
            body { background: #0d1117; }
            .drawio-tabs { background: #161b22; border-color: #30363d; }
            .drawio-tab { color: #8b949e; }
            .drawio-tab.active { color: #e6edf3; border-bottom-color: #58a6ff; }
        }
        </style>
        </head>
        <body>
        <div id="drawio-tabs" class="drawio-tabs"></div>
        \(div)
        <script src="\(escapedURL)"></script>
        <script>
        (function() {
            var el = document.querySelector(".mxgraph");
            if (!el || typeof GraphViewer === "undefined") return;
            var cfg = JSON.parse(el.getAttribute("data-mxgraph"));
            var doc = new DOMParser().parseFromString(cfg.xml, "text/xml");
            var diagrams = doc.querySelectorAll("diagram");
            var tabBar = document.getElementById("drawio-tabs");
            if (diagrams.length > 1) {
                tabBar.style.display = "flex";
                for (var i = 0; i < diagrams.length; i++) {
                    var btn = document.createElement("button");
                    btn.className = "drawio-tab" + (i === 0 ? " active" : "");
                    btn.textContent = diagrams[i].getAttribute("name") || "Page " + (i + 1);
                    btn.setAttribute("data-page", i);
                    tabBar.appendChild(btn);
                }
            }
            el.innerText = "";
            GraphViewer.createViewerForElement(el, function(viewer) {
                if (diagrams.length <= 1) return;
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
        })();
        </script>
        </body>
        </html>
        """
    }
}
