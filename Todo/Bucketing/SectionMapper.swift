//
//  SectionMapper.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//

import Foundation

public struct SectionMapper {
    public let policy: BucketPolicy
    public init(policy: BucketPolicy) { self.policy = policy }

    public func map(_ groups: [BucketGroup]) -> [TodoSection] {
        groups.map { g in
            TodoSection(
                id: sectionID(g.id),
                title: policy.title(for: g.id),
                items: g.todos
            )
        }
    }

    private func sectionID(_ b: BucketID) -> String {
        switch b {
        case .overdue: return "overdue"
        case .someday: return "someday"
        case .day(let d):
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            return "day:\(df.string(from: d))"
        }
    }
}
