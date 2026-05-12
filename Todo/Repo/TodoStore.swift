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
    private var activeFilter: TodoFilter = .all
    private var ordersRepaired = false

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
        activeFilter = filter
        guard let uid = session.uid else { items = []; sections = []; return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in repo.streamTodos(uid: uid, filter: filter) {
                self.items = snapshot
                self.recomputeSections()
                if !self.ordersRepaired {
                    self.ordersRepaired = true
                    await self.repairDuplicateOrders(uid: uid)
                }
            }
        }
    }

    func stop() { streamTask?.cancel(); streamTask = nil }
    func refresh(filter: TodoFilter = .all) { stop(); start(filter: filter) }

    // MARK: - CRUD

    @discardableResult
    func add(
        title: String,
        kind: TodoKind = .task,
        scheduledFor: Date? = nil,
        dueAt: Date? = nil,
        notes: String = "",
        insertAfterOrder: String? = nil,
        insertBeforeOrder: String? = nil
    ) async -> Todo? {
        guard let uid = session.uid else { return nil }
        do {
            try validator.validateDraft(.init(title: title, kind: kind, dueAt: scheduledFor))
            loading = true; defer { loading = false }
            let order = FractionalIndex.between(insertAfterOrder, insertBeforeOrder)
            let todo = try await repo.create(
                uid: uid, title: title, notes: notes, kind: kind,
                scheduledFor: scheduledFor, dueAt: dueAt, order: order
            )
            return todo
        } catch {
            lastError = error
            return nil
        }
    }

    func update(_ id: String, title: String, notes: String, kind: TodoKind, scheduledFor: Date?, dueAt: Date?) async {
        guard let uid = session.uid,
              var todo = items.first(where: { $0.id == id }) else { return }
        do {
            try validator.validatePatch(.init(title: title, dueAt: .some(scheduledFor), isDone: nil))
            todo.title = title; todo.notes = notes; todo.kind = kind
            todo.scheduledFor = scheduledFor; todo.dueAt = dueAt; todo.updatedAt = Date()
            await upsert(uid: uid, todo)
        } catch { lastError = error }
    }

    func toggle(_ id: String, to done: Bool) async {
        guard let uid = session.uid,
              var todo = items.first(where: { $0.id == id }) else { return }
        todo.isDone = done; todo.updatedAt = Date()
        await upsert(uid: uid, todo)
    }

    func delete(_ id: String) async {
        guard let uid = session.uid else { return }
        loading = true; defer { loading = false }
        do { try await repo.delete(uid: uid, id: id) }
        catch { lastError = error }
    }

    // MARK: - Reorder

    func reorder(id: String, afterID: String?, beforeID: String?, inSectionID: String) async {
        guard let uid = session.uid,
              let itemIdx = items.firstIndex(where: { $0.id == id }) else { return }

        var todo = items[itemIdx]

        let lo: String? = afterID.flatMap { aid in items.first(where: { $0.id == aid })?.order }
        let hi: String? = beforeID.flatMap { bid in items.first(where: { $0.id == bid })?.order }
        todo.order = FractionalIndex.between(lo, hi)

        // Only mutate the date if the item actually moved to a different section
        let currentSectionID = sections.first(where: { $0.items.contains(where: { $0.id == id }) })?.id
        if inSectionID != currentSectionID,
           let bucket = SectionMapper.bucket(from: inSectionID, clock: bucketizer.policy.clock) {
            bucketizer.policy.mutateOnMove(&todo, to: bucket)
        }

        todo.updatedAt = Date()
        items[itemIdx] = todo
        recomputeSections()

        stop()
        await upsert(uid: uid, todo)
        start(filter: activeFilter)
    }

    func moveItem(_ id: String, to target: BucketID) async {
        guard let uid = session.uid,
              var todo = items.first(where: { $0.id == id }) else { return }
        bucketizer.policy.mutateOnMove(&todo, to: target)
        await upsert(uid: uid, todo)
    }

    // MARK: - Order repair

    private func repairDuplicateOrders(uid: String) async {
        let allOrders = items.map(\.order)
        guard Set(allOrders).count != allOrders.count else { return }

        var toUpdate: [Todo] = []
        for section in sections {
            let sectionItems = section.items.sorted { $0.order < $1.order }
            var prev: String? = nil
            for var item in sectionItems {
                let newOrder = FractionalIndex.between(prev, nil)
                if newOrder != item.order {
                    item.order = newOrder
                    toUpdate.append(item)
                    if let idx = items.firstIndex(where: { $0.id == item.id }) {
                        items[idx] = item
                    }
                }
                prev = newOrder
            }
        }

        guard !toUpdate.isEmpty else { return }
        recomputeSections()
        for item in toUpdate {
            try? await repo.update(uid: uid, todo: item)
        }
    }

    // MARK: - Private

    private func upsert(uid: String, _ todo: Todo) async {
        loading = true; defer { loading = false }
        do { try await repo.update(uid: uid, todo: todo) }
        catch { lastError = error }
    }

    func recomputeSections() {
        sections = mapper.map(bucketizer.group(items))
    }

    deinit { MainActor.assumeIsolated { streamTask?.cancel() } }
}
