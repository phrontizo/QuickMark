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

    // MARK: - resolveImageReferences

    func testResolveImageReferencesInlinesSVG() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svgContent = "<svg><circle r=\"10\"/></svg>"
        let svgFile = tempDir.appendingPathComponent("icon.svg")
        try svgContent.write(to: svgFile, atomically: true, encoding: .utf8)

        let markdown = "![Icon](icon.svg)"
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: tempDir)

        XCTAssertFalse(result.contains("icon.svg)"), "Original path should be replaced")
        XCTAssertTrue(result.contains("data:image/svg+xml;base64,"), "Should contain SVG data URI")
        XCTAssertTrue(result.contains("![Icon](data:"), "Alt text should be preserved")
    }

    func testResolveImageReferencesInlinesPNG() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write a minimal valid PNG (1x1 transparent pixel)
        let pngData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAABJREFAAAAAAMDAwMDAwMDA")!
        let pngFile = tempDir.appendingPathComponent("photo.png")
        try pngData.write(to: pngFile)

        let markdown = "![Photo](photo.png)"
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("data:image/png;base64,"), "Should contain PNG data URI")
    }

    func testResolveImageReferencesSkipsURLs() {
        let markdown = "![logo](https://example.com/logo.svg)"
        let baseURL = URL(fileURLWithPath: "/tmp")
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "HTTP URLs should not be modified")
    }

    func testResolveImageReferencesSkipsDrawioFiles() {
        let markdown = "![diagram](arch.drawio)"
        let baseURL = URL(fileURLWithPath: "/tmp")
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Draw.io files should be left for drawio handler")
    }

    func testResolveImageReferencesSkipsMissingFiles() {
        let markdown = "![missing](nonexistent.svg)"
        let baseURL = URL(fileURLWithPath: "/tmp/empty")
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Missing files should leave reference unchanged")
    }

    func testResolveImageReferencesHandlesSubdirectoryPaths() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let diagrams = tempDir.appendingPathComponent("diagrams")
        try FileManager.default.createDirectory(at: diagrams, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let svgContent = "<svg><rect width=\"10\" height=\"10\"/></svg>"
        try svgContent.write(to: diagrams.appendingPathComponent("arch.svg"), atomically: true, encoding: .utf8)

        let markdown = "![Architecture](./diagrams/arch.svg)"
        let result = MarkdownProcessor.resolveImageReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("data:image/svg+xml;base64,"), "Subdirectory SVGs should be inlined")
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
