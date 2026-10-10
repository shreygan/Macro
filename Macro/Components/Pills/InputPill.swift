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
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = "-"

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var selection: TextSelection?

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $draft, selection: $selection)
                .focused($isFocused)
                .autoFloatingToolbar(
                    for: keyboardType,
                    text: $text,
                    draft: $draft,
                    selection: $selection
                )
                .multilineTextAlignment(.center)
                .frame(minWidth: 10)
                .fixedSize(horizontal: true, vertical: false)
                .numericKeyboardFilter(text: $draft, type: keyboardType)

            if let unit = unit {
                Text(unit)
                    .foregroundColor(.tertiaryText)
            }
        }
        .pillBackground()
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
