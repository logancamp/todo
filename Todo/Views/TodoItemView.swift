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

    private var isExpanded: Bool {
        expandedTodoID == todo.id
    }

    var body: some View {
        Button {
            expandedTodoID = isExpanded ? nil : todo.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                collapsedRow

                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isExpanded)
    }

    // MARK: - Collapsed Row
    private var collapsedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if let due = todo.dueAt {
                    Text(due, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(todo.kind.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }

    // MARK: - Expanded Content
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let due = todo.dueAt {
                Label {
                    Text(due, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Future expansion:
            // notes, subtasks, tags, actions, etc.
        }
        .padding(.leading, 28)
    }
}

#Preview("TodoItemView") {
    struct PreviewHost: View {
        @State private var expanded: Todo.ID? = nil

        private let sample = Todo(
            id: UUID().uuidString,
            title: "Write SwiftUI previews",
            isDone: false,
            kind: .task,
            dueAt: Date().addingTimeInterval(60 * 60 * 24),
            createdAt: Date().addingTimeInterval(-60 * 60 * 2),
            updatedAt: Date().addingTimeInterval(-60 * 10),
            ownerUid: "preview-user"
        )

        var body: some View {
            VStack(spacing: 0) {
                TodoItemView(todo: sample, expandedTodoID: $expanded)
                    .padding()
            }
        }
    }

    return PreviewHost()
}
