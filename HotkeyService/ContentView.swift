import CoreData
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: TodoListViewModel

    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        _viewModel = StateObject(wrappedValue: TodoListViewModel(context: context))
    }

    var body: some View {
        TodoListView(viewModel: viewModel)
            .environment(\.managedObjectContext, viewModel.context)
            .environment(\.undoManager, viewModel.context.undoManager)
    }
}

struct TodoListView: View {
    @ObservedObject var viewModel: TodoListViewModel

    @Environment(\.undoManager) private var undoManager

    @FetchRequest(fetchRequest: Todo.defaultFetchRequest(), animation: .snappy)
    private var todos: FetchedResults<Todo>

    @FocusState private var focusedTodoID: NSManagedObjectID?
    @State private var isEditingText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            QuickCaptureView(viewModel: viewModel, undoManager: undoManager, isEditing: $isEditingText)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if todos.isEmpty {
                            EmptyStateView()
                                .padding(.vertical, 36)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(todos) { todo in
                                TodoRowView(
                                    todo: todo,
                                    viewModel: viewModel,
                                    focusedTodoID: $focusedTodoID,
                                    isEditingText: $isEditingText
                                )
                                .id(todo.objectID)
                                .focused($focusedTodoID, equals: todo.objectID)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: viewModel.selectedTodoID) { id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 480)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.ensureSelection(in: Array(todos))
            if focusedTodoID == nil {
                focusedTodoID = viewModel.selectedTodoID ?? todos.first?.objectID
            }
        }
        .onChange(of: todoIdentifiers) { _ in
            viewModel.ensureSelection(in: Array(todos))
        }
        .onChange(of: focusedTodoID) { id in
            if viewModel.selectedTodoID != id {
                viewModel.select(todoID: id)
            }
        }
        .onChange(of: viewModel.selectedTodoID) { id in
            if focusedTodoID != id {
                focusedTodoID = id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoSelectionRequested)) { notification in
            guard let id = notification.object as? NSManagedObjectID else { return }
            viewModel.select(todoID: id)
            focusedTodoID = id
        }
        .onMoveCommand(perform: moveFocus)
        .overlay(alignment: .topLeading) {
            keyboardShortcuts
                .frame(width: 0, height: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Todo Backlog")
                .font(.largeTitle.weight(.semibold))

            Text("Track follow-up items for the command palette and automation services.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var todoIdentifiers: [NSManagedObjectID] {
        todos.map(\.objectID)
    }

    private var keyboardShortcuts: some View {
        Group {
            Button(action: toggleSelected) {
                EmptyView()
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.plain)
            .disabled(viewModel.selectedTodoID == nil || isEditingText)

            Button(action: toggleSelected) {
                EmptyView()
            }
            .keyboardShortcut("x", modifiers: [])
            .buttonStyle(.plain)
            .disabled(viewModel.selectedTodoID == nil || isEditingText)

            Button(action: deleteSelected) {
                EmptyView()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .buttonStyle(.plain)
            .disabled(viewModel.selectedTodoID == nil || isEditingText)
        }
    }

    private func toggleSelected() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.toggleSelectedTodoCompletion(undoManager: undoManager)
        }
    }

    private func deleteSelected() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.deleteSelectedTodo(undoManager: undoManager)
        }
    }

    private func moveFocus(_ direction: MoveCommandDirection) {
        guard !todos.isEmpty else { return }
        guard !isEditingText else { return }
        let orderedTodos = Array(todos)

        let currentID: NSManagedObjectID?
        if let focusedTodoID {
            currentID = focusedTodoID
        } else if let selected = viewModel.selectedTodoID {
            currentID = selected
        } else {
            currentID = nil
        }

        let currentIndex = currentID.flatMap { id in
            orderedTodos.firstIndex(where: { $0.objectID == id })
        }

        func focusTodo(at index: Int) {
            guard orderedTodos.indices.contains(index) else { return }
            let todo = orderedTodos[index]
            if focusedTodoID != todo.objectID {
                focusedTodoID = todo.objectID
            } else {
                viewModel.select(todoID: todo.objectID)
            }
        }

        switch direction {
        case .down:
            let nextIndex = (currentIndex ?? -1) + 1
            guard nextIndex < orderedTodos.count else { return }
            focusTodo(at: nextIndex)
        case .up:
            let nextIndex = (currentIndex ?? orderedTodos.count) - 1
            guard nextIndex >= 0 else { return }
            focusTodo(at: nextIndex)
        default:
            break
        }
    }
}

private struct QuickCaptureView: View {
    @ObservedObject var viewModel: TodoListViewModel
    let undoManager: UndoManager?
    @Binding var isEditing: Bool

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick capture")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("New todo title", text: $viewModel.quickCaptureTitle)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .onSubmit(submit)

