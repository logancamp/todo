//
//  TodoListScreen.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct TodoListScreen: View {
    @ObservedObject var store: TodoStore
    @State private var collapse: CGFloat = 0
    @State private var currentSection: String = ""

    var body: some View {
        ZStack(alignment: .top) {
            TodoScrollHost(
                sections: store.sections,
                collapse: $collapse,
                onCenteredSectionChange: { currentSection = $0 },
                onSelect: { id in print("selected", id) },
                rowView: { todo in AnyView(TodoItemView(todo: todo)) },
                headerView: { section in AnyView(TodoSectionHeaderView(section: section)) }
            )

            CollapsingHeaderView(title: currentSection, collapse: $collapse)
        }
    }
}
