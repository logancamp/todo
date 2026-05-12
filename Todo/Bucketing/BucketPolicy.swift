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

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()

    func bucket(for t: Todo) -> BucketID {
        guard let date = t.scheduledFor else { return .someday }
        return clock.isPastDay(date) ? .overdue : .day(clock.normalizeDay(date))
    }

    func title(for b: BucketID) -> String {
        switch b {
        case .overdue:    return "Overdue"
        case .someday:    return "Someday"
        case .day(let d): return BucketPolicy.dayFormatter.string(from: d)
        }
    }

    func mutateOnMove(_ todo: inout Todo, to bucket: BucketID) {
        switch bucket {
        case .overdue:
            // Set to yesterday so the item is genuinely past-due
            todo.scheduledFor = clock.startOfDay(clock.now().addingTimeInterval(-86400))
        case .someday:
            todo.scheduledFor = nil
        case .day(let d):
            todo.scheduledFor = d
        }
        todo.updatedAt = Date()
    }
}
