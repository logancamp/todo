import Foundation

#if DEBUG

extension TodoStore {
    static var preview: TodoStore {
        let session = PreviewSession(uid: "preview-user")
        let repo = InMemoryAppRepository()
        let policy = BucketPolicy(clock: BucketClock())
        let store = TodoStore(
            repo: repo, session: session,
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
        activeUID = uid; activeFilter = filter
        return AsyncStream { cont in
            self.continuations.append(cont)
            cont.yield(self.filtered(uid: uid, filter: filter))
        }
    }

    func create(uid: String, title: String, notes: String, kind: TodoKind, scheduledFor: Date?, dueAt: Date?, order: String) async throws -> Todo {
        let now = Date()
        let new = Todo(id: UUID().uuidString, title: title, notes: notes,
                       isDone: false, kind: kind, scheduledFor: scheduledFor, dueAt: dueAt,
                       createdAt: now, updatedAt: now, ownerUid: uid, order: order)
        todos.insert(new, at: 0); broadcast(); return new
    }

    func update(uid: String, todo: Todo) async throws {
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) { todos[idx] = todo }
        else { todos.insert(todo, at: 0) }
        broadcast()
    }

    func delete(uid: String, id: String) async throws {
        todos.removeAll { $0.id == id }; broadcast()
    }

    func seed(_ initial: [Todo]) { todos = initial; broadcast() }

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
    let cal = Calendar.current
    let now = Date()
    let today     = cal.startOfDay(for: now)
    let tomorrow  = cal.date(byAdding: .day, value: 1, to: today)!
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    let nextWeek  = cal.date(byAdding: .day, value: 7, to: today)!

    // Unique order keys — FractionalIndex.between produces distinct keys per call
    let o1 = FractionalIndex.between(nil, nil)           // "n"
    let o2 = FractionalIndex.between(o1, nil)            // after "n"
    let o3 = FractionalIndex.between(o2, nil)
    let o4 = FractionalIndex.between(o3, nil)
    let o5 = FractionalIndex.between(o4, nil)
    let o6 = FractionalIndex.between(o5, nil)

    return [
        Todo(id: "t1", title: "Buy groceries", notes: "Milk, eggs, bread",
             isDone: false, kind: .task, scheduledFor: today, dueAt: nil,
             createdAt: now.addingTimeInterval(-3_600), updatedAt: now, ownerUid: ownerUid, order: o1),

        Todo(id: "t2", title: "Finish writeup", notes: "Focus on the conclusion",
             isDone: false, kind: .reminder, scheduledFor: today,
             dueAt: tomorrow,
             createdAt: now.addingTimeInterval(-7_200), updatedAt: now, ownerUid: ownerUid, order: o2),

        Todo(id: "t3", title: "Stretch (2 min)", notes: "",
             isDone: true, kind: .task, scheduledFor: today, dueAt: nil,
             createdAt: now.addingTimeInterval(-86_400), updatedAt: now, ownerUid: ownerUid, order: o3),

        Todo(id: "t4", title: "Review PR", notes: "Focus on the auth changes",
             isDone: false, kind: .notes, scheduledFor: yesterday, dueAt: nil,
             createdAt: now.addingTimeInterval(-10_000), updatedAt: now, ownerUid: ownerUid, order: o4),

        Todo(id: "t5", title: "Plan sprint", notes: "",
             isDone: false, kind: .task, scheduledFor: tomorrow, dueAt: nil,
             createdAt: now.addingTimeInterval(-5_000), updatedAt: now, ownerUid: ownerUid, order: o5),

        Todo(id: "t6", title: "Read chapter 4", notes: "",
             isDone: false, kind: .task, scheduledFor: nextWeek, dueAt: nil,
             createdAt: now.addingTimeInterval(-2_000), updatedAt: now, ownerUid: ownerUid, order: o6),
    ]
}

#endif // DEBUG
