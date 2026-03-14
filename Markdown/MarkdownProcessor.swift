import Foundation

struct MarkdownProcessor {

    /// Creates an HTML div that the draw.io viewer will render.
    /// Escaping strategy:
    /// 1. JSON-escape the XML (escape \, ", newlines, tabs)
    /// 2. Build the JSON object string
    /// 3. HTML-attribute-escape the JSON string (escape & and ")
    static func drawioDiv(xml: String) -> String {
        // Step 1: JSON-escape the XML for embedding as a JSON string value
        let jsonEscaped = xml
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        // Step 2: Build JSON object
        let json = "{\"highlight\":\"#0000ff\",\"nav\":true,\"resize\":true,\"xml\":\"\(jsonEscaped)\"}"

        // Step 3: HTML-attribute-escape the JSON for use in data-mxgraph="..."
        let htmlEscaped = json
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return "<div class=\"mxgraph\" data-mxgraph=\"\(htmlEscaped)\"></div>"
    }

    /// Pattern matches `![alt](path.drawio)` in markdown
    private static let drawioPattern = try! NSRegularExpression(
        pattern: #"!\[([^\]]*)\]\(([^)]+\.drawio)\)"#,
        options: []
    )

    /// Replaces `![alt](path.drawio)` references with draw.io viewer divs.
    /// Reads the .drawio XML file from disk and embeds it inline.
    static func resolveDrawioReferences(_ markdown: String, baseURL: URL) -> String {
        let nsMarkdown = markdown as NSString
        let matches = drawioPattern.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length))

        var result = markdown
        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            let pathRange = match.range(at: 2)
            let relativePath = nsMarkdown.substring(with: pathRange)
            let fileURL = baseURL.appendingPathComponent(relativePath)

            guard let xml = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue // Leave the reference as-is if file can't be read
            }

            let fullRange = match.range(at: 0)
            let div = drawioDiv(xml: xml)
            let swiftRange = Range(fullRange, in: result)!
            result.replaceSubrange(swiftRange, with: div)
        }

        return result
    }

    /// Entry point: preprocesses markdown before HTML rendering.
    static func process(_ markdown: String, baseURL: URL) -> String {
        var result = markdown
        result = resolveDrawioReferences(result, baseURL: baseURL)
        return result
    }
}
