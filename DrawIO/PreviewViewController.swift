import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var contentSize: CGSize = .zero
    private var completionHandler: ((Error?) -> Void)?
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
        webView.allowsMagnification = true
        webView.appearance = AppearancePreference.drawio.nsAppearance
        // Hidden until content is measured and scaled to prevent flash
        webView.alphaValue = 0
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let xml = try String(contentsOf: url, encoding: .utf8)
            let bundle = Bundle(for: type(of: self))

            guard let viewerURL = bundle.url(forResource: "viewer-static.min", withExtension: "js") else {
                let error = NSError(domain: "com.quickmark.QuickMarkDrawio", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "viewer-static.min.js not found in bundle"])
                handler(error)
                return
            }

            let div = MxGraphHelper.drawioDiv(xml: xml)

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <style>
            html, body { margin: 0; padding: 0; }
            @media (prefers-color-scheme: dark) {
                body { background: #0d1117; }
            }
            </style>
            </head>
            <body>
            \(div)
            <script src="\(viewerURL.absoluteString)"></script>
            <script>
            if (typeof GraphViewer !== "undefined") { GraphViewer.processElements(); }
            </script>
            </body>
            </html>
            """

            if let old = tempFileURL { try? FileManager.default.removeItem(at: old) }
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("quickdrawio-\(UUID().uuidString).html")
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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

    /// Polls for the rendered diagram element until it has non-zero dimensions,
    /// checking every 50ms for up to 3 seconds before giving up.
    private func pollForDiagram(attempts: Int) {
        let js = """
        (function() {
            var el = document.querySelector('.mxgraph > div') || document.querySelector('svg');
            if (el) {
                var r = el.getBoundingClientRect();
                if (r.width > 0 && r.height > 0) {
                    return JSON.stringify({w: Math.ceil(r.width), h: Math.ceil(r.height)});
                }
            }
            return null;
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self else { return }
            if let json = result as? String {
                self.applyDiagramSize(json: json)
            } else if attempts < 60 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.pollForDiagram(attempts: attempts + 1)
                }
            } else {
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
