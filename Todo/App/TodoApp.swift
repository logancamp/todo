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
    // Session and repositories
    @StateObject private var session: SessionStore
    private let repo: AppRepository
    private let client: FirebaseClient

    // Dependencies for TodoStore
    private let policy: BucketPolicy
    private let bucketizer: Bucketizer
    private let mapper: SectionMapper
    private let validator: Validator

    @StateObject private var todoStore: TodoStore

    init() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()

        print("Project ID:", FirebaseApp.app()?.options.projectID ?? "nil")

        // Create all dependencies as local constants first
        let client = FirebaseClient()
        let repo: AppRepository = FirebaseAppRepository(client: client)
        let policy = BucketPolicy(clock: BucketClock())
        let bucketizer = Bucketizer(policy: policy)
        let mapper = SectionMapper(policy: policy)
        let validator = Validator()
        let session = SessionStore()

        // Initialize StateObjects with wrappedValue without capturing self
        _session = StateObject(wrappedValue: session)
        _todoStore = StateObject(wrappedValue: TodoStore(
            repo: repo,
            session: session,
            bucketizer: bucketizer,
            mapper: mapper,
            validator: validator
        ))

        // Assign non-StateObject stored properties
        self.client = client
        self.repo = repo
        self.policy = policy
        self.bucketizer = bucketizer
        self.mapper = mapper
        self.validator = validator
    }
    
    var body: some Scene {
        WindowGroup {
            RootGate()
                .environmentObject(session)
                .environmentObject(todoStore)
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
