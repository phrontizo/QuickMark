import Foundation

enum LinkAction {
    case renderMarkdown(URL)
    case openExternal(URL)
    case block
}

enum LinkPolicy {

    /// Determines the action for a clicked link URL.
    /// - Local .md/.markdown files → render inline
    /// - http/https URLs → open externally
    /// - Everything else (custom schemes, javascript:, etc.) → block
    static func action(for url: URL) -> LinkAction {
        if url.isFileURL, ["md", "markdown"].contains(url.pathExtension.lowercased()) {
            return .renderMarkdown(url)
        }
        if let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return .openExternal(url)
        }
        return .block
    }
}
