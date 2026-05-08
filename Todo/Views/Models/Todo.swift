//
//  Todo.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

enum TodoFilter {
    case all, completed, pending
}

enum TodoKind: String, Codable, CaseIterable, Identifiable {
    case task, reminder, checklist
    var id: String { rawValue }
}

struct Todo: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var isDone: Bool
    var kind: TodoKind
    var dueAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var ownerUid: String
}
