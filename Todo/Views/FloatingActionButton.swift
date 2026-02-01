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
                .font(.system(size: 20, weight: .bold))
                .padding(18)
        }
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .shadow(radius: 8)
        .accessibilityLabel(Text("Add"))
    }
}

#Preview("FloatingActionButton – Light") {
    ZStack {
        Color.white
            .ignoresSafeArea()

        FloatingActionButton(systemImage: "plus") { }
    }
    .preferredColorScheme(.light)
}
