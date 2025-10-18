//
//  Validation.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

public struct ValidationError: LocalizedError, Equatable {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public struct TodoDraft { public var title: String; public var kind: TodoKind; public var dueAt: Date? }
public struct TodoPatch { public var title: String?; public var dueAt: Date??; public var isDone: Bool? }

public struct Validator {
    let cal: Calendar = { var c = Calendar.current; c.timeZone = .current; return c }()
    let now: () -> Date = { Date() }

    public func validateDraft(_ d: TodoDraft) throws {
        let t = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw ValidationError("Title can’t be empty.") }
        if let due = d.dueAt {
            let lo = cal.date(byAdding: .year, value: -5, to: now())!
            let hi = cal.date(byAdding: .year, value: +5, to: now())!
            guard (lo...hi).contains(due) else { throw ValidationError("Due date is out of range.") }
        }
    }

    public func validatePatch(_ p: TodoPatch) throws {
        if let t = p.title, t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("Title can’t be empty.")
        }
        // add dueAt range check if needed (same as above)
    }
}
