//
//  BucketPolicy.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

struct BucketPolicy {
    let clock: BucketClock
    init(clock: BucketClock) { self.clock = clock }

    // Static formatter — allocated once, not on every call
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()

    func bucket(for t: Todo) -> BucketID {
        guard let due = t.dueAt else { return .someday }
        return clock.isPastDay(due) ? .overdue : .day(clock.normalizeDay(due))
    }

    func title(for b: BucketID) -> String {
        switch b {
        case .overdue:      return "Overdue"
        case .someday:      return "Someday"
        case .day(let d):   return BucketPolicy.dayFormatter.string(from: d)
        }
    }

    func mutateOnMove(_ todo: inout Todo, to bucket: BucketID) {
        switch bucket {
        case .overdue:      todo.dueAt = clock.startOfDay(clock.now())
        case .someday:      todo.dueAt = nil
        case .day(let d):   todo.dueAt = d
        }
        todo.updatedAt = Date()
    }
}
