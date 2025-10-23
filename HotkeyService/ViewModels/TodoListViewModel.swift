import CoreData
import Foundation

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published var quickCaptureTitle: String = ""
    @Published var quickCaptureContent: String = ""
    @Published private(set) var selectedTodoID: NSManagedObjectID?

    let context: NSManagedObjectContext
    private let persistence: PersistenceController

    init(context: NSManagedObjectContext, persistence: PersistenceController = .shared) {
        self.context = context
        self.persistence = persistence

        if context.undoManager == nil {
            context.undoManager = UndoManager()
        }
    }

    func select(todoID: NSManagedObjectID?) {
        guard let todoID else {
            selectedTodoID = nil
            return
        }

        if todo(for: todoID) != nil {
            selectedTodoID = todoID
        } else {
            selectedTodoID = nil
        }
    }

    func ensureSelection(in todos: [Todo]) {
        guard let selectedTodoID else { return }
        guard todos.contains(where: { $0.objectID == selectedTodoID }) else {
            self.selectedTodoID = todos.first?.objectID
            return
        }
    }

    func todo(for objectID: NSManagedObjectID?) -> Todo? {
        guard let objectID else { return nil }
        return persistence.todo(with: objectID, context: context)
    }

    func createTodo(undoManager: UndoManager?) {
        let title = quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = quickCaptureContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return }

        do {
            let todo = try persistence.createTodo(
                title: title,
                content: content.isEmpty ? nil : content,
                in: context
            )

            undoManager?.setActionName("Add Todo")

            quickCaptureTitle = ""
            quickCaptureContent = ""
            selectedTodoID = todo.objectID
        } catch {
            assertionFailure("Failed to create todo: \(error)")
        }
    }

    func updateTitle(for todo: Todo, title: String, undoManager: UndoManager?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != todo.title else { return }

        do {
            try persistence.update(todo, in: context) { $0.title = trimmed }
            undoManager?.setActionName("Rename Todo")
        } catch {
            assertionFailure("Failed to update todo title: \(error)")
        }
    }

    func updateContent(for todo: Todo, content: String?, undoManager: UndoManager?) {
        let trimmed = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = trimmed.isEmpty ? nil : trimmed

        guard normalized != todo.content else { return }

        do {
            try persistence.update(todo, in: context) { $0.content = normalized }
            undoManager?.setActionName("Edit Notes")
        } catch {
            assertionFailure("Failed to update todo content: \(error)")
        }
    }

    func toggleCompletion(for todo: Todo, undoManager: UndoManager?) {
        let nextStatus: TodoStatus = todo.isCompleted ? .pending : .completed

        do {
            try persistence.update(todo, in: context) { $0.status = nextStatus }
            undoManager?.setActionName(nextStatus == .completed ? "Complete Todo" : "Reopen Todo")
        } catch {
            assertionFailure("Failed to toggle todo completion: \(error)")
        }
    }

    func toggleSelectedTodoCompletion(undoManager: UndoManager?) {
        guard let todo = todo(for: selectedTodoID) else { return }
        toggleCompletion(for: todo, undoManager: undoManager)
    }

    func delete(_ todo: Todo, undoManager: UndoManager?) {
        do {
            try persistence.delete(todo, in: context)
            undoManager?.setActionName("Delete Todo")

            if selectedTodoID == todo.objectID {
                selectedTodoID = nil
            }
        } catch {
            assertionFailure("Failed to delete todo: \(error)")
        }
    }

    func deleteSelectedTodo(undoManager: UndoManager?) {
        guard let todo = todo(for: selectedTodoID) else { return }
        delete(todo, undoManager: undoManager)
    }
}
