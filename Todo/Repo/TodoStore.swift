//
//  TodoStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation
import Observation

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
        self.repo = repo; self.session = session
        self.bucketizer = bucketizer; self.mapper = mapper; self.validator = validator
    }

    // MARK: - Stream

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

    // MARK: - CRUD

    func add(
        title: String,
        kind: TodoKind = .task,
        dueAt: Date? = nil,
        notes: String = "",
        insertBeforeOrder: String? = nil   // order of current first item in target section
    ) async {
        guard let uid = session.uid else { return }
        do {
            try validator.validateDraft(.init(title: title, kind: kind, dueAt: dueAt))
            loading = true; defer { loading = false }
            let order = FractionalIndex.between(nil, insertBeforeOrder)
            _ = try await repo.create(uid: uid, title: title, notes: notes, kind: kind, dueAt: dueAt, order: order)
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

    func delete(_ id: String) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do { try await repo.delete(uid: uid, id: id) }
        catch { lastError = error }
    }

    // MARK: - Drag/drop reorder

    /// Move `id` to after `afterID` in `sectionID`.
    /// Pass nil `afterID` to place at the top of the section.
    /// Automatically updates dueAt when moving across sections.
    func reorder(id: String, afterID: String?, inSectionID: String) async {
        guard let uid = session.uid,
              var todo = items.first(where: { $0.id == id }) else { return }

        // Peers = section items excluding the dragged item
        let peers = sections
            .first(where: { $0.id == inSectionID })?.items
            .filter { $0.id != id } ?? []

        let afterIdx = afterID.flatMap { aid in peers.firstIndex(where: { $0.id == aid }) }
        let lo: String? = afterIdx.map { peers[$0].order }
        let hi: String? = {
            if let idx = afterIdx {
                return idx + 1 < peers.count ? peers[idx + 1].order : nil
            }
            return peers.first?.order   // inserting at top → hi is current first item
        }()

        todo.order = FractionalIndex.between(lo, hi)

        // Cross-section move: update dueAt via bucket policy
        if let bucket = SectionMapper.bucket(from: inSectionID, clock: bucketizer.policy.clock) {
            bucketizer.policy.mutateOnMove(&todo, to: bucket)
        }

        todo.updatedAt = Date()
        await upsert(uid: uid, todo)
    }

    func moveItem(_ id: String, to target: BucketID) async {
        guard let uid = session.uid, var todo = items.first(where: { $0.id == id }) else { return }
        bucketizer.policy.mutateOnMove(&todo, to: target)
        await upsert(uid: uid, todo)
    }

    // MARK: - Private

    private func upsert(uid: String, _ todo: Todo) async {
        loading = true; defer { loading = false }
        do { try await repo.update(uid: uid, todo: todo) }
        catch { lastError = error }
    }

    private func recomputeSections() {
        sections = mapper.map(bucketizer.group(items))
    }

    deinit { MainActor.assumeIsolated { streamTask?.cancel() } }
}
