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
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = "-"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .autoFloatingToolbar(for: keyboardType)
                .font(.system(size: textFontSize))
                .multilineTextAlignment(.center)
                .frame(minWidth: 10)
                .fixedSize(horizontal: true, vertical: false)
                .numericKeyboardFilter(text: $text, type: keyboardType)

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
        @State private var bodyFat = "1"

        var body: some View {
            ZStack {
                Color.background.ignoresSafeArea()

                Card {
                    RowGroup(.divider) {
                        PillRow(
                            icon: .customSymbol("scalemass"),
                            title: "Current Weight",
                            text: $weight,
                            unit: "lbs"
                        )

                        PillRow(
                            icon: .customSymbol("percent"),
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
