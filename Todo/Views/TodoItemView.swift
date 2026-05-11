//
//  TodoItemView.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoItemView: View {
    let todo: Todo
    @Binding var expandedTodoID: Todo.ID?
    var onToggle: () -> Void = {}
    var onSave: (String, String, TodoKind, Date?, Date?) -> Void = { _, _, _, _, _ in }

    private var isExpanded: Bool { expandedTodoID == todo.id }

    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var editKind: TodoKind = .task
    @State private var editScheduledFor: Date? = nil
    @State private var editDueAt: Date? = nil
    @State private var showSchedulePicker = false
    @State private var showDuePicker = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // zIndex(1) ensures titleRow always renders ON TOP of the
                // extras below it. In a VStack, later children draw above
                // earlier ones — so without this, expandedExtras bleeds
                // over the title during animation.
                titleRow
                    .zIndex(1)

                VStack(spacing: 0) {
                    expandedExtras
                }
                .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
                .opacity(isExpanded ? 1 : 0)
                .animation(.easeIn(duration: 0.1), value: isExpanded)  // opacity fades fast
                .clipped()
                .allowsHitTesting(isExpanded)
                .zIndex(0)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)  // frame springs slower

                if !isExpanded {
                    collapsedExtras
                }
            }
            .padding(.bottom, 10)
            .padding(.trailing, 16)
            .padding(.leading, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if expandedTodoID != nil {
                    expandedTodoID = nil
                } else {
                    expandedTodoID = todo.id
                }
            }

            // Checkbox — absolutely positioned, never participates in layout
            Button(action: onToggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isDone ? .green : .secondary)
                    .frame(width: 44, height: 44, alignment: .top)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark incomplete" : "Mark complete")
        }
        .opacity(expandedTodoID == nil || expandedTodoID == todo.id ? 1.0 : 0.6)
        .blur(radius: expandedTodoID == nil || expandedTodoID == todo.id ? 0 : 0.7)
        .onChange(of: isExpanded) {
            if isExpanded {
                editTitle = todo.title
                editNotes = todo.notes
                editKind = todo.kind
                editScheduledFor = todo.scheduledFor
                editDueAt = todo.dueAt
                showSchedulePicker = false
                showDuePicker = false
            } else {
                let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSave(trimmed, editNotes, editKind, editScheduledFor, editDueAt)
                }
            }
        }
    }

    // MARK: - Title row
    // Opaque background ensures nothing animating behind it is visible.

    private var titleRow: some View {
        HStack(spacing: 8) {
            TextField("Title", text: isExpanded ? $editTitle : .constant(todo.title))
                .font(.body)
                .disabled(!isExpanded)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .strikethrough(!isExpanded && todo.isDone, color: .secondary)
                .foregroundStyle(!isExpanded && todo.isDone ? .secondary : .primary)

            Spacer(minLength: 8)

            KindBadge(kind: todo.kind)
                .opacity(isExpanded ? 0 : 1)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Collapsed extras

    private var collapsedExtras: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !todo.notes.isEmpty {
                Text(todo.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                if let scheduled = todo.scheduledFor {
                    Label(scheduled.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(isOverdue(scheduled) && !todo.isDone ? .red : .secondary)
                }
                if let due = todo.dueAt {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(isOverdue(due) && !todo.isDone ? .red : .secondary)
                }
            }
        }
    }

    // MARK: - Expanded extras

    private var expandedExtras: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $editNotes)
                .frame(minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .scrollDisabled(true)
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

            HStack(spacing: 12) {
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
                    showSchedulePicker.toggle()
                    showDuePicker = false
                } label: {
                    Label(
                        editScheduledFor?.formatted(date: .abbreviated, time: .omitted) ?? "Set date",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(editScheduledFor != nil ? .blue : .secondary)
                }
                if editScheduledFor != nil {
                    Button { editScheduledFor = nil; showSchedulePicker = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button {
                    showDuePicker.toggle()
                    showSchedulePicker = false
                } label: {
                    Label(
                        editDueAt?.formatted(date: .abbreviated, time: .omitted) ?? "Due date",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(editDueAt != nil ? .orange : .secondary)
                }
                if editDueAt != nil {
                    Button { editDueAt = nil; showDuePicker = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if showSchedulePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { editScheduledFor ?? Date() },
                        set: { editScheduledFor = $0; showSchedulePicker = false }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .transition(.opacity)
            }

            if showDuePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { editDueAt ?? Date() },
                        set: { editDueAt = $0; showDuePicker = false }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .transition(.opacity)
            }
        }
        .padding(.top, 6)
        .animation(.snappy, value: showSchedulePicker)
        .animation(.snappy, value: showDuePicker)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private func kindIcon(_ k: TodoKind) -> String {
        switch k {
        case .task:      return "checkmark.circle"
        case .reminder:  return "bell"
        case .checklist: return "list.bullet"
        }
    }
}

// MARK: - Kind badge

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
        case .task:      .blue
        case .reminder:  .orange
        case .checklist: .purple
        }
    }
}
