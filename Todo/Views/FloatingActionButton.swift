//
//  FloatingActionButton.swift
//  Todo
//
//  Created by Logan Camp on 1/14/26.
//

import SwiftUI

struct FloatingActionButton: View {
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: systemImage)
                .font(.title3.bold())   // Dynamic Type — no fixed point size
                .padding(18)
        }
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .shadow(radius: 8)
        .accessibilityLabel("Add")
    }
}

#Preview("FloatingActionButton") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        FloatingActionButton(systemImage: "plus") { }
    }
}
