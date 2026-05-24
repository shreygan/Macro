//
//  NumericFilterModifier.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/11/26.
//

import SwiftUI

struct NumericFilterModifier: ViewModifier {
    @Binding var text: String
    var keyboardType: UIKeyboardType

    func body(content: Content) -> some View {
        content
            .keyboardType(keyboardType)
            .onChange(of: text) { oldValue, newValue in
                filterNumericInput(newValue: newValue)
            }
    }

    private func filterNumericInput(newValue: String) {
        if keyboardType == .decimalPad {
            var filtered = newValue.filter { "0123456789.".contains($0) }

            let parts = filtered.components(separatedBy: ".")
            if parts.count > 2 {
                filtered = parts[0] + "." + parts.dropFirst().joined()
            }

            if text != filtered { text = filtered }

        } else if keyboardType == .numberPad {
            let filtered = newValue.filter { "0123456789".contains($0) }
            if text != filtered { text = filtered }
        }
    }
}

extension View {
    /// Applies a keyboard type and actively filters out invalid characters (like letters or multiple decimals).
    func numericKeyboardFilter(text: Binding<String>, type: UIKeyboardType)
        -> some View
    {
        self.modifier(NumericFilterModifier(text: text, keyboardType: type))
    }
}
