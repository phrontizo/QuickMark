import Cocoa
import Quartz
import WebKit

@MainActor
class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var contentSize: CGSize = .zero
    nonisolated(unsafe) private var completionHandler: ((Error?) -> Void)?
    nonisolated(unsafe) private var tempFileURL: URL?
    private static let tempFilePrefix = "quickdrawio-"

    deinit {
        // Complete any pending handler so QuickLook doesn't hang if dismissed mid-load.
        // Dispatch to main queue since deinit may run on an arbitrary thread.
        if let handler = completionHandler {
            DispatchQueue.main.async { handler(nil) }
        }
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
        webView.allowsMagnification = true
        // Hidden until content is measured and scaled to prevent flash
        webView.alphaValue = 0
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        webView.appearance = AppearancePreference.drawio.nsAppearance
        do {
            let xml = try FileUtilities.readFile(at: url)
            let bundle = Bundle(for: type(of: self))

            guard let viewerURL = bundle.url(forResource: "viewer-static.min", withExtension: "js") else {
                let error = NSError(domain: "com.phrontizo.QuickMark.QuickMarkDrawio", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "viewer-static.min.js not found in bundle"])
                handler(error)
                return
            }

            let html = MxGraphHelper.buildHTML(xml: xml, viewerURL: viewerURL)

            if let old = tempFileURL { try? FileManager.default.removeItem(at: old) }
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.tempFilePrefix)\(UUID().uuidString).html")
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            tempFileURL = tempFile
            // Defer completion until diagram is measured so QuickLook
            // gets the right preferredContentSize before showing the window.
            self.completionHandler = handler
            webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            handler(error)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        if case .openExternal(let externalURL) = LinkPolicy.action(for: url) {
            NSWorkspace.shared.open(externalURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard completionHandler != nil else { return }
        pollForDiagram(attempts: 0)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickDrawio: navigation failed: %@", error.localizedDescription)
        completionHandler?(error)
        completionHandler = nil
        webView.alphaValue = 1
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("QuickDrawio: provisional navigation failed: %@", error.localizedDescription)
        completionHandler?(error)
        completionHandler = nil
        webView.alphaValue = 1
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("QuickDrawio: WebContent process terminated — reloading")
        // Complete any pending handler so QuickLook doesn't hang waiting
        completionHandler?(nil)
        completionHandler = nil
        webView.alphaValue = 1
        if let temp = tempFileURL {
            webView.loadFileURL(temp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
    }

    /// Polls for the rendered diagram element until it has non-zero dimensions,
    /// checking every 50ms for up to 3 seconds before giving up.
    private func pollForDiagram(attempts: Int) {
        let js = """
        (function() {
            if (!document.querySelector('svg')) return null;
            var d = document.documentElement;
            var w = d.scrollWidth;
            var h = d.scrollHeight;
            if (w > 0 && h > 0) return JSON.stringify({w: w, h: h});
            return null;
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            #if DEBUG
            if let error = error {
                NSLog("QuickDrawio: JS evaluation error: %@", error.localizedDescription)
            }
            #endif
            if let json = result as? String {
                self.applyDiagramSize(json: json)
            } else if attempts < 60 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.pollForDiagram(attempts: attempts + 1)
                }
            } else {
                NSLog("QuickDrawio: diagram poll timed out after 3 seconds")
                self.completionHandler?(nil)
                self.completionHandler = nil
                self.webView.alphaValue = 1
            }
        }
    }

    private func applyDiagramSize(json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let w = obj["w"] as? CGFloat,
              let h = obj["h"] as? CGFloat,
              w > 0, h > 0 else {
            NSLog("QuickDrawio: failed to parse diagram size from: %@", json)
            completionHandler?(nil)
            completionHandler = nil
            webView.alphaValue = 1
            return
        }

        contentSize = CGSize(width: w, height: h)

        // Tell QuickLook the ideal window size (capped at screen bounds)
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
        let prefW = min(w + 20, screen.width * 0.8)
        let prefH = min(h + 20, screen.height * 0.8)
        preferredContentSize = CGSize(width: prefW, height: prefH)

        // Signal QuickLook that the preview is ready (with correct size set)
        completionHandler?(nil)
        completionHandler = nil

        // Scale diagram to fit the current view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let viewW = self.view.bounds.width
            let viewH = self.view.bounds.height
            if w > viewW || h > viewH {
                let scale = min(viewW / w, viewH / h)
                self.webView.magnification = scale
            }
            self.webView.alphaValue = 1
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard contentSize.width > 0, contentSize.height > 0 else { return }
        // Re-fit on window resize
        let viewW = view.bounds.width
        let viewH = view.bounds.height
        let scale = min(viewW / contentSize.width, viewH / contentSize.height, 1.0)
        webView.magnification = scale
    }

}
