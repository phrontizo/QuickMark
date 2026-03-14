import XCTest

class LinkPolicyTests: XCTestCase {

    // MARK: - HTTP/HTTPS → openExternal

    func testHttpURLOpensExternally() {
        let url = URL(string: "http://example.com")!
        guard case .openExternal(let result) = LinkPolicy.action(for: url) else {
            XCTFail("http URL should return .openExternal")
            return
        }
        XCTAssertEqual(result, url)
    }

    func testHttpsURLOpensExternally() {
        let url = URL(string: "https://example.com/page")!
        guard case .openExternal(let result) = LinkPolicy.action(for: url) else {
            XCTFail("https URL should return .openExternal")
            return
        }
        XCTAssertEqual(result, url)
    }

    // MARK: - Local Markdown → renderMarkdown

    func testLocalMdFileRendersInline() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        guard case .renderMarkdown(let result) = LinkPolicy.action(for: url) else {
            XCTFail("Local .md file should return .renderMarkdown")
            return
        }
        XCTAssertEqual(result, url)
    }

    func testLocalMarkdownExtensionRendersInline() {
        let url = URL(fileURLWithPath: "/tmp/notes.markdown")
        guard case .renderMarkdown(let result) = LinkPolicy.action(for: url) else {
            XCTFail("Local .markdown file should return .renderMarkdown")
            return
        }
        XCTAssertEqual(result, url)
    }

    func testLocalMdCaseInsensitive() {
        let url = URL(fileURLWithPath: "/tmp/README.MD")
        guard case .renderMarkdown = LinkPolicy.action(for: url) else {
            XCTFail("Local .MD file (uppercase) should return .renderMarkdown")
            return
        }
    }

    // MARK: - Custom Schemes → block

    func testCustomSchemeIsBlocked() {
        let url = URL(string: "myapp://callback")!
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("Custom scheme should return .block")
            return
        }
    }

    func testJavascriptSchemeIsBlocked() {
        let url = URL(string: "javascript:alert(1)")!
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("javascript: URL should return .block")
            return
        }
    }

    func testDataSchemeIsBlocked() {
        let url = URL(string: "data:text/html,<h1>Hi</h1>")!
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("data: URL should return .block")
            return
        }
    }

    // MARK: - Non-Markdown Local Files → block

    func testLocalNonMdFileIsBlocked() {
        let url = URL(fileURLWithPath: "/tmp/image.png")
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("Local non-md file should return .block")
            return
        }
    }

    func testLocalSwiftFileIsBlocked() {
        let url = URL(fileURLWithPath: "/tmp/main.swift")
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("Local .swift file should return .block")
            return
        }
    }

    // MARK: - FTP → block

    func testFtpSchemeIsBlocked() {
        let url = URL(string: "ftp://files.example.com/doc.md")!
        guard case .block = LinkPolicy.action(for: url) else {
            XCTFail("ftp: URL should return .block (even with .md extension)")
            return
        }
    }
}
