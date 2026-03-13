import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("QuickMark")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("This app provides a QuickLook preview extension for Markdown files. It's already active — just select a .md file in Finder and press Space.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding(40)
        .frame(width: 480, height: 300)
    }
}
