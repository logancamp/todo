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

    static let initial = "n"

    static func between(_ lo: String?, _ hi: String?) -> String {
        // Identical bounds — no valid midpoint exists. Append 'a' (lowest char)
        // so the result sorts immediately after lo rather than far away.
        if let lo, let hi, lo == hi { return lo + "a" }
        return compute(Array(lo ?? ""), Array(hi ?? ""))
    }

    private static func compute(_ lo: [Character], _ hi: [Character]) -> String {
        var result = ""
        let depth = max(lo.count, hi.count) + 1

        for i in 0..<depth {
            let a = i < lo.count ? (alphabet.firstIndex(of: lo[i]) ?? 0) : 0
            let b = i < hi.count ? (alphabet.firstIndex(of: hi[i]) ?? n) : n

            if b - a > 1 {
                result.append(alphabet[(a + b) / 2])
                return result
            }
            if b - a == 1 {
                result.append(alphabet[a])
                let tail = i + 1 < lo.count ? Array(lo[(i + 1)...]) : []
                result += compute(tail, [])
                return result
            }
            result.append(alphabet[a])
        }

        // Fallback: use 'a' (not 'n') so result sorts near duplicates, not at end
        result.append("a")
        return result
    }
}
