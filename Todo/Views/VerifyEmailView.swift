//
//  Untitled.swift
//  Todo
//
//  Created by Logan Camp on 9/20/25.
//

import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        VStack(spacing: 12) {
            Text("Verify your email to continue")
                .font(.headline)
            Text("We’ve sent a verification link to your email. Open it, then tap the button below.")
                .multilineTextAlignment(.center)
                .font(.subheadline)

            if let err = session.lastError {
                Text(err.localizedDescription)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            HStack {
                Button("Resend Email") {
                    Task { try? await session.sendEmailVerification() }
                }
                Button("I Verified") {
                    Task { try? await session.reloadUser() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview("VerifyEmailView – Error") {
    let session = SessionStore()
    session.lastError = NSError(
        domain: "Preview",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Couldn’t send verification email."]
    )

    return VerifyEmailView()
        .environmentObject(session)
}
