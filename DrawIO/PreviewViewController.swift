import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var contentSize: CGSize = .zero
    private var completionHandler: ((Error?) -> Void)?

    override func loadView() {
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
        do {
            let xml = try String(contentsOf: url, encoding: .utf8)
            let bundle = Bundle(for: type(of: self))
            let viewerJS = loadResource("viewer-static.min", ext: "js", bundle: bundle)

            let jsonEscaped = xml
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            let json = "{\"highlight\":\"#0000ff\",\"nav\":true,\"resize\":true,\"xml\":\"\(jsonEscaped)\"}"
            let htmlEscaped = json
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            let div = "<div class=\"mxgraph\" data-mxgraph=\"\(htmlEscaped)\"></div>"

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
            <script>\(viewerJS)</script>
            <script>
            if (typeof GraphViewer !== "undefined") { GraphViewer.processElements(); }
            </script>
            </body>
            </html>
            """

            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("quickdrawio-preview.html")
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            // Defer completion until diagram is measured so QuickLook
            // gets the right preferredContentSize before showing the window.
            self.completionHandler = handler
            webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            handler(error)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for viewer-static.min.js to finish rendering the diagram
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.measureAndFit()
        }
    }

    private func measureAndFit() {
        // Measure the actual rendered diagram, not the viewport
        let js = """
        (function() {
            var el = document.querySelector('.mxgraph > div') || document.querySelector('svg') || document.body;
            var r = el.getBoundingClientRect();
            return JSON.stringify({w: Math.ceil(r.width), h: Math.ceil(r.height)});
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self,
                  let json = result as? String,
                  let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let w = obj["w"] as? CGFloat,
                  let h = obj["h"] as? CGFloat,
                  w > 0, h > 0 else {
                self?.completionHandler?(nil)
                self?.completionHandler = nil
                self?.webView.alphaValue = 1
                return
            }

            self.contentSize = CGSize(width: w, height: h)

            // Tell QuickLook the ideal window size (capped at screen bounds)
            let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
            let prefW = min(w + 20, screen.width * 0.8)
            let prefH = min(h + 20, screen.height * 0.8)
            self.preferredContentSize = CGSize(width: prefW, height: prefH)

            // Signal QuickLook that the preview is ready (with correct size set)
            self.completionHandler?(nil)
            self.completionHandler = nil

            // Scale diagram to fit the current view
            DispatchQueue.main.async {
                let viewW = self.view.bounds.width
                let viewH = self.view.bounds.height
                if w > viewW || h > viewH {
                    let scale = min(viewW / w, viewH / h)
                    self.webView.magnification = scale
                }
                self.webView.alphaValue = 1
            }
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

    private func loadResource(_ name: String, ext: String, bundle: Bundle) -> String {
        guard let resURL = bundle.url(forResource: name, withExtension: ext) else {
            NSLog("QuickDrawio: resource not found: \(name).\(ext)")
            return ""
        }
        return (try? String(contentsOf: resURL, encoding: .utf8)) ?? ""
    }
}
