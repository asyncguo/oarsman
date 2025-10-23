import CoreData
import Foundation

public enum TodoStatus: String, CaseIterable, Codable {
    case pending
    case inProgress
    case completed
    case archived

    public var displayName: String {
        switch self {
        case .pending:
            "Pending"
        case .inProgress:
            "In Progress"
        case .completed:
            "Completed"
        case .archived:
            "Archived"
        }
    }
}

public extension Todo {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Todo> {
        defaultFetchRequest()
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String?
    @NSManaged public var statusRawValue: String
    @NSManaged public var tags: [String]?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    public var status: TodoStatus {
        get { TodoStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    public var orderedTags: [String] {
        (tags ?? []).sorted()
    }

    public var isCompleted: Bool {
        status == .completed
    }

    public static let defaultSortDescriptors: [NSSortDescriptor] = [
        NSSortDescriptor(keyPath: \Todo.createdAt, ascending: false)
    ]

    public static func defaultFetchRequest(limit: Int? = nil) -> NSFetchRequest<Todo> {
        let request = NSFetchRequest<Todo>(entityName: "Todo")
        request.sortDescriptors = defaultSortDescriptors
        if let limit {
            request.fetchLimit = limit
        }
        return request
    }

    public static func fetchRequest(status: TodoStatus) -> NSFetchRequest<Todo> {
        let request = defaultFetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Todo.statusRawValue), status.rawValue)
        return request
    }
}

extension Todo: Identifiable {}
