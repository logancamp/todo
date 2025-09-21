//
//  Todo.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

enum TodoFilter {
    case all
    case completed
    case pending
}

enum TodoKind: String, Codable, CaseIterable, Identifiable {
    case task
    case reminder
    case checklist
    
    var id: String { rawValue }
}

struct Todo: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var isDone: Bool
    var kind: TodoKind
    var dueAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var ownerUid: String
}
