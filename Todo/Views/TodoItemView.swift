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

    // Local edit state — initialised from todo when expanded
    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var editKind: TodoKind = .task
    @State private var editScheduledFor: Date? = nil
    @State private var editDueAt: Date? = nil
    @State private var showSchedulePicker = false
    @State private var showDuePicker = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Content — expands and contracts, leading space reserved for checkbox
            Group {
                if isExpanded {
                    editBody
                } else {
                    collapsedBody
                }
            }
            .padding(.leading, 44)

            // Checkbox — absolutely positioned at top-left, never participates
            // in layout so UIKit's cell resize animation cannot move it
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
        .contentShape(Rectangle())
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

    // MARK: - Collapsed (read-only)

    private var collapsedBody: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .strikethrough(todo.isDone, color: .secondary)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)

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

            Spacer(minLength: 8)
            KindBadge(kind: todo.kind)
        }
        .padding(.bottom, 10)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandedTodoID == nil else {
                expandedTodoID = nil
                return
            }
            expandedTodoID = todo.id
        }
    }

    // MARK: - Expanded (edit mode)

    private var editBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            TextField("Title", text: $editTitle)
                .font(.body)

            // Notes — grows with content
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

            // Toolbar: kind, schedule date, due date
            HStack(spacing: 12) {
                // Kind
                Menu {
                    ForEach(TodoKind.allCases) { k in
                        Button { editKind = k } label: {
                            Label(k.rawValue.capitalized, systemImage: kindIcon(k))
                        }
                    }
                } label: {
                    KindBadge(kind: editKind)
                }

                // Schedule date (section placement)
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

                // Due date (deadline label)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Shared sub-views

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
