import XCTest
import WebKit

class AppearancePreferenceTests: XCTestCase {

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "markdownAppearance")
        UserDefaults.standard.removeObject(forKey: "drawioAppearance")
        super.tearDown()
    }

    // MARK: - Preference Storage

    func testDefaultIsSystem() {
        XCTAssertEqual(AppearancePreference.markdown, .system)
        XCTAssertEqual(AppearancePreference.drawio, .system)
    }

    func testMarkdownPreferencePersists() {
        AppearancePreference.markdown = .dark
        XCTAssertEqual(AppearancePreference.markdown, .dark)

        AppearancePreference.markdown = .light
        XCTAssertEqual(AppearancePreference.markdown, .light)

        AppearancePreference.markdown = .system
        XCTAssertEqual(AppearancePreference.markdown, .system)
    }

    func testDrawioPreferencePersists() {
        AppearancePreference.drawio = .light
        XCTAssertEqual(AppearancePreference.drawio, .light)

        AppearancePreference.drawio = .dark
        XCTAssertEqual(AppearancePreference.drawio, .dark)
    }

    func testMarkdownAndDrawioAreIndependent() {
        AppearancePreference.markdown = .dark
        AppearancePreference.drawio = .light

        XCTAssertEqual(AppearancePreference.markdown, .dark)
        XCTAssertEqual(AppearancePreference.drawio, .light)
    }

    // MARK: - NSAppearance Mapping

    func testSystemReturnsNil() {
        XCTAssertNil(AppearancePreference.system.nsAppearance)
    }

    func testLightReturnsAqua() {
        let appearance = AppearancePreference.light.nsAppearance
        XCTAssertNotNil(appearance)
        XCTAssertEqual(appearance?.name, .aqua)
    }

    func testDarkReturnsDarkAqua() {
        let appearance = AppearancePreference.dark.nsAppearance
        XCTAssertNotNil(appearance)
        XCTAssertEqual(appearance?.name, .darkAqua)
    }

    // MARK: - WKWebView Appearance

    func testWebViewAppearanceAffectsMediaQuery() throws {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Force light mode
        webView.appearance = AppearancePreference.light.nsAppearance

        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8"></head>
        <body><script>
        document.title = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
        </script></body></html>
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-appearance-\(UUID().uuidString).html")
        try html.write(to: tempFile, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempFile) }

        let navExp = expectation(description: "Page loaded")
        let delegate = NavigationDelegate { navExp.fulfill() }
        webView.navigationDelegate = delegate
        webView.loadFileURL(tempFile, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        wait(for: [navExp], timeout: 10)

        let jsExp = expectation(description: "JS result")
        var result: String?
        webView.evaluateJavaScript("document.title") { value, _ in
            result = value as? String
            jsExp.fulfill()
        }
        wait(for: [jsExp], timeout: 5)

        XCTAssertEqual(result, "light", "Forcing light appearance should make prefers-color-scheme report light")
    }
}

/// Simple navigation delegate for tests.
private class NavigationDelegate: NSObject, WKNavigationDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onFinish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onFinish() }
}
