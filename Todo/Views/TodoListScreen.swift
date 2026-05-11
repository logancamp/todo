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
    @State private var currentSectionID = ""
    @State private var expandedTodoID: Todo.ID?
    @State private var activeFilter: TodoFilter = .all
    @State private var showingError = false

    @State private var draftSectionID: String? = nil
    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var draftKind: TodoKind = .task
    @State private var draftScheduledFor: Date? = nil
    @State private var draftDueAt: Date? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                headerBar
                listContent
            }

            if store.loading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(.trailing, 24)
                    .padding(.bottom, 80)
            }

            FloatingActionButton(systemImage: "plus") { openDraft() }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
        .onAppear { store.start(filter: activeFilter) }
        .onDisappear { store.stop() }
        .alert("Something went wrong", isPresented: $showingError) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError?.localizedDescription ?? "")
        }
        .onChange(of: store.lastError == nil) {
            showingError = store.lastError != nil
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if store.sections.isEmpty && !store.loading {
            emptyState
        } else {
            TodoScrollHost(
                sections: store.sections,
                collapse: $collapse,
                onCenteredSectionChange: { id in
                    DispatchQueue.main.async {
                        currentSectionID = id
                        currentSectionTitle = store.sections.first(where: { $0.id == id })?.title ?? id
                    }
                },
                onSelect: { _ in },
                onDelete: { id in
                    Task { await store.delete(id) }
                },
                onMove: { id, afterID, beforeID, sectionID in
                    Task { await store.reorder(id: id, afterID: afterID, beforeID: beforeID, inSectionID: sectionID) }
                },
                onBackgroundTap: {
                    withAnimation(.snappy) { expandedTodoID = nil }
                },
                draftSectionID: draftSectionID,
                draftView: draftSectionID != nil ? {
                    AnyView(
                        TodoDraftRow(
                            title: $draftTitle,
                            notes: $draftNotes,
                            kind: $draftKind,
                            scheduledFor: $draftScheduledFor,
                            dueAt: $draftDueAt,
                            onSave: saveDraft,
                            onCancel: clearDraft
                        )
                    )
                } : nil,
                rowView: { todo in
                    TodoItemView(
                        todo: todo,
                        expandedTodoID: $expandedTodoID,
                        onToggle: { Task { await store.toggle(todo.id, to: !todo.isDone) } },
                        onSave: { title, notes, kind, scheduledFor, dueAt in
                            Task { await store.update(todo.id, title: title, notes: notes, kind: kind, scheduledFor: scheduledFor, dueAt: dueAt) }
                        }
                    )
                },
                headerView: { section in
                    TodoSectionHeaderView(section: section)
                }
            )
        }
    }

    // MARK: - Header

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
                Button(role: .destructive) { try? session.signOut() } label: {
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

    // MARK: - Draft

    private func openDraft() {
        let targetID = currentSectionID.isEmpty ? "someday" : currentSectionID
        draftScheduledFor = SectionMapper.date(from: targetID)
        draftDueAt = nil
        draftKind = .task
        draftTitle = ""
        draftNotes = ""
        draftSectionID = targetID
    }

    private func saveDraft() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let sectionID = draftSectionID else { clearDraft(); return }
        let insertBeforeOrder = store.sections
            .first(where: { $0.id == sectionID })?.items.first?.order
        Task {
            await store.add(
                title: trimmed,
                kind: draftKind,
                scheduledFor: draftScheduledFor,
                dueAt: draftDueAt,
                notes: draftNotes,
                insertBeforeOrder: insertBeforeOrder
            )
        }
        clearDraft()
    }

    private func clearDraft() {
        draftSectionID = nil
        draftTitle = ""
        draftNotes = ""
        draftKind = .task
        draftScheduledFor = nil
        draftDueAt = nil
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

#Preview("TodoListScreen") {
    TodoListScreen()
        .environment(TodoStore.preview)
        .environment(SessionStore())
}
