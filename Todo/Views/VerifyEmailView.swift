//
//  Untitled.swift
//  Todo
//
//  Created by Logan Camp on 9/20/25.
//

import SwiftUI

struct VerifyEmailView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: 12) {
            Text("Verify your email")
                .font(.headline)
            Text("We've sent a verification link to your email. Open it, then tap the button below.")
                .multilineTextAlignment(.center)
                .font(.subheadline)

            if let err = session.lastError {
                Text(err.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            HStack {
                Button("Resend email") {
                    Task { do { try await session.sendEmailVerification() } catch { } }
                }
                Button("I verified") {
                    Task { do { try await session.reloadUser() } catch { } }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview("VerifyEmailView – error") {
    let session = SessionStore()
    session.lastError = NSError(
        domain: "Preview", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Couldn't send verification email."]
    )
    return VerifyEmailView().environment(session)
}
