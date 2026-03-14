import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!
    private var tempFileURL: URL?

    deinit {
        if let temp = tempFileURL { try? FileManager.default.removeItem(at: temp) }
    }

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
        let markdown: String
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            markdown = utf8
        } else {
            markdown = try String(contentsOf: url, encoding: .isoLatin1)
        }
        let baseURL = url.deletingLastPathComponent()
        let processed = MarkdownProcessor.process(markdown, baseURL: baseURL)
        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: processed, bundle: bundle, baseHref: baseURL.absoluteString)

        // Write to temp file and use loadFileURL instead of loadHTMLString,
        // because loadHTMLString doesn't grant WKWebView access to local
        // file resources (images, SVGs) in a sandboxed extension.
        if let old = tempFileURL { try? FileManager.default.removeItem(at: old) }
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickmark-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        tempFileURL = tempFile
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
            do {
                try renderMarkdown(at: url)
            } catch {
                NSLog("QuickMarkPreview: failed to render linked markdown: %@", error.localizedDescription)
            }
            return
        }

        // Only open http/https links externally (block custom URL schemes)
        if let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            NSWorkspace.shared.open(url)
        }
    }
}
