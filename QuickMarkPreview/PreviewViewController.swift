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
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let baseURL = url.deletingLastPathComponent()
            let processed = MarkdownProcessor.process(markdown, baseURL: baseURL)
            let bundle = Bundle(for: type(of: self))
            let html = HTMLBuilder.build(markdown: processed, bundle: bundle)
            webView.loadHTMLString(html, baseURL: baseURL)
            handler(nil)
        } catch {
            handler(error)
        }
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

        // All links open externally:
        // - Local files (including .md): open with default app via NSWorkspace
        // - External URLs: open in default browser via NSWorkspace
        NSWorkspace.shared.open(url)
    }
}
