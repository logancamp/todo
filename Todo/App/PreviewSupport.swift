import Foundation

#if DEBUG

extension TodoStore {
    static var preview: TodoStore {
        let session = PreviewSession(uid: "preview-user")
        let repo = InMemoryAppRepository()
        let policy = BucketPolicy(clock: BucketClock())
        let store = TodoStore(
            repo: repo,
            session: session,
            bucketizer: Bucketizer(policy: policy),
            mapper: SectionMapper(policy: policy),
            validator: Validator()
        )
        repo.seed(sampleTodos(ownerUid: "preview-user"))
        return store
    }
}

@MainActor
final class PreviewSession: SessionProviding {
    let uid: String?
    init(uid: String?) { self.uid = uid }
}

final class InMemoryAppRepository: AppRepository {
    private var todos: [Todo] = []
    private var continuations: [AsyncStream<[Todo]>.Continuation] = []
    private var activeFilter: TodoFilter = .all
    private var activeUID: String = ""

    func streamTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        activeUID = uid
        activeFilter = filter
        return AsyncStream { cont in
            self.continuations.append(cont)
            cont.yield(self.filtered(uid: uid, filter: filter))
        }
    }

    func create(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> Todo {
        let now = Date()
        let new = Todo(id: UUID().uuidString, title: title, isDone: false, kind: kind,
                       dueAt: dueAt, createdAt: now, updatedAt: now, ownerUid: uid)
        todos.insert(new, at: 0)
        broadcast()
        return new
    }

    func update(uid: String, todo: Todo) async throws {
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) { todos[idx] = todo }
        else { todos.insert(todo, at: 0) }
        broadcast()
    }

    func delete(uid: String, id: String) async throws {
        todos.removeAll { $0.id == id }
        broadcast()
    }

    func seed(_ initial: [Todo]) {
        todos = initial
        broadcast()
    }

    private func broadcast() {
        let result = filtered(uid: activeUID, filter: activeFilter)
        continuations.forEach { $0.yield(result) }
    }

    private func filtered(uid: String, filter: TodoFilter) -> [Todo] {
        let mine = todos.filter { $0.ownerUid == uid }
        switch filter {
        case .all:       return mine
        case .completed: return mine.filter { $0.isDone }
        case .pending:   return mine.filter { !$0.isDone }
        }
    }
}

private func sampleTodos(ownerUid: String) -> [Todo] {
    let now = Date()
    return [
        Todo(id: "t1", title: "Buy groceries", isDone: false, kind: .task, dueAt: nil,
             createdAt: now.addingTimeInterval(-3_600), updatedAt: now.addingTimeInterval(-1_800), ownerUid: ownerUid),
        Todo(id: "t2", title: "Finish writeup", isDone: false, kind: .reminder,
             dueAt: now.addingTimeInterval(3_600 * 6),
             createdAt: now.addingTimeInterval(-7_200), updatedAt: now.addingTimeInterval(-3_600), ownerUid: ownerUid),
        Todo(id: "t3", title: "Stretch (2 min)", isDone: true, kind: .task, dueAt: nil,
             createdAt: now.addingTimeInterval(-86_400), updatedAt: now.addingTimeInterval(-40_000), ownerUid: ownerUid),
        Todo(id: "t4", title: "Review PR", isDone: false, kind: .checklist,
             dueAt: now.addingTimeInterval(-3_600),
             createdAt: now.addingTimeInterval(-10_000), updatedAt: now.addingTimeInterval(-5_000), ownerUid: ownerUid),
    ]
}

#endif // DEBUG