            TextEditor(text: $viewModel.quickCaptureContent)
                .font(.body)
                .frame(minHeight: 68, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .focused($focusedField, equals: .notes)
                .overlay(alignment: .topLeading) {
                    if viewModel.quickCaptureContent.isEmpty && focusedField != .notes {
                        Text("Notes (optional)")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .onChange(of: focusedField) { field in
            isEditing = field != nil
        }
        .onAppear {
            if viewModel.quickCaptureTitle.isEmpty {
                focusedField = .title
            }
        }
        .onDisappear {
            isEditing = false
        }
    }

    private func submit() {
        let title = viewModel.quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.createTodo(undoManager: undoManager)
        }

        DispatchQueue.main.async {
            focusedField = .title
        }
    }
}

private struct TodoRowView: View {
    @ObservedObject var todo: Todo
    @ObservedObject var viewModel: TodoListViewModel
    @Binding var focusedTodoID: NSManagedObjectID?
    @Binding var isEditingText: Bool
    @Environment(\.undoManager) private var undoManager

    @State private var titleDraft: String
    @State private var notesDraft: String
    @FocusState private var focusedField: Field?
    @State private var isHovering = false

    private enum Field {
        case title
        case notes
    }

    init(
        todo: Todo,
        viewModel: TodoListViewModel,
        focusedTodoID: Binding<NSManagedObjectID?>,
        isEditingText: Binding<Bool>
    ) {
        self.todo = todo
        self.viewModel = viewModel
        _focusedTodoID = focusedTodoID
        _isEditingText = isEditingText
        _titleDraft = State(initialValue: todo.title)
        _notesDraft = State(initialValue: todo.content ?? "")
    }

    var body: some View {
        let isSelected = viewModel.selectedTodoID == todo.objectID

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                completionButton

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Title", text: $titleDraft)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)
                        .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .focused($focusedField, equals: .title)
                        .onSubmit(commitTitle)

                    if isSelected {
                        TextEditor(text: $notesDraft)
                            .font(.body)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .notes)
                            .overlay(alignment: .topLeading) {
                                if notesDraft.isEmpty && focusedField != .notes {
                                    Text("Notes")
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                }
                            }
                    } else if let content = todo.content, !content.isEmpty {
                        Text(content)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }

                    metadata
                }

                Spacer(minLength: 0)

                Button(role: .destructive, action: deleteTodo) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isSelected ? 1 : 0.35)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor(isSelected: isSelected))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor(isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            focusRow()
        }
        .focusable(true)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: focusedTodoID) { id in
            if id != todo.objectID {
                if isSelected {
                    isEditingText = false
                }
                focusedField = nil
                commitDrafts()
            }
        }
        .onChange(of: focusedField) { field in
            if isSelected {
                isEditingText = field != nil
            }
            if field != .title {
                commitTitle()
            }
            if field != .notes {
                commitNotes()
            }
        }
        .onChange(of: todo.title) { newValue in
            if newValue != titleDraft {
                titleDraft = newValue
            }
        }
        .onChange(of: todo.content ?? "") { newValue in
            if newValue != notesDraft {
                notesDraft = newValue
            }
        }
        .onChange(of: isSelected) { selected in
            if !selected {
                isEditingText = false
            }
        }
    }

    private var completionButton: some View {
        Button(action: toggleCompletion) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(todo.isCompleted ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(todo.isCompleted ? "Mark as pending" : "Mark as complete")
    }

    private var metadata: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("Created \(todo.createdAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
            }

            if todo.updatedAt.timeIntervalSince(todo.createdAt) > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Updated \(todo.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func backgroundColor(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if todo.isCompleted {
            return Color.accentColor.opacity(0.06)
        } else {
            return Color.primary.opacity(0.02)
        }
    }

    private func borderColor(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.6)
        } else if todo.isCompleted {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.primary.opacity(0.05)
        }
    }

    private func focusRow() {
        isEditingText = false
        if focusedTodoID != todo.objectID {
            focusedTodoID = todo.objectID
        } else {
            viewModel.select(todoID: todo.objectID)
        }
    }

    private func toggleCompletion() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.toggleCompletion(for: todo, undoManager: undoManager)
        }
    }

    private func deleteTodo() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.delete(todo, undoManager: undoManager)
        }
        isEditingText = false
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleDraft = todo.title
            return
        }

        viewModel.updateTitle(for: todo, title: trimmed, undoManager: undoManager)
        titleDraft = trimmed
    }

    private func commitNotes() {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.updateContent(for: todo, content: trimmed, undoManager: undoManager)
        notesDraft = trimmed
    }

    private func commitDrafts() {
        commitTitle()
        commitNotes()
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)

            Text("You're all caught up")
                .font(.headline)

            Text("Use the capture field above to add your next todo.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.viewContext)
}
