//
//  CollapsingHeaderView.swift
//  Todo
//
//  Created by Logan Camp on 10/20/25.
//

import SwiftUI

struct CollapsingHeaderView: View {
    let title: String
    @Binding var collapse: CGFloat

    var body: some View {
        let c = clamped(collapse)
        let height = lerp(maxHeight, minHeight, t: c)
        let titleSize = lerp(maxTitleSize, minTitleSize, t: c)

        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(title.isEmpty ? "Todos" : title)
                    .font(.system(size: titleSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                // Optional placeholder action area for later
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: lerp(24, 18, t: c)))
                    .opacity(lerp(1.0, 0.7, t: c))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .opacity(lerp(0.0, 1.0, t: c))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .bottom)
        .background(.ultraThinMaterial)
        .animation(nil, value: collapse)
    }

    // MARK: - Tuning
    private let maxHeight: CGFloat = 120
    private let minHeight: CGFloat = 64
    private let maxTitleSize: CGFloat = 34
    private let minTitleSize: CGFloat = 20

    // MARK: - Helpers
    private func clamped(_ x: CGFloat) -> CGFloat {
        min(max(x, 0), 1)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

#Preview("CollapsingHeaderView") {
    struct PreviewHost: View {
        @State private var collapse: CGFloat = 0

        var body: some View {
            VStack(spacing: 0) {
                CollapsingHeaderView(title: "Today", collapse: $collapse)

                // Simple control to scrub collapse value
                Slider(value: $collapse, in: 0...1)
                    .padding()
            }
        }
    }

    return PreviewHost()
}
