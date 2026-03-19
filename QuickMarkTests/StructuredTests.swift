import XCTest
import WebKit

class StructuredTests: XCTestCase {

    // MARK: - Language Detection

    func testYmlExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "yml"), "yaml")
    }

    func testYamlExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "yaml"), "yaml")
    }

    func testJsonExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "json"), "json")
    }

    func testTomlExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "toml"), "toml")
    }

    func testUnknownExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "txt"), "plaintext")
    }

    func testCaseInsensitiveExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "YML"), "yaml")
        XCTAssertEqual(PreviewViewController.language(for: "JSON"), "json")
        XCTAssertEqual(PreviewViewController.language(for: "TOML"), "toml")
    }

    func testXmlExtension() {
        XCTAssertEqual(PreviewViewController.language(for: "xml"), "xml")
    }

    func testXmlCaseInsensitive() {
        XCTAssertEqual(PreviewViewController.language(for: "XML"), "xml")
    }

    // MARK: - HTML Escaping

    func testBuildHTMLEscapesContent() {
        let content = "<script>alert(\"xss\")</script> & more"
        let html = PreviewViewController.buildHTML(
            content: content, language: "yaml", bundle: Bundle(for: type(of: self)))

        XCTAssertTrue(html.contains("&lt;script&gt;"), "Angle brackets should be escaped")
        XCTAssertTrue(html.contains("&amp; more"), "Ampersands should be escaped")
        XCTAssertTrue(html.contains("&quot;xss&quot;"), "Quotes should be escaped")
        XCTAssertFalse(html.contains("<script>alert"), "Raw script tags must not appear")
    }

    func testBuildHTMLSetsLanguageClass() {
        let html = PreviewViewController.buildHTML(
            content: "key: value", language: "yaml", bundle: Bundle(for: type(of: self)))
        XCTAssertTrue(html.contains("language-yaml"), "Should set language class for highlight.js")
    }

    func testBuildHTMLIncludesHighlightJS() {
        let html = PreviewViewController.buildHTML(
            content: "test", language: "json", bundle: Bundle(for: type(of: self)))
        XCTAssertTrue(html.contains("highlight.min.js"), "Should reference highlight.js")
    }

    func testBuildHTMLIncludesRenderScript() {
        let html = PreviewViewController.buildHTML(
            content: "test", language: "json", bundle: Bundle(for: type(of: self)))
        XCTAssertTrue(html.contains("structured-render.js"), "Should reference structured-render.js")
    }

    // MARK: - Line Spacing

    func testNoDoubleSpacingBetweenLines() throws {
        let bundle = Bundle(for: type(of: self))
        let content = "line1\nline2\nline3"
        let html = PreviewViewController.buildHTML(content: content, language: "yaml", bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-structured-spacing-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationHelper { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        // Block-level .line spans inside <pre> must not be separated by newline
        // characters, otherwise <pre> renders each \n as an extra blank line.
        let jsExp = expectation(description: "JS check")
        var hasNewlineBetweenSpans = true
        webView.evaluateJavaScript(
            "document.querySelector('code').innerHTML.indexOf('</span>\\n<span class=\"line\">') === -1"
        ) { result, _ in
            hasNewlineBetweenSpans = !(result as? Bool ?? false)
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertFalse(hasNewlineBetweenSpans,
                       "Line spans must not be separated by newlines inside <pre> — causes double spacing")
    }

    // MARK: - XML Rendering

    func testXmlHighlightingProducesOutput() throws {
        let bundle = Bundle(for: type(of: self))
        let content = "<?xml version=\"1.0\"?>\n<root>\n  <item name=\"test\">value</item>\n</root>"
        let html = PreviewViewController.buildHTML(content: content, language: "xml", bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-xml-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationHelper { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        let jsExp = expectation(description: "JS check")
        var hasHighlighting = false
        webView.evaluateJavaScript(
            "document.querySelector('.hljs-tag') !== null || document.querySelector('.hljs-attr') !== null"
        ) { result, _ in
            hasHighlighting = result as? Bool ?? false
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertTrue(hasHighlighting, "XML content should get syntax highlighting from highlight.js")
    }

    func testXmlLineNumbersPresent() throws {
        let bundle = Bundle(for: type(of: self))
        let content = "<root>\n  <child/>\n</root>"
        let html = PreviewViewController.buildHTML(content: content, language: "xml", bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-xml-lines-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationHelper { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        let jsExp = expectation(description: "JS check")
        var lineCount = 0
        webView.evaluateJavaScript("document.querySelectorAll('.line-number').length") { result, _ in
            lineCount = result as? Int ?? 0
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertEqual(lineCount, 3, "XML with 3 lines should have 3 line numbers")
    }

    // MARK: - WKWebView Rendering

    func testHighlightJSProducesOutput() throws {
        let bundle = Bundle(for: type(of: self))
        let content = "name: CI\non:\n  push:\n    branches: [main]"
        let html = PreviewViewController.buildHTML(content: content, language: "yaml", bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-structured-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationHelper { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        let jsExp = expectation(description: "JS check")
        var hasHighlighting = false
        webView.evaluateJavaScript(
            "document.querySelector('.hljs-attr') !== null || document.querySelector('.hljs-string') !== null"
        ) { result, _ in
            hasHighlighting = result as? Bool ?? false
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertTrue(hasHighlighting, "highlight.js should produce syntax-highlighted elements")
    }

    func testLineNumbersArePresent() throws {
        let bundle = Bundle(for: type(of: self))
        let content = "line1\nline2\nline3"
        let html = PreviewViewController.buildHTML(content: content, language: "yaml", bundle: bundle)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-structured-lines-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationHelper { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        let jsExp = expectation(description: "JS check")
        var lineCount = 0
        webView.evaluateJavaScript("document.querySelectorAll('.line-number').length") { result, _ in
            lineCount = result as? Int ?? 0
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertEqual(lineCount, 3, "Should have 3 line numbers")
    }
}

private class NavigationHelper: NSObject, WKNavigationDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onFinish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onFinish() }
}
