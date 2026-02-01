//
//  SignInView.swift
//  Todo
//
//  Created by Logan Camp on 9/20/25.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $isSignUp) {
                Text("Sign In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            SecureField("Password", text: $password)

            if let err = session.lastError {
                Text(err.localizedDescription)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button(isSignUp ? "Create Account" : "Sign In") {
                Task {
                    if isSignUp {
                        try? await session.signUp(email: email, password: password)
                    } else {
                        try? await session.signIn(email: email, password: password)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)

            if !isSignUp {
                Button("Forgot Password?") {
                    Task { try? await session.sendPasswordReset(email: email) }
                }
                .font(.footnote)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding()
    }
}

#Preview("SignInView – Error") {
    let session = SessionStore()
    session.lastError = NSError(
        domain: "Preview",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"]
    )

    return SignInView()
        .environmentObject(session)
}
