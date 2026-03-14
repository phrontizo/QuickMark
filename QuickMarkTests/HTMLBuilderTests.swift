import XCTest

class HTMLBuilderTests: XCTestCase {

    func testAssembleHTMLContainsDoctype() {
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "dGVzdA==",  // "test" in base64
            scriptURLs: [],
            styleURLs: []
        )
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"), "Should start with DOCTYPE")
    }

    func testAssembleHTMLContainsBase64MarkdownInHiddenElement() {
        let b64 = "SGVsbG8gV29ybGQ="  // "Hello World"
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: b64,
            scriptURLs: [],
            styleURLs: []
        )
        XCTAssertTrue(html.contains("id=\"markdown-source\""), "Should have markdown source element")
        XCTAssertTrue(html.contains(b64), "Should contain the base64 content")
    }

    func testAssembleHTMLReferencesScripts() {
        let url = URL(fileURLWithPath: "/path/to/script.js")
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [url],
            styleURLs: []
        )
        XCTAssertTrue(
            html.contains("<script src=\"\(url.absoluteString)\"></script>"),
            "Should reference the script URL"
        )
    }

    func testAssembleHTMLReferencesStyles() {
        let url = URL(fileURLWithPath: "/path/to/style.css")
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [],
            styleURLs: [url]
        )
        XCTAssertTrue(
            html.contains("<link rel=\"stylesheet\" href=\"\(url.absoluteString)\">"),
            "Should reference the style URL"
        )
    }

    func testAssembleHTMLIncludesBaseHref() {
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [],
            styleURLs: [],
            baseHref: "file:///Users/test/Documents/"
        )
        XCTAssertTrue(
            html.contains("<base href=\"file:///Users/test/Documents/\">"),
            "Should include base tag"
        )
    }

    func testAssembleHTMLEscapesBaseHref() {
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [],
            styleURLs: [],
            baseHref: "file:///path/with\"quotes&amps<tag>/"
        )
        XCTAssertTrue(html.contains("&amp;"), "Should escape ampersands in base href")
        XCTAssertTrue(html.contains("&quot;"), "Should escape quotes in base href")
        XCTAssertTrue(html.contains("&lt;"), "Should escape angle brackets in base href")
        XCTAssertFalse(html.contains("with\"quotes"), "Raw quotes must be escaped")
    }

    func testAssembleHTMLOmitsBaseTagWhenNil() {
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [],
            styleURLs: []
        )
        XCTAssertFalse(html.contains("<base"), "Should not include base tag when baseHref is nil")
    }

    func testAssembleHTMLEscapesScriptURLs() {
        let url = URL(string: "file:///path/with%22quotes&amps")!
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [url],
            styleURLs: []
        )
        XCTAssertTrue(html.contains("&amp;"), "Ampersands in script URLs should be escaped")
    }

    func testAssembleHTMLEscapesStyleURLs() {
        let url = URL(string: "file:///path/with%22quotes&amps")!
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [],
            styleURLs: [url]
        )
        XCTAssertTrue(html.contains("&amp;"), "Ampersands in style URLs should be escaped")
    }

    func testAssembleHTMLOrdersStylesBeforeScripts() {
        let styleURL = URL(fileURLWithPath: "/style.css")
        let scriptURL = URL(fileURLWithPath: "/script.js")
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scriptURLs: [scriptURL],
            styleURLs: [styleURL]
        )
        let styleRange = html.range(of: "stylesheet")!
        let scriptRange = html.range(of: "<script src=")!
        XCTAssertTrue(styleRange.lowerBound < scriptRange.lowerBound, "Styles should come before scripts")
    }

    // MARK: - build(markdown:bundle:)

    func testBuildProducesValidHTMLWithTestBundle() {
        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: "# Hello", bundle: bundle)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Should produce valid HTML")
        XCTAssertTrue(html.contains("markdown-source"), "Should contain markdown source element")
        XCTAssertTrue(html.contains("render.js"), "Should reference render.js from bundle")
        XCTAssertTrue(html.contains("style.css"), "Should reference style.css from bundle")
    }

    func testBuildBase64EncodesMarkdown() {
        let bundle = Bundle(for: type(of: self))
        let markdown = "# Test Content"
        let html = HTMLBuilder.build(markdown: markdown, bundle: bundle)

        let expected = Data(markdown.utf8).base64EncodedString()
        XCTAssertTrue(html.contains(expected), "Markdown should be base64-encoded in output")
    }

    func testBuildWithMissingResourcesProducesValidHTML() {
        // Bundle.main in tests is the xctest runner, which lacks QuickMark resources
        let html = HTMLBuilder.build(markdown: "# Hello", bundle: Bundle.main)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Should still produce valid HTML structure")
        XCTAssertTrue(html.contains("markdown-source"), "Should still have markdown source element")
        XCTAssertFalse(html.contains("render.js"), "Should not reference missing resources")
    }

    func testBuildIncludesBaseHref() {
        let bundle = Bundle(for: type(of: self))
        let html = HTMLBuilder.build(markdown: "test", bundle: bundle, baseHref: "file:///tmp/docs/")

        XCTAssertTrue(html.contains("<base href=\"file:///tmp/docs/\">"), "Should include base href")
    }
}
