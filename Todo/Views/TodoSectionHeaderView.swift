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
            Text(section.title.isEmpty ? section.id : section.title)
                .font(.headline)
            Spacer()
            Text("\(section.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)  // FIX: opaque background blocks cells scrolling behind
    }
}
