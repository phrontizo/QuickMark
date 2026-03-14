import XCTest
import WebKit

/// Integration tests that load HTML in a real WKWebView to verify
/// markdown actually renders (catches CSP issues, broken scripts, etc.)
class RenderingTests: XCTestCase, WKNavigationDelegate {

    private var webView: WKWebView!
    private var navigationExpectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        webView.navigationDelegate = self
    }

    override func tearDown() {
        webView.navigationDelegate = nil
        webView = nil
        super.tearDown()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationExpectation?.fulfill()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        XCTFail("Navigation failed: \(error.localizedDescription)")
        navigationExpectation?.fulfill()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        XCTFail("Provisional navigation failed: \(error.localizedDescription)")
        navigationExpectation?.fulfill()
    }

    // MARK: - Helpers

    /// Builds HTML, loads it in WKWebView, waits for navigation to finish.
    private func loadMarkdown(_ markdown: String) throws {
        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: markdown, bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-render-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        navigationExpectation = expectation(description: "Page loaded")
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navigationExpectation!], timeout: 10)
    }

    /// Evaluates JS and returns the result synchronously via an expectation.
    private func evaluateJS(_ script: String) -> Any? {
        var jsResult: Any?
        let exp = expectation(description: "JS evaluation")
        webView.evaluateJavaScript(script) { result, error in
            if let error = error { XCTFail("JS error: \(error.localizedDescription)") }
            jsResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
        return jsResult
    }

    // MARK: - Tests

    func testContentElementHasRenderedHTML() throws {
        try loadMarkdown("# Hello\n\nWorld")

        let length = evaluateJS("document.getElementById('content').innerHTML.length") as? Int
        XCTAssertNotNil(length, "Should be able to read content innerHTML length")
        XCTAssertGreaterThan(length ?? 0, 0, "Content element should not be empty — scripts must execute")
    }

    func testHeadingRendersAsH1() throws {
        try loadMarkdown("# Title")

        let tag = evaluateJS("document.querySelector('#content h1')?.tagName") as? String
        XCTAssertEqual(tag, "H1", "# heading should render as <h1>")
    }

    func testBoldRendersAsStrong() throws {
        try loadMarkdown("Some **bold** text")

        let text = evaluateJS("document.querySelector('#content strong')?.textContent") as? String
        XCTAssertEqual(text, "bold", "**bold** should render as <strong>")
    }

    func testCodeBlockRendersWithHighlighting() throws {
        try loadMarkdown("```swift\nlet x = 42\n```")

        let hasHljs = evaluateJS("document.querySelector('#content pre code .hljs-keyword') !== null") as? Bool
        XCTAssertEqual(hasHljs, true, "Code block should have syntax highlighting applied")
    }

    func testInlineHTMLIsNotRendered() throws {
        try loadMarkdown("before <script>alert(1)</script> after")

        let scripts = evaluateJS("document.querySelectorAll('#content script').length") as? Int
        XCTAssertEqual(scripts, 0, "html:false should prevent <script> tags from being rendered")
    }

    // MARK: - Draw.io Tests

    func testDrawioSampleRenders() throws {
        let sampleURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // QuickMarkTests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("TestFiles/sample.drawio")

        let xml = try String(contentsOf: sampleURL, encoding: .utf8)
        let bundle = Bundle(for: type(of: self))

        guard let viewerURL = bundle.url(forResource: "viewer-static.min", withExtension: "js") else {
            XCTFail("viewer-static.min.js not found in test bundle")
            return
        }

        let div = MxGraphHelper.drawioDiv(xml: xml)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
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

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-drawio-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        navigationExpectation = expectation(description: "DrawIO page loaded")
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navigationExpectation!], timeout: 10)

        // The viewer replaces the .mxgraph div contents — poll briefly for rendering
        var rendered = false
        for _ in 0..<20 {
            let hasSVG = evaluateJS(
                "document.querySelector('.mxgraph svg') !== null || document.querySelector('svg') !== null"
            ) as? Bool
            if hasSVG == true { rendered = true; break }
            let waitExp = expectation(description: "poll wait")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { waitExp.fulfill() }
            wait(for: [waitExp], timeout: 1)
        }
        XCTAssertTrue(rendered, "Draw.io viewer should render an SVG from sample.drawio")
    }

    func testDrawioEmbeddedInMarkdownRenders() throws {
        let testFilesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestFiles")

        let markdown = try String(contentsOf: testFilesDir.appendingPathComponent("drawio-test.md"), encoding: .utf8)
        let processed = MarkdownProcessor.process(markdown, baseURL: testFilesDir)

        // Verify the preprocessor produced a drawio fenced block
        XCTAssertTrue(processed.contains("```drawio\n"), "Preprocessor should create drawio fence block")

        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: processed, bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-drawio-md-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        navigationExpectation = expectation(description: "Drawio-in-markdown page loaded")
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navigationExpectation!], timeout: 10)

        // The drawio fence rule should produce a .mxgraph div, then GraphViewer renders it
        var rendered = false
        for _ in 0..<40 {
            let hasSVG = evaluateJS(
                "document.querySelector('.mxgraph svg') !== null || document.querySelector('svg') !== null"
            ) as? Bool
            if hasSVG == true { rendered = true; break }
            let waitExp = expectation(description: "poll wait")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { waitExp.fulfill() }
            wait(for: [waitExp], timeout: 1)
        }
        XCTAssertTrue(rendered, "Draw.io diagram embedded in markdown should render as SVG")
    }

    // MARK: - Test File Rendering

    func testMultipleTestFilesRender() throws {
        let testFilesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // QuickMarkTests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("TestFiles")

        let mdFiles = try FileManager.default.contentsOfDirectory(at: testFilesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }

        XCTAssertGreaterThan(mdFiles.count, 0, "Should find test .md files")

        for file in mdFiles {
            let markdown = try String(contentsOf: file, encoding: .utf8)
            let bundle = Bundle(for: type(of: self))
            let html = HTMLBuilder.build(markdown: markdown, bundle: bundle)

            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("test-\(UUID().uuidString).html")
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

            navigationExpectation = expectation(description: "Page loaded: \(file.lastPathComponent)")
            webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            wait(for: [navigationExpectation!], timeout: 15)

            let length = evaluateJS("document.getElementById('content').innerHTML.length") as? Int
            XCTAssertGreaterThan(length ?? 0, 0, "\(file.lastPathComponent) should render non-empty content")
        }
    }
}
