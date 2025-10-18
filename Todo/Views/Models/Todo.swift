//
//  Todo.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

public enum TodoFilter {
    case all
    case completed
    case pending
}

public enum TodoKind: String, Codable, CaseIterable, Identifiable {
    case task
    case reminder
    case checklist
    
    public var id: String { rawValue }
}

public struct Todo: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var title: String
    public var isDone: Bool
    public var kind: TodoKind
    public var dueAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var ownerUid: String
}
