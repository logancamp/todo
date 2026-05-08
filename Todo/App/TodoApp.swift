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
    @State private var session: SessionStore
    @State private var todoStore: TodoStore

    init() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()

        let session = SessionStore()
        let client = FirebaseClient()
        let repo: AppRepository = FirebaseAppRepository(client: client)
        let policy = BucketPolicy(clock: BucketClock())
        let store = TodoStore(
            repo: repo,
            session: session,
            bucketizer: Bucketizer(policy: policy),
            mapper: SectionMapper(policy: policy),
            validator: Validator()
        )
        _session = State(initialValue: session)
        _todoStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environment(session)
                .environment(todoStore)
        }
    }
}

// MARK: - Root navigation gate

struct RootGate: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        switch session.state {
        case .signedOut:
            SignInView()
        case .signedIn(let verified):
            if verified {
                TodoListScreen()
            } else {
                VerifyEmailView()
            }
        case .pending:
            ProgressView("Loading…")
                .progressViewStyle(.circular)
        }
    }
}
