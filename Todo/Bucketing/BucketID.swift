//
//  BucketID.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

public enum BucketID: Hashable {
    case overdue
    case day(Date)   // normalized to startOfDay
    case someday
}