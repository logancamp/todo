//
//  BucketClock.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

struct BucketClock {
    var now: () -> Date = { Date() }
    var cal: Calendar = {
        var c = Calendar.current
        c.timeZone = .current
        return c
    }()

    func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
    func normalizeDay(_ d: Date) -> Date { startOfDay(d) }
    func isPastDay(_ d: Date) -> Bool { startOfDay(d) < startOfDay(now()) }
}
