import AppKit
import SwiftUI

struct CommandPaletteView: View {
    let controller: CommandPaletteController

    @State private var query: String = ""
    @FocusState private var focusedField: Field?
    @State private var isVisible = false

    private enum Field: Hashable {
        case search
    }

    var body: some View {
        ZStack {
            PaletteBackground()
            VStack(spacing: 20) {
                searchField
                commandListPlaceholder
                divider
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 460, height: 360)
        .preferredColorScheme(.dark)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95, anchor: .top)
        .animation(.easeOut(duration: 0.18), value: isVisible)
        .onAppear {
            focusedField = .search
            withAnimation(.easeOut(duration: 0.18)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        .onExitCommand {
            controller.dismiss()
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            TextField(text: $query, prompt: Text("Search commands…").foregroundStyle(.white.opacity(0.55))) {}
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($focusedField, equals: .search)
                .onSubmit {
                    controller.dismiss()
                }

            if !query.isEmpty {
                Button {
                    query.removeAll(keepingCapacity: true)
                    focusedField = .search
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var commandListPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))

            Text("No commands yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text("Start typing to discover actions as you add integrations.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var divider: some View {
        Color.white.opacity(0.1)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text("Command palette ready")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            HStack(spacing: 14) {
                hint(keys: ["⌘", "K"], description: "Open palette")
                hint(keys: ["⌘", "↩︎"], description: "Run")
                hint(keys: ["esc".uppercased()], description: "Close")
            }
        }
    }

    private func hint(keys: [String], description: String) -> some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                KeyCap(text: key)
            }

            Text(description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

private struct PaletteBackground: View {
    var body: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
