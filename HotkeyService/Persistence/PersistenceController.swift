import CoreData
import Foundation

final class PersistenceController {
    static let modelName = "HotkeyService"

    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        do {
            try controller.seedSampleTodos(in: context)
        } catch {
            assertionFailure("Failed to seed preview todos: \(error)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)

        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
    }

    // MARK: CRUD

    @discardableResult
    func createTodo(
        title: String,
        content: String? = nil,
        status: TodoStatus = .pending,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        save: Bool = true,
        in context: NSManagedObjectContext? = nil
    ) throws -> Todo {
        let workingContext = context ?? viewContext
        return try performSync(on: workingContext) {
            let todo = Todo(context: workingContext)
            let timestamp = createdAt

            todo.id = UUID()
            todo.title = title
            todo.content = content
            todo.status = status
            todo.tags = tags
            todo.createdAt = timestamp
            todo.updatedAt = updatedAt ?? timestamp

            if save, workingContext.hasChanges {
                try workingContext.save()
            }

            return todo
        }
    }

    func fetchTodos(
        status: TodoStatus? = nil,
        limit: Int? = nil,
        context: NSManagedObjectContext? = nil
    ) throws -> [Todo] {
        let workingContext = context ?? viewContext
        let request: NSFetchRequest<Todo>

        if let status {
            request = Todo.fetchRequest(status: status)
        } else {
            request = Todo.defaultFetchRequest(limit: limit)
        }

        if let limit, status != nil {
            request.fetchLimit = limit
        }

        return try performSync(on: workingContext) {
            try workingContext.fetch(request)
        }
    }

    func update(_ todo: Todo, in context: NSManagedObjectContext? = nil, updates: (Todo) -> Void) throws {
        let workingContext = context ?? todo.managedObjectContext ?? viewContext
        try performSync(on: workingContext) {
            updates(todo)
            todo.updatedAt = Date()

            if workingContext.hasChanges {
                try workingContext.save()
            }
        }
    }

    func delete(_ todo: Todo, in context: NSManagedObjectContext? = nil) throws {
        let workingContext = context ?? todo.managedObjectContext ?? viewContext
        try performSync(on: workingContext) {
            workingContext.delete(todo)
            if workingContext.hasChanges {
                try workingContext.save()
            }
        }
    }

    func save(context: NSManagedObjectContext? = nil) throws {
        let workingContext = context ?? viewContext
        try performSync(on: workingContext) {
            if workingContext.hasChanges {
                try workingContext.save()
            }
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.name = "backgroundContext"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    private func seedSampleTodos(in context: NSManagedObjectContext) throws {
        try createTodo(
            title: "Draft architecture notes",
            content: "Outline the service boundaries for automation modules.",
            status: .inProgress,
            tags: ["planning", "architecture"],
            createdAt: Date().addingTimeInterval(-8 * 60 * 60),
            in: context,
            save: false
        )

        try createTodo(
            title: "Collect shortcut feedback",
            content: "Ask the design team for their top five global hotkey requests.",
            status: .pending,
            tags: ["research"],
            createdAt: Date().addingTimeInterval(-4 * 60 * 60),
            in: context,
            save: false
        )

        try createTodo(
            title: "Polish release notes",
            content: "Draft a concise summary for the 0.2.0 milestone.",
            status: .completed,
            tags: ["writing"],
            createdAt: Date().addingTimeInterval(-2 * 60 * 60),
            in: context,
            save: false
        )

        try save(context: context)
    }

    private func performSync<T>(on context: NSManagedObjectContext, _ work: () throws -> T) throws -> T {
        var capturedResult: Result<T, Error>?

        context.performAndWait {
            do {
                capturedResult = .success(try work())
            } catch {
                capturedResult = .failure(error)
            }
        }

        guard let result = capturedResult else {
            fatalError("performAndWait did not capture a result on context: \(context)")
        }

        return try result.get()
    }
}
