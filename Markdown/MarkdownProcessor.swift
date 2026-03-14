import Foundation

enum MarkdownProcessor {

    /// Pattern matches `![alt](path.drawio)` in markdown
    private static let drawioPattern = #/!\[([^\]]*)\]\(([^)]+\.drawio)\)/#

    /// Replaces `![alt](path.drawio)` references with draw.io viewer divs.
    /// Reads the .drawio XML file from disk and embeds it inline.
    static func resolveDrawioReferences(_ markdown: String, baseURL: URL) -> String {
        let matches = Array(markdown.matches(of: drawioPattern))

        var result = markdown
        // Process in reverse: match ranges are computed against the original
        // string, so replacing from the end keeps earlier ranges valid.
        for match in matches.reversed() {
            let relativePath = String(match.output.2)
            let fileURL = baseURL.appendingPathComponent(relativePath)

            guard let xml = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue // Leave the reference as-is if file can't be read
            }

            let fencedBlock = "```drawio\n\(xml)\n```"
            result.replaceSubrange(match.range, with: fencedBlock)
        }

        return result
    }

    /// Entry point: preprocesses markdown before HTML rendering.
    static func process(_ markdown: String, baseURL: URL) -> String {
        return resolveDrawioReferences(markdown, baseURL: baseURL)
    }

    /// Reads a markdown file, trying UTF-8 first and falling back to ISO Latin 1.
    static func readFile(at url: URL) throws -> String {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            return utf8
        }
        return try String(contentsOf: url, encoding: .isoLatin1)
    }
}
