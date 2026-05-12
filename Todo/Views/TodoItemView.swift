//
//  TodoItemView.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoItemView: View {
    let todo: Todo
    let isExpanded: Bool
    var editTitle: Binding<String> = .constant("")
    var onToggle: () -> Void = {}
    var onTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onToggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isDone ? .green : .secondary)
                    .frame(width: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    TextField("Title", text: isExpanded ? editTitle : .constant(todo.title))
                        .font(.body)
                        .disabled(!isExpanded)
                        .lineLimit(isExpanded ? nil : 2)
                        .strikethrough(todo.isDone, color: .secondary)
                        .foregroundStyle(todo.isDone ? .secondary : .primary)

                    Spacer(minLength: 8)

                    KindBadge(kind: todo.kind)
                        .opacity(isExpanded ? 0 : 1)
                }

                if !isExpanded {
                    collapsedExtras
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, isExpanded ? 0 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

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

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
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
        case .task:      .blue
        case .reminder:  .orange
        case .checklist: .purple
        }
    }
}
