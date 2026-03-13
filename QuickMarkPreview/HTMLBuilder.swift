import Foundation

struct HTMLBuilder {

    /// Pure function: assembles a complete HTML document from pre-loaded resources.
    /// `markdownBase64` is the preprocessed markdown encoded as base64.
    /// `scripts` are JS strings to inline (in order). `styles` are CSS strings.
    static func assembleHTML(
        markdownBase64: String,
        scripts: [String],
        styles: [String]
    ) -> String {
        var html = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"
        html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"

        for css in styles {
            html += "<style>\(css)</style>\n"
        }

        html += "</head>\n<body>\n"
        html += "<article id=\"content\"></article>\n"
        html += "<script id=\"markdown-source\" type=\"text/plain\">\(markdownBase64)</script>\n"

        for js in scripts {
            html += "<script>\(js)</script>\n"
        }

        html += "</body>\n</html>"
        return html
    }

    /// Resource names in the order they must be loaded.
    private static let scriptResources: [(name: String, ext: String)] = [
        ("markdown-it.min", "js"),
        ("markdown-it-task-lists.min", "js"),
        ("markdown-it-footnote.min", "js"),
        ("katex.min", "js"),
        ("texmath.min", "js"),
        ("highlight.min", "js"),
        ("mermaid.min", "js"),
        ("viewer-static.min", "js"),
        ("render", "js"),
    ]

    private static let styleResources: [(name: String, ext: String)] = [
        ("style", "css"),
        ("hljs-themes", "css"),
        ("katex-inlined.min", "css"),
        ("texmath.min", "css"),
    ]

    /// Reads a text resource from the bundle. Returns empty string if not found.
    private static func loadResource(_ name: String, ext: String, bundle: Bundle) -> String {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            NSLog("QuickMarkPreview: resource not found: \(name).\(ext)")
            return ""
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Builds a complete HTML document from markdown and bundled resources.
    static func build(markdown: String, bundle: Bundle) -> String {
        let markdownBase64 = Data(markdown.utf8).base64EncodedString()

        let scripts = scriptResources.map { loadResource($0.name, ext: $0.ext, bundle: bundle) }
        let styles = styleResources.map { loadResource($0.name, ext: $0.ext, bundle: bundle) }

        return assembleHTML(markdownBase64: markdownBase64, scripts: scripts, styles: styles)
    }
}
