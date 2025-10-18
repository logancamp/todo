//
//  BucketPolicy.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

public struct BucketPolicy {
    public let clock: BucketClock
    public init(clock: BucketClock) { self.clock = clock }

    public func bucket(for t: Todo) -> BucketID {
        guard let due = t.dueAt else { return .someday }
        return clock.isPastDay(due) ? .overdue : .day(clock.normalizeDay(due))
    }

    public func title(for b: BucketID) -> String {
        switch b {
        case .overdue: return "Overdue"
        case .someday: return "Someday"
        case .day(let d):
            let df = DateFormatter(); df.dateStyle = .full; df.timeStyle = .none
            return df.string(from: d)
        }
    }

    // Apply when user drags an item into a different section
    public func mutateOnMove(_ todo: inout Todo, to bucket: BucketID) {
        switch bucket {
        case .overdue: todo.dueAt = clock.startOfDay(clock.now())
        case .someday: todo.dueAt = nil
        case .day(let d): todo.dueAt = d
        }
        todo.updatedAt = Date()
    }
}