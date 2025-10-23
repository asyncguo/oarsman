import Combine
import CoreData
import Foundation

@MainActor
final class CommandPaletteViewModel: NSObject, ObservableObject {
    enum StatusFilter: CaseIterable, Equatable, Identifiable {
        case all
        case open
        case done

        var id: Self { self }

        var title: String {
            switch self {
            case .all:
                return "All"
            case .open:
                return "Open"
            case .done:
                return "Done"
            }
        }

        fileprivate var statusRawValues: [String]? {
            switch self {
            case .all:
                return nil
            case .open:
                return [TodoStatus.pending.rawValue, TodoStatus.inProgress.rawValue]
            case .done:
                return [TodoStatus.completed.rawValue, TodoStatus.archived.rawValue]
            }
        }
    }

    struct TodoSearchResult: Identifiable {
        let id: NSManagedObjectID
        let title: String
        let content: String?
        let status: TodoStatus
        let createdAt: Date
        let updatedAt: Date
    }

    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .all
    @Published private(set) var results: [TodoSearchResult] = []

    private let context: NSManagedObjectContext
    private let fetchRequest: NSFetchRequest<Todo>
    private var fetchedResultsController: NSFetchedResultsController<Todo>?
    private var cancellables: Set<AnyCancellable> = []

    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
        fetchRequest = Todo.defaultFetchRequest()
        fetchRequest.fetchBatchSize = 40
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = []
        super.init()

        configureFetchedResultsController()
        bindFilters()
        applyFiltersAndFetch()
    }

    func resetSearch() {
        searchText.removeAll(keepingCapacity: true)
    }

    private func configureFetchedResultsController() {
        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller
    }

    private func bindFilters() {
        Publishers.CombineLatest(
            $searchText
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .removeDuplicates(),
            $statusFilter.removeDuplicates()
        )
        .debounce(for: .milliseconds(140), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.applyFiltersAndFetch()
        }
        .store(in: &cancellables)
    }

    private func applyFiltersAndFetch() {
        guard let controller = fetchedResultsController else { return }

        controller.fetchRequest.predicate = predicate(for: searchText, statusFilter: statusFilter)

        do {
            try controller.performFetch()
            updateResults()
        } catch {
            assertionFailure("Failed to fetch todos for command palette: \(error)")
            results = []
        }
    }

    private func updateResults() {
        guard let objects = fetchedResultsController?.fetchedObjects else {
            results = []
            return
        }

        results = objects.map { todo in
            TodoSearchResult(
                id: todo.objectID,
                title: todo.title,
                content: todo.content,
                status: todo.status,
                createdAt: todo.createdAt,
                updatedAt: todo.updatedAt
            )
        }
    }

    private func predicate(for query: String, statusFilter: StatusFilter) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        if let rawValues = statusFilter.statusRawValues {
            predicates.append(NSPredicate(
                format: "%K IN %@",
                #keyPath(Todo.statusRawValue),
                rawValues
            ))
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            predicates.append(NSPredicate(
                format: "(%K CONTAINS[cd] %@) OR (%K CONTAINS[cd] %@)",
                #keyPath(Todo.title),
                trimmedQuery,
                #keyPath(Todo.content),
                trimmedQuery
            ))
        }

        if predicates.isEmpty {
            return nil
        }

        if predicates.count == 1, let predicate = predicates.first {
            return predicate
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

extension CommandPaletteViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard controller === fetchedResultsController else { return }
        updateResults()
    }
}
