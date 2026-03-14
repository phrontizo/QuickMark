import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            try renderMarkdown(at: url)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func renderMarkdown(at url: URL) throws {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let baseURL = url.deletingLastPathComponent()
        let processed = MarkdownProcessor.process(markdown, baseURL: baseURL)
        let bundle = Bundle(for: type(of: self))
        var html = HTMLBuilder.build(markdown: processed, bundle: bundle)

        // Inject <base> tag so relative image paths resolve against the
        // markdown file's directory, not the temp file location.
        let baseTag = "<base href=\"\(baseURL.absoluteString)\">"
        html = html.replacingOccurrences(of: "<head>\n", with: "<head>\n\(baseTag)\n")

        // Write to temp file and use loadFileURL instead of loadHTMLString,
        // because loadHTMLString doesn't grant WKWebView access to local
        // file resources (images, SVGs) in a sandboxed extension.
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickmark-preview.html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }
}

extension PreviewViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Allow the initial page load
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)

        // Local .md links: render inline in the preview
        if url.isFileURL && ["md", "markdown"].contains(url.pathExtension.lowercased()) {
            try? renderMarkdown(at: url)
            return
        }

        // Everything else opens externally
        NSWorkspace.shared.open(url)
    }
}
