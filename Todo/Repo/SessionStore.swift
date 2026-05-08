//
//  SessionStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Observation
import FirebaseAuth

@Observable
@MainActor
final class SessionStore {
    enum AuthState {
        case pending
        case signedOut
        case signedIn(verified: Bool)
    }

    private(set) var state: AuthState = .pending
    private(set) var uid: String?
    private(set) var email: String?
    var lastError: Error?

    @ObservationIgnored
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private let auth: AuthClient

    init(auth: AuthClient = FirebaseClient()) {
        self.auth = auth
        authStateHandle = auth.addAuthListener { [weak self] user in
            Task { @MainActor [weak self] in
                self?.apply(user: user)
            }
        }
        apply(user: auth.currentUser)
    }

    deinit {
        MainActor.assumeIsolated {
            if let handle = authStateHandle {
                auth.removeAuthListener(handle)
            }
        }
    }

    // MARK: - Auth actions

    func signUp(email: String, password: String) async throws {
        lastError = nil
        state = .pending
        do {
            _ = try await auth.signUp(email: email, password: password)
            try? await auth.reloadUser()
            apply(user: auth.currentUser)
        } catch {
            lastError = error
            state = .signedOut
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        lastError = nil
        state = .pending
        do {
            _ = try await auth.signIn(email: email, password: password)
            try? await auth.reloadUser()
            apply(user: auth.currentUser)
        } catch {
            lastError = error
            state = .signedOut
            throw error
        }
    }

    func signOut() throws {
        do {
            try auth.signOut()
            apply(user: nil)
        } catch {
            lastError = error
            throw error
        }
    }

    func sendEmailVerification() async throws {
        do {
            try await auth.sendEmailVerification()
        } catch {
            lastError = error
            throw error
        }
    }

    func reloadUser() async throws {
        do {
            try await auth.reloadUser()
            apply(user: auth.currentUser)
        } catch {
            lastError = error
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(email: email)
        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Private

    private func apply(user: User?) {
        if let u = user {
            uid = u.uid
            email = u.email
            state = .signedIn(verified: u.isEmailVerified)
        } else {
            uid = nil
            email = nil
            state = .signedOut
        }
    }
}

extension SessionStore: SessionProviding {}
