import SwiftUI

struct ContentView: View {
    @State private var extensionActive = false
    @State private var hasChecked = false

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("QuickMark")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("A QuickLook preview extension for Markdown files.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if hasChecked {
                HStack(spacing: 8) {
                    Image(systemName: extensionActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(extensionActive ? .green : .orange)
                    Text(extensionActive ? "Extension is active" : "Extension is not enabled")
                        .font(.callout)
                }
                .padding(.top, 4)

                if extensionActive {
                    Text("Select a .md file in Finder and press Space to preview.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Open Extension Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                    }
                    .padding(.top, 4)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .padding(40)
        .frame(width: 480, height: 320)
        .onAppear { checkExtension() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkExtension()
        }
    }

    private func checkExtension() {
        DispatchQueue.global(qos: .userInitiated).async {
            let active = isExtensionRegistered()
            DispatchQueue.main.async {
                extensionActive = active
                hasChecked = true
            }
        }
    }

    private func isExtensionRegistered() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", "com.quickmark.QuickMark.QuickMarkPreview"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
