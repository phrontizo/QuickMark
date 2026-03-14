import Cocoa
import Quartz
import WebKit

@MainActor
class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {

    private var webView: WKWebView!
    private var tempFileURL: URL?
    private static let tempFilePrefix = "quickmark-"

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
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        webView.appearance = AppearancePreference.markdown.nsAppearance
        do {
            try renderMarkdown(at: url)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    private func renderMarkdown(at url: URL) throws {
        let markdown = try MarkdownProcessor.readFile(at: url)
        let baseURL = url.deletingLastPathComponent()
        let processed = MarkdownProcessor.process(markdown, baseURL: baseURL)
        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: processed, bundle: bundle, baseHref: baseURL.absoluteString)

        // Write to temp file and use loadFileURL instead of loadHTMLString,
        // because loadHTMLString doesn't grant WKWebView access to local
        // file resources (images, SVGs) in a sandboxed extension.
        if let old = tempFileURL { try? FileManager.default.removeItem(at: old) }
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.tempFilePrefix)\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        tempFileURL = tempFile
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

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

        switch LinkPolicy.action(for: url) {
        case .renderMarkdown(let fileURL):
            do {
                try renderMarkdown(at: fileURL)
            } catch {
                NSLog("QuickMarkPreview: failed to render linked markdown: %@", error.localizedDescription)
            }
        case .openExternal(let externalURL):
            NSWorkspace.shared.open(externalURL)
        case .block:
            break
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickMarkPreview: navigation failed: %@", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickMarkPreview: provisional navigation failed: %@", error.localizedDescription)
    }
}
