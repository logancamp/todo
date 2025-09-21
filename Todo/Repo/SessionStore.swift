//
//  SessionStore.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import FirebaseAuth
import Combine

@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case signedOut
        case pending
        case signedIn(verified: Bool)
    }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let auth: AuthClient

    @Published var state: State = .signedOut
    @Published var uid: String? = nil
    @Published var email: String? = nil
    @Published var lastError: Error? = nil

    init(auth: AuthClient = FirebaseClient()) {
        self.auth = auth
        self.authStateHandle = auth.addAuthListener { [weak self] user in
            Task { @MainActor in
                self?.apply(user: user)
            }
        }
        self.apply(user: auth.currentUser)
    }

    deinit {
        if let handle = authStateHandle {
            auth.removeAuthListener(handle)
        }
    }

    // TODO: Session Methods:
    func signUp(email: String, password: String) async throws {
        state = .pending
        defer {
            // if listener didn’t fire, fall back based on current user
            let u = auth.currentUser
            state = (u != nil) ? .signedIn(verified: u?.isEmailVerified ?? false) : .signedOut
        }
        do {
            _ = try await auth.signUp(email: email, password: password)
            try? await auth.reloadUser()
            apply(user: auth.currentUser)          // listener should also call apply()
            // optional: try? await auth.sendEmailVerification()
        } catch {
            lastError = error
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        state = .pending
        defer {
            let u = auth.currentUser
            state = (u != nil) ? .signedIn(verified: u?.isEmailVerified ?? false) : .signedOut
        }
        do {
            _ = try await auth.signIn(email: email, password: password)
            try? await auth.reloadUser()
            apply(user: auth.currentUser)
        } catch {
            lastError = error
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
    
//    func sendEmailVerification() async throws {
//        do {
//            try await auth.sendEmailVerification()
//        } catch {
//            lastError = error
//            throw error
//        }
//    }
    
    func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            print("[DEBUG] No current user, cannot send verification.")
            let err = NSError(domain: "SessionStore", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No signed-in user"])
            lastError = err
            throw err
        }
        print("[DEBUG] Attempting to send verification. uid:", user.uid,
              "email:", user.email ?? "nil",
              "verified:", user.isEmailVerified)

        do {
            try await user.sendEmailVerification()
            print("[DEBUG] Verification request sent successfully (Firebase accepted).")
        } catch {
            print("[DEBUG] sendEmailVerification threw error:", error)
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
        do { try await auth.sendPasswordReset(email: email) }
        catch { lastError = error; throw error }
    }
    
    // MARK: - Helpers
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
