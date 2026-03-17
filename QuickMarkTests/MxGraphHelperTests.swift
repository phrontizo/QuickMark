import XCTest

class MxGraphHelperTests: XCTestCase {

    func testDrawioDivProducesMxgraphDiv() {
        let xml = "<mxfile><diagram>content</diagram></mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        XCTAssertTrue(result.hasPrefix("<div"), "Should produce a div element")
        XCTAssertTrue(result.contains("class=\"mxgraph\""), "Should have mxgraph class")
        XCTAssertTrue(result.contains("data-mxgraph="), "Should have data-mxgraph attribute")
        XCTAssertTrue(result.hasSuffix("</div>"), "Should close the div")
    }

    func testDrawioDivEscapesBackslashes() {
        let xml = "<mxfile path=\"C:\\Users\\test\">data</mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        // Backslashes should be double-escaped for JSON embedding
        XCTAssertFalse(result.contains("C:\\Users"), "Raw backslashes must be escaped")
    }

    func testDrawioDivEscapesNewlines() {
        let xml = "<mxfile>\n<diagram>\n</diagram>\n</mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        // Newlines should be escaped as \n in the JSON
        XCTAssertFalse(result.contains("\n<diagram>"), "Raw newlines must be escaped in the attribute value")
    }

    func testDrawioDivEscapesAmpersands() {
        let xml = "<mxfile label=\"A&amp;B\">data</mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        // Ampersands in the JSON must be HTML-escaped for the attribute
        XCTAssertTrue(result.contains("&amp;"), "Ampersands should be HTML-escaped")
    }

    func testDrawioDivEscapesAngleBrackets() {
        let xml = "<mxfile><diagram>content</diagram></mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        // Angle brackets in the XML must be HTML-escaped in the attribute value
        XCTAssertTrue(result.contains("&lt;"), "Opening angle brackets should be HTML-escaped")
        XCTAssertTrue(result.contains("&gt;"), "Closing angle brackets should be HTML-escaped")
    }

    func testDrawioDivHandlesEmptyXml() {
        let result = MxGraphHelper.drawioDiv(xml: "")

        XCTAssertTrue(result.contains("class=\"mxgraph\""), "Should still produce a valid div")
        XCTAssertTrue(result.contains("data-mxgraph="), "Should still have the attribute")
    }

    func testDrawioDivEscapesControlCharacters() {
        let xml = "<mxfile>\u{0000}\u{0008}\u{000B}\u{000C}</mxfile>"
        let result = MxGraphHelper.drawioDiv(xml: xml)

        // Control characters should be escaped by JSONSerialization
        XCTAssertFalse(result.contains("\u{0000}"), "NUL bytes must be escaped")
        XCTAssertTrue(result.contains("class=\"mxgraph\""), "Should still produce a valid div")
    }

    // MARK: - buildHTML

    func testBuildHTMLProducesCompleteDocument() {
        let viewerURL = URL(fileURLWithPath: "/path/to/viewer-static.min.js")
        let html = MxGraphHelper.buildHTML(xml: "<mxfile><diagram>test</diagram></mxfile>", viewerURL: viewerURL)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Should start with DOCTYPE")
        XCTAssertTrue(html.contains("</html>"), "Should close HTML tag")
        XCTAssertTrue(html.contains("class=\"mxgraph\""), "Should contain the mxgraph div")
        XCTAssertTrue(html.contains("viewer-static.min.js"), "Should reference the viewer script")
    }

    func testBuildHTMLContainsTabBarDiv() {
        let viewerURL = URL(fileURLWithPath: "/path/to/viewer.js")
        let html = MxGraphHelper.buildHTML(xml: "<mxfile><diagram>a</diagram></mxfile>", viewerURL: viewerURL)

        XCTAssertTrue(html.contains("id=\"drawio-tabs\""), "Should contain tab bar div")
    }

    func testBuildHTMLEscapesViewerURL() {
        let viewerURL = URL(string: "file:///path/with%22quotes&amps")!
        let html = MxGraphHelper.buildHTML(xml: "<mxfile/>", viewerURL: viewerURL)

        XCTAssertTrue(html.contains("&amp;amps"), "Ampersands in viewer URL should be escaped")
    }
}
