//
//  TextInputRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct TextInputRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    var placeholder: String = "-"

    @Binding var text: String

    var keyboardType: UIKeyboardType = .default

    var isEnabled: Bool = true
    var maxWidth: CGFloat? = 120

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var selection: TextSelection?

    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            TextField(placeholder, text: $draft, selection: $selection)
                .focused($isFocused)
                .autoFloatingToolbar(
                    for: keyboardType,
                    text: $text,
                    draft: $draft,
                    selection: $selection
                )
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: maxWidth)
                .foregroundStyle(
                    isEnabled
                        ? Color(uiColor: .label)
                        : Color(uiColor: .secondaryLabel)
                )
                .disabled(!isEnabled)
                .numericKeyboardFilter(text: $draft, type: keyboardType)
        }
    }
}

#Preview {
    struct TextInputRow_Previews: View {
        @State private var activeText = "955"
        @State private var disabledText = "84"

        var body: some View {

            Card {
                RowGroup(.divider) {
                    TextInputRow(
                        icon: .customSymbol("flame.fill", tint: .orange),
                        title: "Calories",
                        titleExtension: "(kcal)",
                        text: $activeText,
                        isEnabled: true
                    )

                    TextInputRow(
                        icon: .customSymbol("bolt.fill", tint: .blue),
                        title: "Protein",
                        titleExtension: "(g)",
                        text: $disabledText,
                        isEnabled: false
                    )
                }
            }
        }
    }

    return TextInputRow_Previews()
}
