import XCTest

class MarkdownProcessorTests: XCTestCase {

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
        XCTAssertTrue(result.contains("```drawio\n"), "Should contain drawio fenced block")
        XCTAssertTrue(result.contains(drawioContent), "Should contain the XML content")
        XCTAssertTrue(result.contains("End."), "Other content should be preserved")
    }

    func testProcessReturnsUnchangedMarkdownWithoutDrawio() {
        let markdown = "# Hello\n\nSome text with ![photo](cat.png) and **bold**."
        let baseURL = URL(fileURLWithPath: "/tmp")
        let result = MarkdownProcessor.process(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Markdown without .drawio refs should be unchanged")
    }

    func testProcessResolvesDrawioReferences() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xml = "<mxfile><diagram>test</diagram></mxfile>"
        try xml.write(to: tempDir.appendingPathComponent("arch.drawio"), atomically: true, encoding: .utf8)

        let markdown = "# Architecture\n\n![Diagram](arch.drawio)\n\nDone."
        let result = MarkdownProcessor.process(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("```drawio\n"), "process() should resolve drawio refs as fenced blocks")
        XCTAssertTrue(result.contains("# Architecture"), "Other content should be preserved")
        XCTAssertFalse(result.contains("![Diagram]"), "Drawio ref should be replaced")
    }

    func testResolveDrawioReferencesIgnoresNonDrawioImages() {
        let markdown = "![photo](cat.png)"
        let baseURL = URL(fileURLWithPath: "/tmp")
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: baseURL)

        XCTAssertEqual(result, markdown, "Non-drawio images should be unchanged")
    }

    // MARK: - readFile Encoding

    func testReadFileWithUTF8() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let content = "# Héllo Wörld"
        let file = tempDir.appendingPathComponent("test.md")
        try content.write(to: file, atomically: true, encoding: .utf8)

        let result = try MarkdownProcessor.readFile(at: file)
        XCTAssertEqual(result, content, "UTF-8 content should be read correctly")
    }

    func testReadFileWithLatin1Fallback() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let content = "café résumé naïve"
        let file = tempDir.appendingPathComponent("test.md")
        try content.write(to: file, atomically: true, encoding: .isoLatin1)

        let result = try MarkdownProcessor.readFile(at: file)
        XCTAssertEqual(result, content, "Latin1 content should be read via fallback")
    }

    func testReadFileThrowsForMissingFile() {
        let file = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).md")
        XCTAssertThrowsError(try MarkdownProcessor.readFile(at: file),
                             "Should throw for missing file")
    }

    // MARK: - Malformed Draw.io XML

    func testResolveDrawioReferencesMalformedXMLPassesThrough() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write malformed XML (unclosed tags, invalid structure)
        let malformedXML = "<mxfile><diagram><unclosed"
        try malformedXML.write(
            to: tempDir.appendingPathComponent("broken.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![Broken](broken.drawio)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        // Malformed XML should still be embedded — the viewer handles parse errors
        XCTAssertTrue(result.contains("```drawio\n"), "Malformed XML should still produce a fenced block")
        XCTAssertTrue(result.contains(malformedXML), "Malformed XML content should be embedded as-is")
        XCTAssertFalse(result.contains("![Broken]"), "Image ref should be replaced even for malformed XML")
    }

    func testResolveDrawioReferencesEmptyFilePassesThrough() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write an empty file
        try "".write(
            to: tempDir.appendingPathComponent("empty.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![Empty](empty.drawio)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("```drawio\n"), "Empty file should still produce a fenced block")
        XCTAssertFalse(result.contains("![Empty]"), "Image ref should be replaced")
    }

    // MARK: - Page Fragment

    func testResolveDrawioReferencesWithPageNameFragment() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xml = "<mxfile><diagram name=\"Overview\">a</diagram><diagram name=\"Details\">b</diagram></mxfile>"
        try xml.write(to: tempDir.appendingPathComponent("arch.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![](arch.drawio#Details)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("```drawio page=Details\n"), "Fragment should produce page= in fence info")
        XCTAssertTrue(result.contains(xml), "XML content should be embedded")
    }

    func testResolveDrawioReferencesWithPageIndexFragment() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xml = "<mxfile><diagram name=\"A\">a</diagram><diagram name=\"B\">b</diagram></mxfile>"
        try xml.write(to: tempDir.appendingPathComponent("d.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![](d.drawio#1)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("```drawio page=1\n"), "Numeric fragment should produce page= in fence info")
    }

    func testResolveDrawioReferencesWithoutFragment() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let xml = "<mxfile><diagram>a</diagram></mxfile>"
        try xml.write(to: tempDir.appendingPathComponent("d.drawio"), atomically: true, encoding: .utf8)

        let markdown = "![](d.drawio)"
        let result = MarkdownProcessor.resolveDrawioReferences(markdown, baseURL: tempDir)

        XCTAssertTrue(result.contains("```drawio\n"), "No fragment should produce plain drawio fence")
        XCTAssertFalse(result.contains("page="), "No page param without fragment")
    }

    // MARK: - Multiple Drawio Refs

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
        let fenceCount = result.components(separatedBy: "```drawio\n").count - 1
        XCTAssertEqual(fenceCount, 2, "Should have two drawio fenced blocks")
    }
}
