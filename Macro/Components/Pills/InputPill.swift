//
//  InputPill.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct InputPill: View {
    @Binding var text: String
    var unit: String? = nil
    var textFontSize: CGFloat = 16
    var keyboardType: UIKeyboardType = .decimalPad

    var body: some View {
        HStack(spacing: 4) {
            TextField("0", text: $text)
                .font(.system(size: textFontSize))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)
                .keyboardType(keyboardType)

            if let unit = unit {
                Text(unit)
                    .font(.system(size: textFontSize))
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
}

#Preview {
    struct PillPreviewWrapper: View {
        @State private var weight = "175"
        @State private var bodyFat = "15"

        var body: some View {
            ZStack {
                Color.background.ignoresSafeArea()

                Card {
                    RowGroup(.divider) {
                        PillRow(
                            icon: .system("scalemass"),
                            title: "Current Weight",
                            text: $weight,
                            unit: "lbs"
                        )

                        PillRow(
                            icon: .system("percent"),
                            title: "Category",
                            text: $bodyFat
                        )
                    }
                }
                .padding()
            }
        }
    }
    return PillPreviewWrapper()
}
