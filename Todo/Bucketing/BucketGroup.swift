//
//  BucketGroup.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

struct BucketGroup: Hashable {
    let id: BucketID
    var todos: [Todo]
}

struct Bucketizer {
    let policy: BucketPolicy
    init(policy: BucketPolicy) { self.policy = policy }

    func group(_ todos: [Todo]) -> [BucketGroup] {
        var dict: [BucketID: [Todo]] = [:]
        for t in todos { dict[policy.bucket(for: t), default: []].append(t) }

        return dict.keys.sorted(by: bucketOrder).map { key in
            var arr = dict[key] ?? []
            arr.sort {
                if $0.isDone != $1.isDone { return !$0.isDone }
                if $0.dueAt != $1.dueAt {
                    return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return BucketGroup(id: key, todos: arr)
        }
    }

    private func bucketOrder(_ a: BucketID, _ b: BucketID) -> Bool {
        switch (a, b) {
        case (.overdue, .overdue):       return false
        case (.overdue, _):              return true
        case (_, .overdue):              return false
        case (.someday, .someday):       return false
        case (.someday, _):              return false
        case (_, .someday):              return true
        case (.day(let da), .day(let db)): return da < db
        }
    }
}
