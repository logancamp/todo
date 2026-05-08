//
//  FractionalIndex.swift
//  Todo
//
//  Created by Logan Camp on 5/8/26.
//

import Foundation

enum FractionalIndex {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
    private static let n = 26

    /// Starting key for the first item in a new list.
    static let initial = "n"

    /// A key that sorts between `lo` and `hi`.
    /// Pass `nil` for an open (unbounded) end.
    static func between(_ lo: String?, _ hi: String?) -> String {
        compute(Array(lo ?? ""), Array(hi ?? ""))
    }

    private static func compute(_ lo: [Character], _ hi: [Character]) -> String {
        var result = ""
        let depth = max(lo.count, hi.count) + 1

        for i in 0..<depth {
            let a = i < lo.count ? (alphabet.firstIndex(of: lo[i]) ?? 0) : 0
            let b = i < hi.count ? (alphabet.firstIndex(of: hi[i]) ?? n) : n

            if b - a > 1 {
                // Room for a midpoint character at this position
                result.append(alphabet[(a + b) / 2])
                return result
            }

            if b - a == 1 {
                // Adjacent: take lo's char, recurse with remaining lo and open hi
                result.append(alphabet[a])
                let tail = i + 1 < lo.count ? Array(lo[(i + 1)...]) : []
                result += compute(tail, [])
                return result
            }

            // Same char: go one level deeper
            result.append(alphabet[a])
        }

        // Safety fallback — shouldn't occur with well-formed keys
        result.append("n")
        return result
    }
}
