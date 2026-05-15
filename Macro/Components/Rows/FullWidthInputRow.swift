//
//  FullWidthInputRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct FullWidthInputRow: View {
    var placeholder: String
    @Binding var text: String

    var keyboardType: UIKeyboardType = .default
    
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .autoFloatingToolbar(for: keyboardType)
            .frame(maxWidth: .infinity, alignment: .leading)
            .numericKeyboardFilter(text: $text, type: keyboardType)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        Card {

            FullWidthInputRow(
                placeholder: "Search for a food...",
                text: .constant("")
            )

            Divider().padding(.leading, 16)

            FullWidthInputRow(
                placeholder: "Quick add calories (kcal)",
                text: .constant(""),
                keyboardType: .numberPad
            )

            Divider().padding(.leading, 16)

            ToggleRow(
                icon: .system("star.fill", tint: .yellow),
                title: "Save to Favorites",
                isOn: .constant(false)
            )
        }
    }
}
