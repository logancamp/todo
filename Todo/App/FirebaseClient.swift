//
//  FirebaseClient.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation
import FirebaseAuth

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
    // MARK: read-only
    var currentUser: User? { Auth.auth().currentUser }
    var uid: String? { currentUser?.uid }
    var isVerified: Bool { currentUser?.isEmailVerified ?? false }

    // MARK: listeners
    @discardableResult
    func addAuthListener(_ onChange: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in onChange(user) }
    }
    func removeAuthListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    // MARK: sign up / in / out
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

// MARK: - TodoStore temporary stubs
extension FirebaseClient {
    // TODO: Wire up to Firestore and implement real logic.
    func listenTodos(uid: String, filter: TodoFilter) -> AsyncStream<[Todo]> {
        // Temporary: return an empty stream that finishes immediately.
        return AsyncStream { continuation in
            continuation.finish()
        }
    }

    func createTodo(uid: String, title: String, kind: TodoKind, dueAt: Date?) async throws -> String {
        // Temporary stub implementation
        throw NSError(domain: "FirebaseClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "createTodo(uid:title:kind:dueAt:) not implemented"]) 
    }

    func updateTodo(uid: String, todo: Todo) async throws {
        // Temporary stub implementation
        throw NSError(domain: "FirebaseClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "updateTodo(uid:todo:) not implemented"]) 
    }

    func deleteTodo(uid: String, id: String) async throws {
        // Temporary stub implementation
        throw NSError(domain: "FirebaseClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "deleteTodo(uid:id:) not implemented"]) 
    }
}

// MARK: - Small internal error
private enum AuthError: Error { case noCurrentUser }
