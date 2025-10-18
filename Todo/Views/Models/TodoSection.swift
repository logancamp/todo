//
//  TodoSection.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//


public struct TodoSection: Hashable {
    public let id: String
    public let title: String
    public var items: [Todo]
}
