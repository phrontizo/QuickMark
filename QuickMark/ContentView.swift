import SwiftUI

struct ContentView: View {
    @State private var markdownActive = false
    @State private var drawioActive = false
    @State private var structuredActive = false
    @State private var hasChecked = false
    @State private var markdownAppearance = AppearancePreference.markdown
    @State private var drawioAppearance = AppearancePreference.drawio
    @State private var structuredAppearance = AppearancePreference.structured

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("QuickMark")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("QuickLook preview extensions for Markdown, draw.io, and structured data files.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if hasChecked {
                VStack(alignment: .leading, spacing: 6) {
                    extensionRow("Markdown Preview", active: markdownActive)
                    extensionRow("Draw.io Preview", active: drawioActive)
                    extensionRow("Structured Data Preview", active: structuredActive)
                }
                .padding(.top, 4)

                if markdownActive && drawioActive && structuredActive {
                    Text("Select a .md, .drawio, .yml, .json, or .toml file in Finder and press Space to preview.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("You can quit this app \u{2014} the extensions will continue to work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Open Extension Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            }

            Divider()

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Markdown")
                        .font(.callout)
                        .fontWeight(.medium)
                    featureRow("Syntax-highlighted code")
                    featureRow("LaTeX math")
                    featureRow("Mermaid diagrams")
                    featureRow("Task lists & footnotes")
                    featureRow("Embedded draw.io diagrams")
                    featureRow("Local images")
                    featureRow("Linked .md navigation")
                    appearancePicker(selection: $markdownAppearance)
                        .onChange(of: markdownAppearance) { _, newValue in
                            AppearancePreference.markdown = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Draw.io")
                        .font(.callout)
                        .fontWeight(.medium)
                    featureRow("All diagram types")
                    featureRow("Auto-fit to window")
                    featureRow("Pinch-to-zoom")
                    featureRow("Multi-page diagrams")
                    Spacer()
                    appearancePicker(selection: $drawioAppearance)
                        .onChange(of: drawioAppearance) { _, newValue in
                            AppearancePreference.drawio = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Structured Data")
                        .font(.callout)
                        .fontWeight(.medium)
                    featureRow("YAML / JSON / TOML")
                    featureRow("Syntax highlighting")
                    featureRow("Line numbers")
                    Spacer()
                    appearancePicker(selection: $structuredAppearance)
                        .onChange(of: structuredAppearance) { _, newValue in
                            AppearancePreference.structured = newValue
                        }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Text("MIT Licence \u{00B7} \u{00A9} 2026 Phrontizo Limited")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 600)
        .onAppear { checkExtensions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkExtensions()
        }
    }

    private func extensionRow(_ name: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(active ? .green : .orange)
            Text(active ? "\(name) is active" : "\(name) is not enabled")
                .font(.callout)
        }
    }

    private func appearancePicker(selection: Binding<AppearancePreference>) -> some View {
        Picker("Appearance", selection: selection) {
            ForEach(AppearancePreference.allCases, id: \.self) { pref in
                Text(pref.displayName).tag(pref)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.top, 4)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func checkExtensions() {
        Task.detached {
            let md = Self.isExtensionRegistered("com.phrontizo.QuickMark.QuickMarkPreview")
            let dio = Self.isExtensionRegistered("com.phrontizo.QuickMark.QuickMarkDrawio")
            let str = Self.isExtensionRegistered("com.phrontizo.QuickMark.QuickMarkStructured")
            await MainActor.run {
                markdownActive = md
                drawioActive = dio
                structuredActive = str
                hasChecked = true
            }
        }
    }

    private nonisolated static func isExtensionRegistered(_ bundleId: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", bundleId]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            #if DEBUG
            NSLog("QuickMark: pluginkit check failed for %@: %@", bundleId, error.localizedDescription)
            #endif
            return false
        }
    }
}
