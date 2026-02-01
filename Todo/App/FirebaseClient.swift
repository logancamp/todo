//
//  FirebaseClient.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth used by store files
protocol AuthClient {
    var currentUser: User? { get }
    var uid: String? { get }
    var isVerified: Bool { get }

    @discardableResult
    func addAuthListener(_ onChange: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle
    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle)

    // email+password flows
    func signUp(email: String, password: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() throws

    // account utilities
    func sendEmailVerification() async throws
    func reloadUser() async throws
    func sendPasswordReset(email: String) async throws
}

final class FirebaseClient: AuthClient {
    // read-only
    var currentUser: User? { Auth.auth().currentUser }
    var uid: String? { currentUser?.uid }
    var isVerified: Bool { currentUser?.isEmailVerified ?? false }

    // listeners
    @discardableResult
    func addAuthListener(_ onChange: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in onChange(user) }
    }
    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    // sign up / in / out
    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
        return result.user
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        // refresh flags after sign-in
        try await result.user.reload()
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: Utilities
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

// MARK: - TodoStore Firestore implementation
extension FirebaseClient {
    private var db: Firestore { Firestore.firestore() }

    private func todosCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("todos")
    }

    func listenTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        let base = todosCollection(uid: uid)

        // Query filtering
        let query: Query = {
            switch filter {
            case .all:
                return base
            case .completed:
                return base.whereField("isDone", isEqualTo: true)
            case .pending:
                return base.whereField("isDone", isEqualTo: false)
            }
        }()

        // Optional ordering (remove if you prefer “whatever Firestore gives”)
        let ordered = query.order(by: "createdAt", descending: false)

        return AsyncStream { continuation in
            let listener = ordered.addSnapshotListener { snapshot, error in
                if let err = error {
                    print("Firestore listener error:", err)
                    continuation.finish()
                    return
                }
                guard let snapshot else {
                    continuation.yield([])
                    return
                }

                let todos: [Todo] = snapshot.documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let title = data["title"] as? String,
                        let isDone = data["isDone"] as? Bool,
                        let kindRaw = data["kind"] as? String,
                        let kind = TodoKind(rawValue: kindRaw),
                        let ownerUid = data["ownerUid"] as? String,
                        let createdAtTS = data["createdAt"] as? Timestamp,
                        let updatedAtTS = data["updatedAt"] as? Timestamp
                    else {
                        return nil
                    }

                    let dueAt: Date?
                    if let dueTS = data["dueAt"] as? Timestamp {
                        dueAt = dueTS.dateValue()
                    } else {
                        dueAt = nil
                    }

                    // Prefer stored "id" if present; else use docID (robust to older docs)
                    let storedID = data["id"] as? String
                    let id = storedID ?? doc.documentID

                    return Todo(
                        id: id,
                        title: title,
                        isDone: isDone,
                        kind: kind,
                        dueAt: dueAt,
                        createdAt: createdAtTS.dateValue(),
                        updatedAt: updatedAtTS.dateValue(),
                        ownerUid: ownerUid
                    )
                }

                continuation.yield(todos)
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
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

        var data: [String: Any] = [
            "id": todo.id,
            "title": todo.title,
            "isDone": todo.isDone,
            "kind": todo.kind.rawValue,
            "createdAt": Timestamp(date: todo.createdAt),
            "updatedAt": Timestamp(date: todo.updatedAt),
            "ownerUid": todo.ownerUid
        ]
        if let dueAt = todo.dueAt {
            data["dueAt"] = Timestamp(date: dueAt)
        }

        try await ref.setData(data)
        return todo
    }

    func updateTodo(uid: String, todo: Todo) async throws {
        let ref = todosCollection(uid: uid).document(todo.id)

        var data: [String: Any] = [
            "id": todo.id,
            "title": todo.title,
            "isDone": todo.isDone,
            "kind": todo.kind.rawValue,
            "createdAt": Timestamp(date: todo.createdAt),
            "updatedAt": Timestamp(date: todo.updatedAt),
            "ownerUid": todo.ownerUid
        ]
        if let dueAt = todo.dueAt {
            data["dueAt"] = Timestamp(date: dueAt)
        } else {
            // Explicitly clear due date if set to nil
            data["dueAt"] = FieldValue.delete()
        }

        try await ref.setData(data, merge: true)
    }

    func deleteTodo(uid: String, id: String) async throws {
        try await todosCollection(uid: uid).document(id).delete()
    }
}

// MARK: - Small internal error
private enum AuthError: Error { case noCurrentUser }

