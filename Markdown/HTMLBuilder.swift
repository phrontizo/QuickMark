import Foundation

enum HTMLBuilder {

    /// Pure function: assembles a complete HTML document referencing resources by URL.
    /// Scripts and styles are loaded by the browser via file:// URLs rather than
    /// inlined, avoiding holding multi-megabyte JS libraries in memory.
    static func assembleHTML(
        markdownBase64: String,
        scriptURLs: [URL],
        styleURLs: [URL],
        baseHref: String? = nil
    ) -> String {
        var html = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"
        html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"

        if let href = baseHref {
            html += "<base href=\"\(href.htmlEscaped)\">\n"
        }

        for url in styleURLs {
            html += "<link rel=\"stylesheet\" href=\"\(url.absoluteString.htmlEscaped)\">\n"
        }

        html += "</head>\n<body>\n"
        html += "<article id=\"content\"></article>\n"
        html += "<script id=\"markdown-source\" type=\"text/plain\">\(markdownBase64)</script>\n"

        for url in scriptURLs {
            html += "<script src=\"\(url.absoluteString.htmlEscaped)\"></script>\n"
        }

        html += "</body>\n</html>"
        return html
    }

    /// Resource names in the order they must be loaded.
    private static let scriptResources: [(name: String, ext: String)] = [
        ("markdown-it.min", "js"),
        ("markdown-it-task-lists.min", "js"),
        ("markdown-it-footnote.min", "js"),
        ("markdownItAnchor.umd", "js"),
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

    /// Builds a complete HTML document from markdown and bundled resources.
    static func build(markdown: String, bundle: Bundle, baseHref: String? = nil) -> String {
        let markdownBase64 = Data(markdown.utf8).base64EncodedString()

        let scriptURLs = scriptResources.compactMap { res -> URL? in
            guard let url = bundle.url(forResource: res.name, withExtension: res.ext) else {
                NSLog("QuickMarkPreview: resource not found: %@.%@", res.name, res.ext)
                return nil
            }
            return url
        }

        let styleURLs = styleResources.compactMap { res -> URL? in
            guard let url = bundle.url(forResource: res.name, withExtension: res.ext) else {
                NSLog("QuickMarkPreview: resource not found: %@.%@", res.name, res.ext)
                return nil
            }
            return url
        }

        return assembleHTML(markdownBase64: markdownBase64, scriptURLs: scriptURLs, styleURLs: styleURLs, baseHref: baseHref)
    }
}
