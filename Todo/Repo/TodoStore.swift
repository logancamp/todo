//
//  TodoStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation
import Observation

// @MainActor on the protocol → conformance no longer crosses isolation
@MainActor
protocol SessionProviding: AnyObject {
    var uid: String? { get }
}

@Observable
@MainActor
final class TodoStore {
    private(set) var items: [Todo] = []
    private(set) var sections: [TodoSection] = []
    var loading = false
    var lastError: Error?

    private let repo: AppRepository
    private let session: SessionProviding
    private let bucketizer: Bucketizer
    private let mapper: SectionMapper
    private let validator: Validator
    private var streamTask: Task<Void, Never>?

    init(
        repo: AppRepository,
        session: SessionProviding,
        bucketizer: Bucketizer,
        mapper: SectionMapper,
        validator: Validator
    ) {
        self.repo = repo
        self.session = session
        self.bucketizer = bucketizer
        self.mapper = mapper
        self.validator = validator
    }

    func start(filter: TodoFilter = .all) {
        guard let uid = session.uid else { items = []; sections = []; return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in repo.streamTodos(uid: uid, filter: filter) {
                self.items = snapshot
                self.recomputeSections()
            }
        }
    }

    func stop() { streamTask?.cancel(); streamTask = nil }
    func refresh(filter: TodoFilter = .all) { stop(); start(filter: filter) }

    func add(title: String, kind: TodoKind = .task, dueAt: Date? = nil) async {
        guard let uid = session.uid else { return }
        do {
            try validator.validateDraft(.init(title: title, kind: kind, dueAt: dueAt))
            loading = true; defer { loading = false }
            _ = try await repo.create(uid: uid, title: title, kind: kind, dueAt: dueAt)
        } catch { lastError = error }
    }

    func rename(_ id: String, to newTitle: String) async {
        guard let uid = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        do {
            try validator.validatePatch(.init(title: newTitle, dueAt: nil, isDone: nil))
            todo.title = newTitle; todo.updatedAt = Date()
            await upsert(uid: uid, todo)
        } catch { lastError = error }
    }

    func setDueDate(_ id: String, to newDate: Date?) async {
        guard let uid = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        do {
            try validator.validatePatch(.init(title: nil, dueAt: .some(newDate), isDone: nil))
            todo.dueAt = newDate; todo.updatedAt = Date()
            await upsert(uid: uid, todo)
        } catch { lastError = error }
    }

    func toggle(_ id: String, to done: Bool) async {
        guard let uid = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        todo.isDone = done; todo.updatedAt = Date()
        await upsert(uid: uid, todo)
    }

    func moveItem(_ id: String, to target: BucketID) async {
        guard let uid = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        bucketizer.policy.mutateOnMove(&todo, to: target)
        await upsert(uid: uid, todo)
    }

    func delete(_ id: String) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do { try await repo.delete(uid: uid, id: id) }
        catch { lastError = error }
    }

    private func upsert(uid: String, _ todo: Todo) async {
        loading = true; defer { loading = false }
        do { try await repo.update(uid: uid, todo: todo) }
        catch { lastError = error }
    }

    private func recomputeSections() {
        sections = mapper.map(bucketizer.group(items))
    }

    deinit {
        MainActor.assumeIsolated { streamTask?.cancel() }
    }
}
