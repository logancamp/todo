//
//  BucketClock.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

public struct BucketClock {
    public var now: () -> Date = { Date() }
    public var cal: Calendar = {
        var c = Calendar.current
        c.timeZone = .current
        return c
    }()

    public func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
    public func normalizeDay(_ d: Date) -> Date { startOfDay(d) }
    public func isPastDay(_ d: Date) -> Bool { startOfDay(d) < startOfDay(now()) }
}