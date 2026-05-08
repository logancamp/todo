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

    private var isExpanded: Bool { expandedTodoID == todo.id }

    var body: some View {
        HStack(spacing: 0) {
            // Completion toggle — independent of expand
            Button(action: onToggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isDone ? .green : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark incomplete" : "Mark complete")

            // Row body — tap to expand
            Button {
                expandedTodoID = isExpanded ? nil : todo.id
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    TodoItemRow(todo: todo, isExpanded: isExpanded)
                    if isExpanded {
                        TodoItemDetail(todo: todo)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.snappy, value: isExpanded)
        }
    }
}

// MARK: - Sub-views (extracted so @Observable tracks them individually)

private struct TodoItemRow: View {
    let todo: Todo
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .strikethrough(todo.isDone, color: .secondary)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)

                if let due = todo.dueAt {
                    Label {
                        Text(due, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(isOverdue(due) && !todo.isDone ? .red : .secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                KindBadge(kind: todo.kind)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }
}

private struct TodoItemDetail: View {
    let todo: Todo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.top, 4)

            HStack {
                Label("Created", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(todo.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
        case .task:      .blue
        case .reminder:  .orange
        case .checklist: .purple
        }
    }
}

#Preview("TodoItemView") {
    struct Host: View {
        @State private var expanded: Todo.ID?
        private let pending = Todo(id: "1", title: "Write SwiftUI previews for all views",
            isDone: false, kind: .task, dueAt: Date().addingTimeInterval(-86_400),
            createdAt: Date().addingTimeInterval(-7_200), updatedAt: Date(), ownerUid: "p")
        private let done = Todo(id: "2", title: "Buy groceries",
            isDone: true, kind: .reminder, dueAt: nil,
            createdAt: Date().addingTimeInterval(-3_600), updatedAt: Date(), ownerUid: "p")

        var body: some View {
            VStack(spacing: 0) {
                TodoItemView(todo: pending, expandedTodoID: $expanded)
                Divider()
                TodoItemView(todo: done, expandedTodoID: $expanded)
            }
            .padding(.horizontal)
        }
    }
    return Host()
}

