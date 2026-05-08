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

    // Allocated once — not on every call
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
        case .overdue:    return "overdue"
        case .someday:    return "someday"
        case .day(let d): return "day:\(SectionMapper.idFormatter.string(from: d))"
        }
    }

    // MARK: - Decoding helpers (used by TodoStore for drag/drop)

    /// The date embedded in a day-section ID, or nil for overdue/someday.
    static func date(from sectionID: String) -> Date? {
        guard sectionID.hasPrefix("day:") else { return nil }
        return idFormatter.date(from: String(sectionID.dropFirst(4)))
    }

    /// Reverse-map a section ID back to a BucketID for cross-section drag moves.
    static func bucket(from sectionID: String, clock: BucketClock) -> BucketID? {
        switch sectionID {
        case "overdue": return .overdue
        case "someday": return .someday
        default:
            guard let d = date(from: sectionID) else { return nil }
            return .day(clock.normalizeDay(d))
        }
    }
}

