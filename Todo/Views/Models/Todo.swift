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
    var notes: String
    var isDone: Bool
    var kind: TodoKind
    var dueAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var ownerUid: String
    var order: String

    init(
        id: String,
        title: String,
        notes: String = "",
        isDone: Bool,
        kind: TodoKind,
        dueAt: Date?,
        createdAt: Date,
        updatedAt: Date,
        ownerUid: String,
        order: String = FractionalIndex.initial
    ) {
        self.id = id; self.title = title; self.notes = notes
        self.isDone = isDone; self.kind = kind; self.dueAt = dueAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.ownerUid = ownerUid; self.order = order
    }

    // Custom decoder: backward compat — old docs missing notes/order decode cleanly
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try  c.decode(String.self,   forKey: .id)
        title     = try  c.decode(String.self,   forKey: .title)
        notes     = (try? c.decode(String.self,  forKey: .notes))  ?? ""
        isDone    = try  c.decode(Bool.self,     forKey: .isDone)
        kind      = try  c.decode(TodoKind.self, forKey: .kind)
        dueAt     = try? c.decode(Date.self,     forKey: .dueAt)
        createdAt = try  c.decode(Date.self,     forKey: .createdAt)
        updatedAt = try  c.decode(Date.self,     forKey: .updatedAt)
        ownerUid  = try  c.decode(String.self,   forKey: .ownerUid)
        order     = (try? c.decode(String.self,  forKey: .order))  ?? FractionalIndex.initial
    }
}
