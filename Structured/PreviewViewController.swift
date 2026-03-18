import Cocoa
import Quartz
import WebKit

@MainActor
class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    nonisolated(unsafe) private var tempFileURL: URL?
    private static let tempFilePrefix = "quickstructured-"

    deinit {
        if let temp = tempFileURL { try? FileManager.default.removeItem(at: temp) }
    }

    override func loadView() {
        FileUtilities.cleanupStaleTempFiles(prefix: Self.tempFilePrefix)
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        webView.appearance = AppearancePreference.structured.nsAppearance
        do {
            let content = try FileUtilities.readFile(at: url)

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
        case "xml": return "xml"
        default: return "plaintext"
        }
    }

    // MARK: - HTML Builder

    nonisolated static func buildHTML(content: String, language: String, bundle: Bundle) -> String {
        let escaped = content.htmlEscaped

        let hljsURL = bundle.url(forResource: "highlight.min", withExtension: "js")
        let themeURL = bundle.url(forResource: "hljs-themes", withExtension: "css")
        let styleURL = bundle.url(forResource: "structured-style", withExtension: "css")

        var html = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n"

        if let url = themeURL {
            html += "<link rel=\"stylesheet\" href=\"\(url.absoluteString.htmlEscaped)\">\n"
        }
        if let url = styleURL {
            html += "<link rel=\"stylesheet\" href=\"\(url.absoluteString.htmlEscaped)\">\n"
        }

        html += "</head>\n<body>\n"
        html += "<pre><code class=\"language-\(language.htmlEscaped)\">\(escaped)</code></pre>\n"

        if let url = hljsURL {
            html += "<script src=\"\(url.absoluteString.htmlEscaped)\"></script>\n"
        }

        html += "<script>\n"
        html += "(function() {\n"
        html += "  var code = document.querySelector('code');\n"
        html += "  if (!code) return;\n"
        html += "  var lang = (code.className.match(/language-(\\w+)/) || [])[1] || '';\n"
        html += "  var highlighted = code.innerHTML;\n"
        html += "  try {\n"
        html += "    if (typeof hljs !== 'undefined' && lang) {\n"
        html += "      highlighted = hljs.highlight(code.textContent, {language: lang}).value;\n"
        html += "    }\n"
        html += "  } catch(e) {}\n"
        html += "  var lines = highlighted.split('\\n');\n"
        html += "  if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();\n"
        html += "  code.innerHTML = lines.map(function(line, i) {\n"
        html += "    return '<span class=\"line\"><span class=\"line-number\">' + (i + 1) + '</span>' + line + '</span>';\n"
        html += "  }).join('');\n"
        html += "  code.classList.add('hljs');\n"
        html += "  code.setAttribute('data-highlighted', 'yes');\n"
        html += "})();\n"
        html += "</script>\n"

        html += "</body>\n</html>"
        return html
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickStructured: navigation failed: %@", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickStructured: provisional navigation failed: %@", error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("QuickStructured: WebContent process terminated — reloading")
        if let temp = tempFileURL {
            webView.loadFileURL(temp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
    }
}
