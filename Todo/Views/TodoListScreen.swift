//
//  TodoListScreen.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoListScreen: View {
    @Environment(TodoStore.self) private var store
    @Environment(SessionStore.self) private var session

    @State private var collapse: CGFloat = 0
    @State private var currentSectionTitle = ""
    @State private var showingNewTodo = false
    @State private var expandedTodoID: Todo.ID?
    @State private var activeFilter: TodoFilter = .all
    @State private var showingError = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                headerBar

                if store.sections.isEmpty && !store.loading {
                    emptyState
                } else {
                    TodoScrollHost(
                        sections: store.sections,
                        collapse: $collapse,
                        onCenteredSectionChange: { id in
                            // Map ID → title so header shows "Someday" not "someday"
                            currentSectionTitle = store.sections
                                .first(where: { $0.id == id })?.title ?? id
                        },
                        onSelect: { id in
                            withAnimation(.snappy) {
                                expandedTodoID = expandedTodoID == id ? nil : id
                            }
                        },
                        onDelete: { id in Task { await store.delete(id) } },
                        rowView: { todo in
                            TodoItemView(
                                todo: todo,
                                expandedTodoID: $expandedTodoID,
                                onToggle: { Task { await store.toggle(todo.id, to: !todo.isDone) } }
                            )
                        },
                        headerView: { section in
                            TodoSectionHeaderView(section: section)
                        }
                    )
                }
            }

            if store.loading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.trailing, 24)
                    .padding(.bottom, 80)
            }

            FloatingActionButton(systemImage: "plus") {
                showingNewTodo = true
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        .onAppear { store.start(filter: activeFilter) }
        .onDisappear { store.stop() }
        .sheet(isPresented: $showingNewTodo) {
            NewTodoSheet(isPresented: $showingNewTodo)
        }
        .alert("Something went wrong", isPresented: $showingError) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError?.localizedDescription ?? "")
        }
        .onChange(of: store.lastError == nil) {
            showingError = store.lastError != nil
        }
    }

    // MARK: - Header with filter menu + sign out

    private var headerBar: some View {
        ZStack(alignment: .topTrailing) {
            CollapsingHeaderView(title: currentSectionTitle, collapse: $collapse)

            Menu {
                Section("Show") {
                    filterButton("All",       filter: .all,       icon: "tray")
                    filterButton("Active",    filter: .pending,   icon: "circle")
                    filterButton("Completed", filter: .completed, icon: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    try? session.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: menuIcon)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
            .padding(.top, 8)
            .accessibilityLabel("Menu")
        }
    }

    private func filterButton(_ label: String, filter: TodoFilter, icon: String) -> some View {
        Button {
            guard filter != activeFilter else { return }
            activeFilter = filter
            store.refresh(filter: filter)
        } label: {
            Label(label, systemImage: activeFilter == filter ? "\(icon).fill" : icon)
        }
    }

    private var menuIcon: String {
        activeFilter == .all
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add one.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyMessage: String {
        switch activeFilter {
        case .all:       return "No todos yet"
        case .pending:   return "Nothing active"
        case .completed: return "Nothing completed"
        }
    }
}

// MARK: - New todo sheet

private struct NewTodoSheet: View {
    @Environment(TodoStore.self) private var store
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var kind: TodoKind = .task
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .submitLabel(.done)
                }

                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(TodoKind.allCases) { k in
                            Text(k.rawValue.capitalized).tag(k)
                        }
                    }

                    Toggle("Due date", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
            }
            .navigationTitle("New todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            await store.add(title: trimmed, kind: kind, dueAt: hasDueDate ? dueDate : nil)
                            dismiss()
                        }
                    }
                    .bold()
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func dismiss() { title = ""; isPresented = false }
}

#Preview("TodoListScreen") {
    TodoListScreen()
        .environment(TodoStore.preview)
        .environment(SessionStore())
}
