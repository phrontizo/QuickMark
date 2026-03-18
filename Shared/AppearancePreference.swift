import AppKit

/// Appearance preference for QuickLook extensions.
///
/// The host app writes via UserDefaults.standard (which persists to
/// ~/Library/Preferences/com.phrontizo.QuickMark.plist). The sandboxed
/// extensions read that plist file directly using their read-only
/// filesystem entitlement — no app group required.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Returns the NSAppearance to apply to a WKWebView, or nil for system default.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    private static let markdownKey = "markdownAppearance"
    private static let drawioKey = "drawioAppearance"
    private static let structuredKey = "structuredAppearance"

    /// Path to the host app's UserDefaults plist.
    /// Uses getpwuid to get the real home directory, since NSHomeDirectory()
    /// returns the sandbox container path in extensions.
    static let prefsPlistPath: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let realHome = String(cString: dir)
            return (realHome as NSString).appendingPathComponent("Library/Preferences/com.phrontizo.QuickMark.plist")
        }
        return (NSHomeDirectory() as NSString).appendingPathComponent("Library/Preferences/com.phrontizo.QuickMark.plist")
    }()

    /// Read a preference value. In the host app this reads UserDefaults.standard;
    /// in extensions it reads the host app's plist file directly.
    private static func read(key: String) -> AppearancePreference {
        // Try UserDefaults first (works in the host app)
        if let raw = UserDefaults.standard.string(forKey: key),
           let pref = AppearancePreference(rawValue: raw) {
            return pref
        }
        // Fall back to reading the plist file (for sandboxed extensions)
        if let dict = NSDictionary(contentsOfFile: prefsPlistPath),
           let raw = dict[key] as? String,
           let pref = AppearancePreference(rawValue: raw) {
            return pref
        }
        return .system
    }

    static var markdown: AppearancePreference {
        get { read(key: markdownKey) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: markdownKey) }
    }

    static var drawio: AppearancePreference {
        get { read(key: drawioKey) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: drawioKey) }
    }

    static var structured: AppearancePreference {
        get { read(key: structuredKey) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: structuredKey) }
    }
}
