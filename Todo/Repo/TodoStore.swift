//
//  TodoStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//


//
//  TodoStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

@MainActor
final class TodoStore: ObservableObject {
    // MARK: - Published state for views
    @Published private(set) var items: [Todo] = []
    @Published var loading: Bool = false
    @Published var lastError: Error?

    // MARK: - Dependencies
    private let client: FirebaseClient
    private let session: SessionStore
    private var streamTask: Task<Void, Never>? = nil

    // MARK: - Init
    init(client: FirebaseClient, session: SessionStore) {
        self.client = client
        self.session = session
    }

    // MARK: - Live stream
    /// Start (or restart) a live stream of todos for the current user.
    func start(filter: TodoFilter = .all) {
        guard let uid = session.uid else {
            items = []
            return
        }
        // Cancel any previous listener
        streamTask?.cancel()
        streamTask = Task {
            for await snapshot in client.listenTodos(uid: uid, filter: filter) {
                await MainActor.run { self.items = snapshot }
            }
        }
    }

    /// Stop listening for updates.
    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Manual refresh helper (restarts listener with the same filter)
    func refresh(filter: TodoFilter = .all) async {
        stop()
        start(filter: filter)
    }

    // MARK: - CRUD
    func add(title: String, kind: TodoKind = .task, dueAt: Date? = nil) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do {
            _ = try await client.createTodo(uid: uid, title: title, kind: kind, dueAt: dueAt)
        } catch {
            lastError = error
        }
    }

    func toggle(_ id: String, to done: Bool) async {
        guard let _ = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        todo.isDone = done
        todo.updatedAt = Date()
        await upsert(todo)
    }

    func rename(_ id: String, to newTitle: String) async {
        guard let _ = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        todo.title = newTitle
        todo.updatedAt = Date()
        await upsert(todo)
    }

    func setDueDate(_ id: String, to newDate: Date?) async {
        guard let _ = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        todo.dueAt = newDate
        todo.updatedAt = Date()
        await upsert(todo)
    }

    private func upsert(_ todo: Todo) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do { try await client.updateTodo(uid: uid, todo: todo) }
        catch { lastError = error }
    }

    func delete(_ id: String) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do { try await client.deleteTodo(uid: uid, id: id) }
        catch { lastError = error }
    }

    // MARK: - Derived slices (for views)
    var pending: [Todo] { items.filter { !$0.isDone } }
    var completed: [Todo] { items.filter { $0.isDone } }
    var dueToday: [Todo] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return items.filter { t in
            guard let d = t.dueAt else { return false }
            return d >= start && d < end
        }
    }
    func byKind(_ k: TodoKind) -> [Todo] { items.filter { $0.kind == k } }

    deinit { streamTask?.cancel() }
}
