//
//  SectionMapper.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//

import Foundation

struct SectionMapper {
    let policy: BucketPolicy
    init(policy: BucketPolicy) { self.policy = policy }

    // Static formatter — allocated once
    private static let idFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    func map(_ groups: [BucketGroup]) -> [TodoSection] {
        groups.map { g in
            TodoSection(id: sectionID(g.id), title: policy.title(for: g.id), items: g.todos)
        }
    }

    private func sectionID(_ b: BucketID) -> String {
        switch b {
        case .overdue:      return "overdue"
        case .someday:      return "someday"
        case .day(let d):   return "day:\(SectionMapper.idFormatter.string(from: d))"
        }
    }
}
