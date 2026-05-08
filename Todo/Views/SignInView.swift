//
//  SignInView.swift
//  Todo
//
//  Created by Logan Camp on 9/20/25.
//

import SwiftUI

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $isSignUp) {
                Text("Sign in").tag(false)
                Text("Sign up").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isSignUp) {
                session.lastError = nil   // clear stale error when switching tabs
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            SecureField("Password", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)

            if let err = session.lastError {
                Text(err.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button(isSignUp ? "Create account" : "Sign in") {
                Task {
                    do {
                        if isSignUp {
                            try await session.signUp(email: email, password: password)
                        } else {
                            try await session.signIn(email: email, password: password)
                        }
                    } catch {
                        // session.lastError already set by store
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)

            if !isSignUp {
                Button("Forgot password?") {
                    Task {
                        do { try await session.sendPasswordReset(email: email) } catch { }
                    }
                }
                .font(.footnote)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding()
    }
}

#Preview("SignInView – error") {
    let session = SessionStore()
    session.lastError = NSError(
        domain: "Preview", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"]
    )
    return SignInView().environment(session)
}
