import Foundation

enum MarkdownProcessor {

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
            let fencedBlock = "```drawio\n\(xml)\n```"
            guard let swiftRange = Range(fullRange, in: result) else { continue }
            result.replaceSubrange(swiftRange, with: fencedBlock)
        }

        return result
    }

    /// Entry point: preprocesses markdown before HTML rendering.
    static func process(_ markdown: String, baseURL: URL) -> String {
        return resolveDrawioReferences(markdown, baseURL: baseURL)
    }
}
