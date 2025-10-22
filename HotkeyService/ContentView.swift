import SwiftUI

struct ContentView: View {
    @State private var releaseNotes: String = """\n# HotkeyService\nYour next macOS hotkey companion starts here.\n\n- SwiftUI lifecycle\n- macOS 13+ universal target\n- Hardened runtime ready\n\nStay tuned for service integrations and automation.\n"""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("HotkeyService")
                .font(.largeTitle)
                .fontWeight(.semibold)

            ScrollView {
                Text(formattedReleaseNotes)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160)

            Spacer()

            Text("Update the SwiftUI views to prototype hotkey UX.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 480, minHeight: 320)
    }

    private var formattedReleaseNotes: AttributedString {
        (try? AttributedString(markdown: releaseNotes)) ?? AttributedString(releaseNotes)
    }
}

#Preview {
    ContentView()
}
