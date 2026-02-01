import Foundation
import SwiftUI

#if DEBUG

extension TodoStore {
    static var preview: TodoStore {
        let repo = InMemoryAppRepository()
        let session = PreviewSession(uid: "preview-user")

        // Use your real concrete bucketing deps (minimal wiring)
        let policy = BucketPolicy(clock: BucketClock())
        let bucketizer = Bucketizer(policy: policy)
        let mapper = SectionMapper(policy: policy)

        let store = TodoStore(
            repo: repo,
            session: session,
            bucketizer: bucketizer,
            mapper: mapper,
            validator: Validator()
        )

        repo.seed(sampleTodos(ownerUid: session.uid ?? "preview-user"))
        return store
    }
}

struct PreviewSession: SessionProviding {
    let uid: String?
}

final class InMemoryAppRepository: AppRepository {
    private var todos: [Todo] = []
    private var continuation: AsyncStream<[Todo]>.Continuation?

    func streamTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        AsyncStream { cont in
            self.continuation = cont
            cont.yield(self.apply(filter: filter, to: self.todos, uid: uid))
        }
    }

    func create(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> Todo {
        let now = Date()
        let new = Todo(
            id: UUID().uuidString,
            title: title,
            isDone: false,
            kind: kind,
            dueAt: dueAt,
            createdAt: now,
            updatedAt: now,
            ownerUid: uid
        )
        todos.insert(new, at: 0)
        publish(for: uid, filter: .all)
        return new
    }

    func update(uid: String, todo: Todo) async throws {
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[idx] = todo
        } else {
            todos.insert(todo, at: 0)
        }
        publish(for: uid, filter: .all)
    }

    func delete(uid: String, id: String) async throws {
        todos.removeAll { $0.id == id }
        publish(for: uid, filter: .all)
    }

    func seed(_ initial: [Todo]) {
        self.todos = initial
        continuation?.yield(initial)
    }

    private func publish(for uid: String, filter: TodoFilter) {
        continuation?.yield(apply(filter: filter, to: todos, uid: uid))
    }

    private func apply(filter: TodoFilter, to todos: [Todo], uid: String) -> [Todo] {
        let mine = todos.filter { $0.ownerUid == uid }
        switch filter {
        case .all: return mine
        case .completed: return mine.filter { $0.isDone }
        case .pending: return mine.filter { !$0.isDone }
        }
    }
}

private func sampleTodos(ownerUid: String) -> [Todo] {
    let now = Date()
    return [
        Todo(id: "t1", title: "Buy groceries", isDone: false, kind: .task, dueAt: nil,
             createdAt: now.addingTimeInterval(-3600), updatedAt: now.addingTimeInterval(-1800), ownerUid: ownerUid),
        Todo(id: "t2", title: "Finish writeup", isDone: false, kind: .reminder, dueAt: now.addingTimeInterval(3600 * 6),
             createdAt: now.addingTimeInterval(-7200), updatedAt: now.addingTimeInterval(-3600), ownerUid: ownerUid),
        Todo(id: "t3", title: "Stretch (2 min)", isDone: true, kind: .task, dueAt: nil,
             createdAt: now.addingTimeInterval(-86400), updatedAt: now.addingTimeInterval(-40000), ownerUid: ownerUid)
    ]
}

#endif
