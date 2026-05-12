//
//  TodoListScreen.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI
import Combine

struct TodoListScreen: View {
    @Environment(TodoStore.self) private var store
    @Environment(SessionStore.self) private var session

    @State private var collapse: CGFloat = 0
    @State private var currentSectionTitle = ""
    @State private var currentSectionID = ""
    @State private var topSectionID = ""
    @State private var activeFilter: TodoFilter = .all
    @State private var showingError = false
    @State private var keyboardHeight: CGFloat = 0

    @State private var expandedTodoID: Todo.ID?

    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var editKind: TodoKind = .task
    @State private var editScheduledFor: Date? = nil
    @State private var editDueAt: Date? = nil

    @State private var showSchedulePicker = false
    @State private var showDuePicker = false

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

            DraggableFAB {
                Task {
                    let sectionID = topSectionID.isEmpty ? "someday" : topSectionID
                    let scheduledFor = SectionMapper.date(from: sectionID)
                    let insertBeforeOrder = store.sections
                        .first(where: { $0.id == sectionID })?.items.first?.order
                    if let todo = await store.add(
                        title: "New",
                        scheduledFor: scheduledFor,
                        insertBeforeOrder: insertBeforeOrder
                    ) {
                        editTitle = todo.title
                        editNotes = todo.notes
                        editKind = todo.kind
                        editScheduledFor = todo.scheduledFor
                        editDueAt = todo.dueAt
                        expandedTodoID = todo.id
                    }
                }
            }
            .frame(width: 56, height: 56)
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
        .onChange(of: expandedTodoID) { oldID, newID in
            showSchedulePicker = false
            showDuePicker = false

            if let oldID {
                let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Task { await store.update(oldID, title: trimmed, notes: editNotes, kind: editKind, scheduledFor: editScheduledFor, dueAt: editDueAt) }
                }
            }
            if let newID, let todo = store.items.first(where: { $0.id == newID }) {
                editTitle = todo.title
                editNotes = todo.notes
                editKind = todo.kind
                editScheduledFor = todo.scheduledFor
                editDueAt = todo.dueAt
            }
        }
        .onReceive(keyboardPublisher) { height in
            keyboardHeight = height
        }
        // --- Date picker sheets ---
        .sheet(isPresented: $showSchedulePicker) {
            DatePickerSheet(
                title: "Set Date",
                tint: .blue,
                selection: Binding(
                    get: { editScheduledFor ?? Date() },
                    set: { editScheduledFor = $0 }
                ),
                onClear: { editScheduledFor = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDuePicker) {
            DatePickerSheet(
                title: "Due Date",
                tint: .red,
                selection: Binding(
                    get: { editDueAt ?? Date() },
                    set: { editDueAt = $0 }
                ),
                onClear: { editDueAt = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
                expandedTodoID: expandedTodoID,
                keyboardHeight: keyboardHeight,
                onCenteredSectionChange: { id in
                    DispatchQueue.main.async {
                        guard expandedTodoID == nil else { return }
                        currentSectionID = id
                        currentSectionTitle = store.sections.first(where: { $0.id == id })?.title ?? id
                    }
                },
                onTopSectionChange: { id in
                    DispatchQueue.main.async { topSectionID = id }
                },
                onSelect: { _ in },
                onDelete: { id in Task { await store.delete(id) } },
                onMove: { id, afterID, beforeID, sectionID in
                    Task { await store.reorder(id: id, afterID: afterID, beforeID: beforeID, inSectionID: sectionID) }
                },
                onBackgroundTap: {
                    expandedTodoID = nil
                },
                onNewItemDrop: { sectionID, afterID, beforeID in
                    let scheduledFor = SectionMapper.date(from: sectionID)
                    let afterOrder = store.items.first(where: { $0.id == afterID })?.order
                    let beforeOrder = store.items.first(where: { $0.id == beforeID })?.order
                    Task {
                        if let todo = await store.add(
                            title: "New",
                            scheduledFor: scheduledFor,
                            insertAfterOrder: afterOrder,
                            insertBeforeOrder: beforeOrder
                        ) {
                            editTitle = todo.title
                            editNotes = todo.notes
                            editKind = todo.kind
                            editScheduledFor = todo.scheduledFor
                            editDueAt = todo.dueAt
                            expandedTodoID = todo.id
                        }
                    }
                },
                detailView: { _ in
                    AnyView(TodoDetailView(
                        editNotes: $editNotes,
                        editKind: $editKind,
                        editScheduledFor: $editScheduledFor,
                        editDueAt: $editDueAt,
                        showSchedulePicker: $showSchedulePicker,
                        showDuePicker: $showDuePicker
                    ))
                },
                rowView: { todo in
                    TodoItemView(
                        todo: todo,
                        isExpanded: expandedTodoID == todo.id,
                        editTitle: $editTitle,
                        onToggle: { Task { await store.toggle(todo.id, to: !todo.isDone) } },
                        onTap: {
                            guard expandedTodoID == nil else {
                                expandedTodoID = nil
                                return
                            }
                            editTitle = todo.title
                            editNotes = todo.notes
                            editKind = todo.kind
                            editScheduledFor = todo.scheduledFor
                            editDueAt = todo.dueAt
                            expandedTodoID = todo.id
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
            CollapsingHeaderView(title: "Todo", collapse: $collapse)
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
        activeFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
    }

    // MARK: - Keyboard publisher

    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map(\.height),
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle").font(.system(size: 52)).foregroundStyle(.secondary)
            Text(emptyMessage).font(.headline).foregroundStyle(.secondary)
            Text("Tap + to add one.").font(.subheadline).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyMessage: String {
        switch activeFilter {
        case .all: return "No todos yet"
        case .pending: return "Nothing active"
        case .completed: return "Nothing completed"
        }
    }
}

// MARK: - Date picker sheet

private struct DatePickerSheet: View {
    let title: String
    let tint: Color
    @Binding var selection: Date
    var onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(tint)
                .padding(.horizontal)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationBackground(Color(.systemBackground))
    }
}

// MARK: - Detail cell

private struct TodoDetailView: View {
    @Binding var editNotes: String
    @Binding var editKind: TodoKind
    @Binding var editScheduledFor: Date?
    @Binding var editDueAt: Date?
    @Binding var showSchedulePicker: Bool
    @Binding var showDuePicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $editNotes)
                .frame(height: 72)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .overlay(alignment: .topLeading) {
                    if editNotes.isEmpty {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }

            Divider()
                .padding(.top, 8)

            HStack(spacing: 4) {
                Menu {
                    ForEach(TodoKind.allCases) { k in
                        Button { editKind = k } label: {
                            Label(k.rawValue.capitalized, systemImage: kindIcon(k))
                        }
                    }
                } label: {
                    KindBadge(kind: editKind)
                }

                Button {
                    showSchedulePicker = true
                } label: {
                    Label(
                        editScheduledFor?.formatted(date: .abbreviated, time: .omitted) ?? "Set date",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(editScheduledFor != nil ? .blue : .secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(editScheduledFor != nil ? Color.blue.opacity(0.12) : Color.clear, in: Capsule())
                }
                if editScheduledFor != nil {
                    Button { editScheduledFor = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button {
                    showDuePicker = true
                } label: {
                    Label(
                        editDueAt?.formatted(date: .abbreviated, time: .omitted) ?? "Due date",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(editDueAt != nil ? .red : .secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(editDueAt != nil ? Color.red.opacity(0.12) : Color.clear, in: Capsule())
                }
                if editDueAt != nil {
                    Button { editDueAt = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 10)
        }
        .padding(.leading, 44)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }

    private func kindIcon(_ k: TodoKind) -> String {
        switch k {
        case .task: return "checkmark.circle"
        case .reminder: return "bell"
        case .notes: return "document.circle"
        }
    }
}

private struct KindBadge: View {
    let kind: TodoKind
    var body: some View {
        Text(kind.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch kind {
        case .task: .gray
        case .reminder: .blue
        case .notes: .green
        }
    }
}

#Preview("TodoListScreen") {
    TodoListScreen()
        .environment(TodoStore.preview)
        .environment(SessionStore())
}
