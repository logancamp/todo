//
//  Validation.swift
//  Todo
//
//  Created by Logan Camp on 9/15/25.
//

import Foundation

struct ValidationError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

struct TodoDraft { var title: String; var kind: TodoKind; var dueAt: Date? }
struct TodoPatch  { var title: String?; var dueAt: Date??; var isDone: Bool? }

struct Validator {
    var cal: Calendar
    var now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = { Date() }) {
        self.cal = calendar
        self.now = now
    }

    func validateDraft(_ d: TodoDraft) throws {
        let t = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw ValidationError("Title can't be empty.") }
        guard t.count <= 500 else { throw ValidationError("Title must be 500 characters or fewer.") }
        if let due = d.dueAt {
            let lo = cal.date(byAdding: .year, value: -5, to: now())!
            let hi = cal.date(byAdding: .year, value: +5, to: now())!
            guard (lo...hi).contains(due) else { throw ValidationError("Due date is out of range.") }
        }
    }

    func validatePatch(_ p: TodoPatch) throws {
        if let t = p.title {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError("Title can't be empty.") }
            guard trimmed.count <= 500 else { throw ValidationError("Title must be 500 characters or fewer.") }
        }
    }
}
