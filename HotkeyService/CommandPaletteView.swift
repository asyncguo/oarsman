import AppKit
import CoreData
import SwiftUI

struct CommandPaletteView: View {
    let controller: CommandPaletteController

    @FetchRequest(fetchRequest: Todo.defaultFetchRequest(), animation: .easeInOut)
    private var todos: FetchedResults<Todo>

    @State private var query: String = ""
    @State private var highlightedTodoID: NSManagedObjectID?
    @State private var isVisible = false

    private var filteredTodos: [Todo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(todos)
        }

        return todos.filter { todo in
            todo.title.localizedCaseInsensitiveContains(trimmed)
                || (todo.content?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || todo.orderedTags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
        }
    }

    private var filteredIdentifiers: [NSManagedObjectID] {
        filteredTodos.map(\.objectID)
    }

    var body: some View {
        ZStack {
            PaletteBackground()

            VStack(spacing: 20) {
                searchBar
                resultsSection
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
            withAnimation(.easeOut(duration: 0.18)) {
                isVisible = true
            }
            refreshHighlight(preserveCurrent: false)
        }
        .onDisappear {
            isVisible = false
        }
        .onExitCommand {
            controller.dismiss()
        }
        .onChange(of: query) { _ in
            refreshHighlight(preserveCurrent: false)
        }
        .onChange(of: filteredIdentifiers) { _ in
            refreshHighlight(preserveCurrent: true)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            CommandPaletteSearchField(
                text: $query,
                onMove: handleMove,
                onConfirm: activateSelection,
                onCancel: controller.dismiss
            )
            .frame(maxWidth: .infinity)

            if !query.isEmpty {
                Button {
                    query.removeAll(keepingCapacity: true)
                    refreshHighlight(preserveCurrent: false)
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

    private var resultsSection: some View {
        ScrollViewReader { proxy in
            Group {
                if todos.isEmpty {
                    EmptyPaletteState(
                        icon: "rectangle.and.text.magnifyingglass",
                        title: "No todos yet",
                        subtitle: "Create todos in the main window to make them searchable."
                    )
                } else if filteredTodos.isEmpty {
                    EmptyPaletteState(
                        icon: "nosign",
                        title: "No matches",
                        subtitle: "Try searching for a different keyword or status."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(filteredTodos) { todo in
                                CommandPaletteResultRow(
                                    todo: todo,
                                    isHighlighted: highlightedTodoID == todo.objectID
                                )
                                .id(todo.objectID)
                                .onHover { hovering in
                                    if hovering {
                                        highlightedTodoID = todo.objectID
                                    }
                                }
                                .onTapGesture {
                                    highlightedTodoID = todo.objectID
                                    activateSelection()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .onChange(of: highlightedTodoID) { id in
                guard let id, filteredIdentifiers.contains(id) else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var divider: some View {
        Color.white.opacity(0.1)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            let message = highlightedTodoID == nil
                ? "Use the arrow keys to highlight a todo"
                : "Press \u{21B5} to open details"

            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))

            Spacer()

            HStack(spacing: 14) {
                hint(keys: ["↑", "↓"], description: "Navigate")
                hint(keys: ["↩︎"], description: "Open")
                hint(keys: ["esc".uppercased()], description: "Close")
            }
        }
    }

    private func handleMove(_ direction: CommandPaletteSearchField.MoveDirection) {
        let ids = filteredIdentifiers
        guard !ids.isEmpty else { return }

        if let current = highlightedTodoID, let index = ids.firstIndex(of: current) {
            switch direction {
            case .down:
                let next = min(index + 1, ids.count - 1)
                highlightedTodoID = ids[next]
            case .up:
                let next = max(index - 1, 0)
                highlightedTodoID = ids[next]
            }
        } else {
            highlightedTodoID = direction == .up ? ids.last : ids.first
        }
    }

    private func activateSelection() {
        let ids = filteredIdentifiers
        guard !ids.isEmpty else { return }

        let selectedID = highlightedTodoID ?? ids.first!
        NotificationCenter.default.post(name: .todoSelectionRequested, object: selectedID)
        controller.dismiss()
    }

    private func refreshHighlight(preserveCurrent: Bool) {
        let ids = filteredIdentifiers
        guard !ids.isEmpty else {
            highlightedTodoID = nil
            return
        }

        if preserveCurrent, let current = highlightedTodoID, ids.contains(current) {
            return
        }

        highlightedTodoID = ids.first
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

private struct CommandPaletteResultRow: View {
    @ObservedObject var todo: Todo
    var isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(todo.isCompleted ? Color.accentColor : Color.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                if let content = todo.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(todo.status.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )

                    Text(todo.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHighlighted ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

private struct EmptyPaletteState: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.4))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
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
}

private struct CommandPaletteSearchField: NSViewRepresentable {
    @Binding var text: String
    var onMove: (MoveDirection) -> Void
    var onConfirm: () -> Void
    var onCancel: () -> Void

    enum MoveDirection {
        case up
        case down
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.placeholderAttributedString = NSAttributedString(
            string: "Search todos…",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.55),
                .font: NSFont.systemFont(ofSize: 16, weight: .medium)
            ]
        )

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context _: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: CommandPaletteSearchField

        init(parent: CommandPaletteSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)):
                parent.onMove(.down)
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onMove(.up)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onConfirm()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            default:
                return false
            }
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
