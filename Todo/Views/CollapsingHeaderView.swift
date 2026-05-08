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

    @ScaledMetric private var maxTitleSize: CGFloat = 34
    @ScaledMetric private var minTitleSize: CGFloat = 20

    var body: some View {
        let c = min(max(collapse, 0), 1)
        let height = lerp(TodoLayout.headerMaxHeight, TodoLayout.headerMinHeight, t: c)
        let titleSize = lerp(maxTitleSize, minTitleSize, t: c)

        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(title.isEmpty ? "Todos" : title)
                    .font(.system(size: titleSize).bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.trailing, 52)  // reserve space for menu button overlay

                Spacer()
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

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

#Preview("CollapsingHeaderView") {
    struct Host: View {
        @State private var collapse: CGFloat = 0
        var body: some View {
            VStack(spacing: 0) {
                CollapsingHeaderView(title: "Today", collapse: $collapse)
                Slider(value: $collapse, in: 0...1).padding()
            }
        }
    }
    return Host()
}
