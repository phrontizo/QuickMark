import XCTest

class MarkdownProcessorTests: XCTestCase {

    func testDrawioDivWrapsXmlInMxgraphDiv() {
        let xml = "<mxfile><diagram>test</diagram></mxfile>"
        let result = MarkdownProcessor.drawioDiv(xml: xml)

        XCTAssertTrue(result.contains("class=\"mxgraph\""), "Should have mxgraph class")
        XCTAssertTrue(result.contains("data-mxgraph="), "Should have data attribute")
        XCTAssertTrue(result.contains("mxfile"), "Should reference the XML content")
    }

    func testDrawioDivEscapesQuotesInXml() {
        let xml = "<mxfile attr=\"value\">content</mxfile>"
        let result = MarkdownProcessor.drawioDiv(xml: xml)

        XCTAssertTrue(result.contains("mxgraph"), "Should produce mxgraph div")
        XCTAssertFalse(result.contains("attr=\"value\">"), "Raw quotes must be escaped")
    }

    func testDrawioDivMissingFileReturnsUnchanged() {
        let markdown = "![diagram](nonexistent.drawio)"
        let baseURL = URL(fileURLWithPath: "/tmp/empty")
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Missing file should leave reference unchanged")
    }

    func testResolveDrawioReferencesReplacesImageRef() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let drawioContent = "<mxfile><diagram>test</diagram></mxfile>"
        let drawioFile = tempDir.appendingPathComponent("diagram.drawio")
        try drawioContent.write(to: drawioFile, atomically: true, encoding: .utf8)

        let markdown = "Check this out:\n\n![My Diagram](diagram.drawio)\n\nEnd."
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertFalse(result.contains("![My Diagram](diagram.drawio)"), "Image ref should be replaced")
        XCTAssertTrue(result.contains("class=\"mxgraph\""), "Should contain draw.io div")
        XCTAssertTrue(result.contains("End."), "Other content should be preserved")
    }

    func testResolveDrawioReferencesIgnoresNonDrawioImages() {
        let markdown = "![photo](cat.png)"
        let baseURL = URL(fileURLWithPath: "/tmp")
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Non-drawio images should be unchanged")
    }

    func testResolveDrawioReferencesHandlesMultipleRefs() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "<mxfile>one</mxfile>".write(
            to: tempDir.appendingPathComponent("a.drawio"), atomically: true, encoding: .utf8)
        try "<mxfile>two</mxfile>".write(
            to: tempDir.appendingPathComponent("b.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![A](a.drawio)\ntext\n![B](b.drawio)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertFalse(result.contains("![A]"), "First ref should be replaced")
        XCTAssertFalse(result.contains("![B]"), "Second ref should be replaced")
        XCTAssertTrue(result.contains("text"), "Surrounding text should be preserved")
        let divCount = result.components(separatedBy: "class=\"mxgraph\"").count - 1
        XCTAssertEqual(divCount, 2, "Should have two mxgraph divs")
    }
}
