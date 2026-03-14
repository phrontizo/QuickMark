import Foundation

/// Shared utilities for draw.io diagram embedding.
enum MxGraphHelper {

    /// Creates an HTML div that the draw.io viewer will render.
    ///
    /// Escaping strategy:
    /// 1. JSON-escape the XML (escape \, ", newlines, tabs)
    /// 2. Build the JSON object string
    /// 3. HTML-attribute-escape the JSON string (escape &, <, >, and ")
    static func drawioDiv(xml: String) -> String {
        let jsonEscaped = xml
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        let json = "{\"highlight\":\"#0000ff\",\"nav\":true,\"resize\":true,\"xml\":\"\(jsonEscaped)\"}"

        let htmlEscaped = json
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return "<div class=\"mxgraph\" data-mxgraph=\"\(htmlEscaped)\"></div>"
    }

    /// Builds a complete HTML document for rendering a draw.io diagram.
    static func buildHTML(xml: String, viewerURL: URL) -> String {
        let div = drawioDiv(xml: xml)
        let escapedURL = viewerURL.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        html, body { margin: 0; padding: 0; }
        @media (prefers-color-scheme: dark) {
            body { background: #0d1117; }
        }
        </style>
        </head>
        <body>
        \(div)
        <script src="\(escapedURL)"></script>
        <script>
        if (typeof GraphViewer !== "undefined") { GraphViewer.processElements(); }
        </script>
        </body>
        </html>
        """
    }
}
