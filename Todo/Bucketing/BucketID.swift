//
//  BucketID.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


import Foundation

enum BucketID: Hashable {
    case overdue
    case day(Date)   // always normalized to startOfDay
    case someday
}
