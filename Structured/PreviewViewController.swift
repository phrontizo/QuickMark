import Cocoa
import Quartz
import WebKit

@MainActor
class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {

    private var webView: WKWebView!
    private var tempFileURL: URL?
    private static let tempFilePrefix = "quickstructured-"

    deinit {
        if let temp = tempFileURL { try? FileManager.default.removeItem(at: temp) }
    }

    override func loadView() {
        cleanupStaleTempFiles()
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        webView.appearance = AppearancePreference.structured.nsAppearance
        do {
            let content: String
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                content = utf8
            } else {
                content = try String(contentsOf: url, encoding: .isoLatin1)
            }

            let lang = Self.language(for: url.pathExtension)
            let bundle = Bundle(for: type(of: self))
            let html = Self.buildHTML(content: content, language: lang, bundle: bundle)

            if let old = tempFileURL { try? FileManager.default.removeItem(at: old) }
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.tempFilePrefix)\(UUID().uuidString).html")
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            tempFileURL = tempFile
            webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            handler(nil)
        } catch {
            handler(error)
        }
    }

    // MARK: - Language Detection

    nonisolated static func language(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "yml", "yaml": return "yaml"
        case "json": return "json"
        case "toml": return "toml"
        default: return "plaintext"
        }
    }

    // MARK: - HTML Builder

    nonisolated static func buildHTML(content: String, language: String, bundle: Bundle) -> String {
        let escaped = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let hljsURL = bundle.url(forResource: "highlight.min", withExtension: "js")
        let themeURL = bundle.url(forResource: "hljs-themes", withExtension: "css")
        let styleURL = bundle.url(forResource: "structured-style", withExtension: "css")

        var html = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"

        if let url = themeURL {
            html += "<link rel=\"stylesheet\" href=\"\(url.absoluteString)\">\n"
        }
        if let url = styleURL {
            html += "<link rel=\"stylesheet\" href=\"\(url.absoluteString)\">\n"
        }

        html += "</head>\n<body>\n"
        html += "<pre><code class=\"language-\(language)\">\(escaped)</code></pre>\n"

        if let url = hljsURL {
            html += "<script src=\"\(url.absoluteString)\"></script>\n"
        }

        html += "<script>\n"
        html += "(function() {\n"
        html += "  var code = document.querySelector('code');\n"
        html += "  if (!code) return;\n"
        html += "  var lang = (code.className.match(/language-(\\w+)/) || [])[1] || '';\n"
        html += "  var highlighted = code.textContent;\n"
        html += "  try {\n"
        html += "    if (typeof hljs !== 'undefined' && lang) {\n"
        html += "      highlighted = hljs.highlight(code.textContent, {language: lang}).value;\n"
        html += "    }\n"
        html += "  } catch(e) { highlighted = code.innerHTML; }\n"
        html += "  var lines = highlighted.split('\\n');\n"
        html += "  if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();\n"
        html += "  code.innerHTML = lines.map(function(line, i) {\n"
        html += "    return '<span class=\"line\"><span class=\"line-number\">' + (i + 1) + '</span>' + line + '</span>';\n"
        html += "  }).join('\\n');\n"
        html += "  code.classList.add('hljs');\n"
        html += "  code.setAttribute('data-highlighted', 'yes');\n"
        html += "})();\n"
        html += "</script>\n"

        html += "</body>\n</html>"
        return html
    }

    // MARK: - Temp File Cleanup

    private func cleanupStaleTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-300) // 5 minutes ago
        for file in files where file.lastPathComponent.hasPrefix(Self.tempFilePrefix) && file.pathExtension == "html" {
            guard let created = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  created < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
