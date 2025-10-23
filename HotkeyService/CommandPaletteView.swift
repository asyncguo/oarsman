import AppKit
import CoreData
import SwiftUI

struct CommandPaletteView: View {
    let controller: CommandPaletteController

    @StateObject private var viewModel: CommandPaletteViewModel
    @FocusState private var focusedField: Field?
    @State private var isVisible = false
    @State private var highlightedResultID: NSManagedObjectID?

    private enum Field: Hashable {
        case search
    }

    init(controller: CommandPaletteController, context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.controller = controller
        _viewModel = StateObject(wrappedValue: CommandPaletteViewModel(context: context))
    }

    var body: some View {
        ZStack {
            PaletteBackground()

            VStack(spacing: 16) {
                searchField
                statusFilterControl
                resultsSection
                divider
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 460, height: 400)
        .preferredColorScheme(.dark)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95, anchor: .top)
        .animation(.easeOut(duration: 0.18), value: isVisible)
        .onAppear {
            focusedField = .search
            highlightedResultID = viewModel.results.first?.id
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
        .overlay(alignment: .topLeading) {
            keyboardShortcutBindings
        }
        .onChange(of: viewModel.results) { newResults in
            guard let first = newResults.first else {
                highlightedResultID = nil
                return
            }

            if highlightedResultID == nil || !newResults.contains(where: { $0.id == highlightedResultID }) {
                highlightedResultID = first.id
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            TextField(text: $viewModel.searchText, prompt: Text("Search todos…").foregroundStyle(.white.opacity(0.55))) {}
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($focusedField, equals: .search)
                .onSubmit {
                    controller.dismiss()
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.resetSearch()
                    highlightedResultID = nil
                    focusedField = .search
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.45))
                        .accessibilityLabel("Clear search")
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

    private var statusFilterControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.resetSearch()
                        highlightedResultID = nil
                        focusedField = .search
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.accentColor)
                    .accessibilityLabel("Clear search text")
                }
            }

            Picker("Status filter", selection: $viewModel.statusFilter) {
                ForEach(CommandPaletteViewModel.StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var resultsSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

            if viewModel.results.isEmpty {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    commandListPlaceholder
                } else {
                    SearchEmptyState(query: viewModel.searchText) {
                        viewModel.resetSearch()
                        highlightedResultID = nil
                        focusedField = .search
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.results) { result in
                            CommandPaletteResultRow(
                                result: result,
                                query: viewModel.searchText,
                                isHighlighted: result.id == highlightedResultID
                            )
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 208)
    }

    private var commandListPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))

            Text("Save todos to get started")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text("Add todos from the main window or start typing to filter your backlog.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var divider: some View {
        Color.white.opacity(0.1)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text(resultsSummary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            HStack(spacing: 14) {
                hint(keys: ["⌘", "1"], description: "All")
                hint(keys: ["⌘", "2"], description: "Open")
                hint(keys: ["⌘", "3"], description: "Done")
                hint(keys: ["⌘", "\\"], description: "Clear search")
                hint(keys: ["ESC"], description: "Close")
            }
        }
    }

    private var resultsSummary: String {
        let count = viewModel.results.count
        let noun = count == 1 ? "todo" : "todos"
        let filterTitle = viewModel.statusFilter.title.lowercased()
        let hasQuery = !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let prefix = hasQuery ? "Filtered" : "Showing"
        return "\(prefix) \(count) \(noun) (\(filterTitle))"
    }

    @ViewBuilder
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

    private var keyboardShortcutBindings: some View {
        ZStack {
            ShortcutButton(shortcut: KeyEquivalent("1"), modifiers: [.command]) {
                viewModel.statusFilter = .all
            }

            ShortcutButton(shortcut: KeyEquivalent("2"), modifiers: [.command]) {
                viewModel.statusFilter = .open
            }

            ShortcutButton(shortcut: KeyEquivalent("3"), modifiers: [.command]) {
                viewModel.statusFilter = .done
            }

            ShortcutButton(shortcut: KeyEquivalent("\\"), modifiers: [.command]) {
                viewModel.resetSearch()
                highlightedResultID = nil
                focusedField = .search
            }
        }
    }
}

private struct ShortcutButton: View {
    let shortcut: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .keyboardShortcut(shortcut, modifiers: modifiers)
        .frame(width: 0, height: 0)
        .opacity(0.0001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CommandPaletteResultRow: View {
    let result: CommandPaletteViewModel.TodoSearchResult
    let query: String
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                highlightedText(result.title, query: query)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                StatusBadge(status: result.status)
            }

            if let content = result.content, !content.isEmpty {
                highlightedSecondaryText(content, query: query)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                Label {
                    Text(result.createdAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 11, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.white.opacity(0.45))

                if result.updatedAt.timeIntervalSince(result.createdAt) > 1 {
                    Label {
                        Text(result.updatedAt, style: .relative)
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isHighlighted ? 0.2 : 0.12), lineWidth: 1)
        )
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(text)
                .foregroundStyle(.white)
        }

        let segments = text.highlightSegments(matching: query)
        return segments.reduce(Text("")) { partial, segment in
            let segmentText = Text(segment.text)
                .foregroundStyle(segment.isMatch ? Color.accentColor : Color.white)
            return partial + segmentText
        }
    }

    private func highlightedSecondaryText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(text)
                .foregroundStyle(.white.opacity(0.65))
        }

        let segments = text.highlightSegments(matching: query)
        return segments.reduce(Text("")) { partial, segment in
            let segmentText = Text(segment.text)
                .foregroundStyle(segment.isMatch ? Color.accentColor : Color.white.opacity(0.65))
            return partial + segmentText
        }
    }
}

private struct SearchEmptyState: View {
    let query: String
    let clearAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))

            VStack(spacing: 4) {
                Text("No todos matched \"\(query.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Text("Try a different keyword or clear your search.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Button(action: clearAction) {
                Label("Clear search", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
    }
}

private struct StatusBadge: View {
    let status: TodoStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status), in: Capsule())
            .foregroundStyle(.white)
    }

    private func statusColor(_ status: TodoStatus) -> Color {
        switch status {
        case .pending:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .archived:
            return .orange
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

private struct HighlightSegment {
    let text: String
    let isMatch: Bool
}

private extension String {
    func highlightSegments(matching query: String) -> [HighlightSegment] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return [HighlightSegment(text: self, isMatch: false)]
        }

        var segments: [HighlightSegment] = []
        var currentIndex = startIndex
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        while currentIndex < endIndex,
              let range = range(of: trimmedQuery, options: options, range: currentIndex ..< endIndex) {
            if range.lowerBound > currentIndex {
                segments.append(HighlightSegment(text: String(self[currentIndex ..< range.lowerBound]), isMatch: false))
            }

            segments.append(HighlightSegment(text: String(self[range]), isMatch: true))
            currentIndex = range.upperBound
        }

        if currentIndex < endIndex {
            segments.append(HighlightSegment(text: String(self[currentIndex ..< endIndex]), isMatch: false))
        }

        if segments.isEmpty {
            segments.append(HighlightSegment(text: self, isMatch: false))
        }

        return segments
    }
}
