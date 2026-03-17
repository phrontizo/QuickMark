import Foundation

enum MarkdownProcessor {

    /// Pattern matches `![alt](path.drawio)` or `![alt](path.drawio#fragment)` in markdown
    private static let drawioPattern = #/!\[([^\]]*)\]\(([^)#]+\.drawio)(?:#([^)]*))?\)/#

    /// Replaces `![alt](path.drawio)` references with draw.io viewer divs.
    /// Reads the .drawio XML file from disk and embeds it inline.
    /// An optional fragment selects a page by name or 0-based index:
    ///   `![](arch.drawio#Key Derivation)` or `![](arch.drawio#2)`
    static func resolveDrawioReferences(_ markdown: String, baseURL: URL) -> String {
        let matches = Array(markdown.matches(of: drawioPattern))

        var result = markdown
        // Process in reverse: match ranges are computed against the original
        // string, so replacing from the end keeps earlier ranges valid.
        for match in matches.reversed() {
            let relativePath = String(match.output.2)
            let decodedPath = relativePath.removingPercentEncoding ?? relativePath
            let fileURL = baseURL.appendingPathComponent(decodedPath)

            guard let xml = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue // Leave the reference as-is if file can't be read
            }

            let fragment = match.output.3.map(String.init) ?? ""
            let info = fragment.isEmpty ? "drawio" : "drawio page=\(fragment)"
            let fence = Self.fenceFor(content: xml)
            let fencedBlock = "\(fence)\(info)\n\(xml)\n\(fence)"
            result.replaceSubrange(match.range, with: fencedBlock)
        }

        return result
    }

    /// Returns a backtick fence long enough that it cannot appear in `content`.
    /// Uses 3 backticks (the minimum) unless the content contains a run of 3+.
    static func fenceFor(content: String) -> String {
        var maxRun = 0
        var current = 0
        for ch in content {
            if ch == "`" {
                current += 1
                if current > maxRun { maxRun = current }
            } else {
                current = 0
            }
        }
        return String(repeating: "`", count: max(3, maxRun + 1))
    }

    /// Entry point: preprocesses markdown before HTML rendering.
    static func process(_ markdown: String, baseURL: URL) -> String {
        return resolveDrawioReferences(markdown, baseURL: baseURL)
    }

    /// Reads a markdown file, trying UTF-8 first and falling back to ISO Latin 1.
    static func readFile(at url: URL) throws -> String {
        try FileUtilities.readFile(at: url)
    }
}
