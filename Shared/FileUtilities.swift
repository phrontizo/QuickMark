import Foundation

enum FileUtilities {

    /// Reads a text file, trying UTF-8 first and falling back to ISO Latin 1.
    static func readFile(at url: URL) throws -> String {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            return utf8
        }
        return try String(contentsOf: url, encoding: .isoLatin1)
    }

    /// Removes temp HTML files with the given prefix that are older than 5 minutes.
    static func cleanupStaleTempFiles(prefix: String) {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-300) // 5 minutes ago
        for file in files where file.lastPathComponent.hasPrefix(prefix) && file.pathExtension == "html" {
            guard let created = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  created < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
