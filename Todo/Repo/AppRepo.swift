//
//  AppRepo.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

protocol AppRepository {
    func streamTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]>
    func create(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> Todo
    func update(uid: String, todo: Todo) async throws
    func delete(uid: String, id: String) async throws
}

final class FirebaseAppRepository: AppRepository {
    private let client: FirebaseClient
    init(client: FirebaseClient) { self.client = client }

    func streamTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        client.listenTodos(uid: uid, filter: filter) // you already have this
    }
    func create(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> Todo {
        try await client.createTodo(uid: uid, title: title, kind: kind, dueAt: dueAt)
    }
    func update(uid: String, todo: Todo) async throws { try await client.updateTodo(uid: uid, todo: todo) }
    func delete(uid: String, id: String) async throws { try await client.deleteTodo(uid: uid, id: id) }
}
