import XCTest

class FileUtilitiesTests: XCTestCase {

    func testCleanupRemovesStaleFilesWithPrefix() throws {
        let prefix = "test-cleanup-\(UUID().uuidString)-"
        let tempDir = FileManager.default.temporaryDirectory

        // Create a temp file with the correct prefix and .html extension
        let staleFile = tempDir.appendingPathComponent("\(prefix)stale.html")
        try "test".write(to: staleFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: staleFile) }

        // Backdate the file's creation date to 10 minutes ago
        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-600)],
            ofItemAtPath: staleFile.path
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: staleFile.path))

        FileUtilities.cleanupStaleTempFiles(prefix: prefix)

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleFile.path),
                       "Stale file older than 5 minutes should be removed")
    }

    func testCleanupKeepsRecentFiles() throws {
        let prefix = "test-cleanup-\(UUID().uuidString)-"
        let tempDir = FileManager.default.temporaryDirectory

        // Create a recent temp file (creation date = now)
        let recentFile = tempDir.appendingPathComponent("\(prefix)recent.html")
        try "test".write(to: recentFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: recentFile) }

        FileUtilities.cleanupStaleTempFiles(prefix: prefix)

        XCTAssertTrue(FileManager.default.fileExists(atPath: recentFile.path),
                      "Recent file should not be removed")
    }

    func testCleanupIgnoresNonHTMLFiles() throws {
        let prefix = "test-cleanup-\(UUID().uuidString)-"
        let tempDir = FileManager.default.temporaryDirectory

        // Create a stale non-HTML file with the correct prefix
        let txtFile = tempDir.appendingPathComponent("\(prefix)old.txt")
        try "test".write(to: txtFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: txtFile) }

        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-600)],
            ofItemAtPath: txtFile.path
        )

        FileUtilities.cleanupStaleTempFiles(prefix: prefix)

        XCTAssertTrue(FileManager.default.fileExists(atPath: txtFile.path),
                      "Non-HTML files should not be removed even if stale")
    }

    func testCleanupIgnoresFilesWithDifferentPrefix() throws {
        let prefix = "test-cleanup-\(UUID().uuidString)-"
        let tempDir = FileManager.default.temporaryDirectory

        // Create a stale HTML file with a different prefix
        let otherFile = tempDir.appendingPathComponent("other-prefix-stale.html")
        try "test".write(to: otherFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: otherFile) }

        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-600)],
            ofItemAtPath: otherFile.path
        )

        FileUtilities.cleanupStaleTempFiles(prefix: prefix)

        XCTAssertTrue(FileManager.default.fileExists(atPath: otherFile.path),
                      "Files with different prefix should not be removed")
    }
}
