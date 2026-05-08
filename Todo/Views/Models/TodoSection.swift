//
//  TodoSection.swift
//  Todo
//
//  Created by Logan Camp on 10/18/25.
//

import Foundation

struct TodoSection: Identifiable, Hashable {
    let id: String
    let title: String
    var items: [Todo]
}
