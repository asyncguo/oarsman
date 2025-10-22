import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(fetchRequest: Todo.defaultFetchRequest()) private var todos: FetchedResults<Todo>

    @State private var newTitle: String = ""
    @State private var newNotes: String = ""

    private let persistenceController = PersistenceController.shared

    private var isAddDisabled: Bool {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Todo Backlog")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Track follow-up items for the command palette and automation services.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            List {
                if todos.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 32, weight: .light))

                        Text("You're all caught up")
                            .font(.headline)

                        Text("Add a todo below to capture the next hotkey integration task.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 320)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(todos) { todo in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(todo.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                statusBadge(for: todo.status)
                            }

                            if let notes = todo.content, !notes.isEmpty {
                                Text(notes)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                    Text(todo.createdAt, style: .relative)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if todo.updatedAt.timeIntervalSince(todo.createdAt) > 1 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Updated \(todo.updatedAt, style: .relative)")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                if !todo.orderedTags.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag")
                                        Text(todo.orderedTags.joined(separator: ", "))
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.15))
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteTodos)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Add a Todo")
                    .font(.headline)

                TextField("Title", text: $newTitle)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $newNotes)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Button("Add Todo", action: addTodo)
                        .buttonStyle(.borderedProminent)
                        .disabled(isAddDisabled)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 460)
    }

    private func addTodo() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedNotes = newNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try persistenceController.createTodo(
                title: trimmedTitle,
                content: trimmedNotes.isEmpty ? nil : trimmedNotes,
                in: context
            )

            newTitle = ""
            newNotes = ""
        } catch {
            assertionFailure("Failed to create todo: \(error)")
        }
    }

    private func deleteTodos(at offsets: IndexSet) {
        let items = offsets.map { todos[$0] }

        withAnimation {
            for todo in items {
                do {
                    try persistenceController.delete(todo, in: context)
                } catch {
                    assertionFailure("Failed to delete todo: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(for status: TodoStatus) -> some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: status), in: Capsule())
            .foregroundStyle(.white)
    }

    private func statusColor(for status: TodoStatus) -> Color {
        switch status {
        case .pending:
            Color.gray
        case .inProgress:
            Color.blue
        case .completed:
            Color.green
        case .archived:
            Color.orange
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
