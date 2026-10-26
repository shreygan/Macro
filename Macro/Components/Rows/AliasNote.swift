//
//  AliasNote.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/25/26.
//

import SwiftUI

struct AliasNote: View {
    let alias: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text("Matches “\(alias)”")
                .lineLimit(1)
                .fixedSize()

            Text("Matches\n“\(alias)”")
                .lineLimit(2)
        }
        .font(.detail)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 120, alignment: .trailing)
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()

        Card {
            RowGroup(.divider) {
                BaseRowLayout(title: "Cola", subtitle: "Can · 12 fl oz") {
                    AliasNote(alias: "Coke")
                }
                BaseRowLayout(title: "Sports Drink", subtitle: "Bottle · 20 fl oz") {
                    AliasNote(alias: "Prime Hydration")
                }
            }
        }
        .padding()
    }
}
