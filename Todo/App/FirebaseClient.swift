//
//  FirebaseClient.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth protocol

protocol AuthClient {
    var currentUser: User? { get }
    var uid: String? { get }
    var isVerified: Bool { get }

    @discardableResult
    func addAuthListener(_ onChange: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle)

    func signUp(email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() throws
    func sendEmailVerification() async throws
    func reloadUser() async throws
    func sendPasswordReset(email: String) async throws
}

// MARK: - Firebase implementation

final class FirebaseClient: AuthClient {
    var currentUser: User? { Auth.auth().currentUser }
    var uid: String? { currentUser?.uid }
    var isVerified: Bool { currentUser?.isEmailVerified ?? false }

    @discardableResult
    func addAuthListener(_ onChange: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in onChange(user) }
    }

    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
        return result.user
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        try await result.user.reload()
        return result.user
    }

    func signOut() throws { try Auth.auth().signOut() }

    func sendEmailVerification() async throws {
        guard let user = currentUser else { throw AuthError.noCurrentUser }
        try await user.sendEmailVerification()
    }

    func reloadUser() async throws {
        guard let user = currentUser else { throw AuthError.noCurrentUser }
        try await user.reload()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}

// MARK: - Firestore

extension FirebaseClient {
    private var db: Firestore { Firestore.firestore() }

    private func todosCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("todos")
    }

    func listenTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        let base = todosCollection(uid: uid)

        let query: Query = {
            switch filter {
            case .all:      return base
            case .completed: return base.whereField("isDone", isEqualTo: true)
            case .pending:   return base.whereField("isDone", isEqualTo: false)
            }
        }()

        let ordered = query.order(by: "createdAt", descending: false)

        return AsyncStream { continuation in
            let listener = ordered.addSnapshotListener { snapshot, error in
                if error != nil { continuation.finish(); return }
                guard let snapshot else { continuation.yield([]); return }

                // Codable decoding via FirebaseFirestoreSwift — safe, type-checked
                let todos: [Todo] = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Todo.self)
                }
                continuation.yield(todos)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func createTodo(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> Todo {
        let ref = todosCollection(uid: uid).document()
        let now = Date()
        let todo = Todo(
            id: ref.documentID,
            title: title,
            isDone: false,
            kind: kind,
            dueAt: dueAt,
            createdAt: now,
            updatedAt: now,
            ownerUid: uid
        )
        try ref.setData(from: todo)   // Codable encoding; nil dueAt omits the field
        return todo
    }

    func updateTodo(uid: String, todo: Todo) async throws {
        let ref = todosCollection(uid: uid).document(todo.id)
        try ref.setData(from: todo)   // full replace — safer than merge:true
    }

    func deleteTodo(uid: String, id: String) async throws {
        try await todosCollection(uid: uid).document(id).delete()
    }
}

// MARK: - Errors

private enum AuthError: Error { case noCurrentUser }
