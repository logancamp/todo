//
//  TodoListScreen.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoListScreen: View {
    @EnvironmentObject var store: TodoStore
    @State private var collapse: CGFloat = 0
    @State private var currentSection: String = ""
    @State private var showingNewTodo = false
    @State private var newTitle: String = ""
    @State private var expandedTodoID: Todo.ID? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                CollapsingHeaderView(title: currentSection, collapse: $collapse)

                TodoScrollHost(
                    sections: store.sections,
                    collapse: $collapse,
                    onCenteredSectionChange: { currentSection = $0 },
                    onSelect: { id in
                        // optional: keep or remove selection behavior
                        print("selected", id)
                    },
                    rowView: { todo in
                        AnyView(
                            TodoItemView(todo: todo, expandedTodoID: $expandedTodoID)
                        )
                    },
                    headerView: { section in
                        AnyView(TodoSectionHeaderView(section: section))
                    }
                )
            }

            FloatingActionButton(systemImage: "plus") {
                showingNewTodo = true
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        .onAppear { store.start(filter: .all) }
        .onDisappear { store.stop() }
        .sheet(isPresented: $showingNewTodo) {
            NavigationStack {
                Form {
                    Section("New Todo") {
                        TextField("Title", text: $newTitle)
                    }
                }
                .navigationTitle("Add")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            newTitle = ""
                            showingNewTodo = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }
                            Task {
                                await store.add(title: title, kind: .task, dueAt: nil)
                                await MainActor.run {
                                    newTitle = ""
                                    showingNewTodo = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("TodoListScreen") {
    TodoListScreen()
        .environmentObject(TodoStore.preview)
}
