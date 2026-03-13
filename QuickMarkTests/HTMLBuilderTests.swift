import XCTest

class HTMLBuilderTests: XCTestCase {

    func testAssembleHTMLContainsDoctype() {
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "dGVzdA==",  // "test" in base64
            scripts: ["console.log('hello');"],
            styles: ["body { color: red; }"]
        )
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"), "Should start with DOCTYPE")
    }

    func testAssembleHTMLContainsBase64MarkdownInHiddenElement() {
        let b64 = "SGVsbG8gV29ybGQ="  // "Hello World"
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: b64,
            scripts: [],
            styles: []
        )
        XCTAssertTrue(html.contains("id=\"markdown-source\""), "Should have markdown source element")
        XCTAssertTrue(html.contains(b64), "Should contain the base64 content")
    }

    func testAssembleHTMLInlinesScripts() {
        let script = "var x = 42;"
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scripts: [script],
            styles: []
        )
        XCTAssertTrue(html.contains("<script>\(script)</script>"), "Should inline the script")
    }

    func testAssembleHTMLInlinesStyles() {
        let css = "body { margin: 0; }"
        let html = HTMLBuilder.assembleHTML(
            markdownBase64: "",
            scripts: [],
            styles: [css]
        )
        XCTAssertTrue(html.contains(css), "Should contain the CSS")
    }
}
