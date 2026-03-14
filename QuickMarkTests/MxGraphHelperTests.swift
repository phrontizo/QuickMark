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
}
