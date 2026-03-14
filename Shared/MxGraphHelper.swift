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
}
