//
//  TodoApp.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseAppCheck

@main
struct TodoApp: App {
    @StateObject var session = SessionStore()
    private let client = FirebaseClient()
    
    init() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()
        
        print("Project ID:", FirebaseApp.app()?.options.projectID ?? "nil")
    }
    
    var body: some Scene {
        WindowGroup {
            RootGate()
                .environmentObject(session)
                .environmentObject(TodoStore(client: client, session: session))
        }
    }
}

// Gate struct for session navigation
struct RootGate: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        switch session.state {
        case .signedOut:
            SignInView()
        case .signedIn(let verified):
            if verified {
                TempView() // replace with your TodoList later
            } else {
                VerifyEmailView()
            }
        case .pending:
            ProgressView("Loading…")   // loading spinner
                .progressViewStyle(CircularProgressViewStyle())
        }
    }
}
