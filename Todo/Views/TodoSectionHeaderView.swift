//
//  TodoSectionHeaderView.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoSectionHeaderView: View {
    let section: TodoSection

    var body: some View {
        HStack {
            Text(titleText)
                .font(.headline)
            Spacer()
            Text("\(section.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var titleText: String {
        section.title.isEmpty
            ? String(describing: section.id)
            : section.title
    }
}

#Preview("TodoSectionHeaderView") {
    let sampleTodos = [
        Todo(
            id: "t1",
            title: "Buy groceries",
            isDone: false,
            kind: .task,
            dueAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            ownerUid: "preview-user"
        ),
        Todo(
            id: "t2",
            title: "Finish writeup",
            isDone: true,
            kind: .task,
            dueAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            ownerUid: "preview-user"
        )
    ]

    let section = TodoSection(
        id: "today",
        title: "Today",
        items: sampleTodos
    )

    return VStack(alignment: .leading, spacing: 0) {
        TodoSectionHeaderView(section: section)
            .padding(.horizontal)
    }
}
