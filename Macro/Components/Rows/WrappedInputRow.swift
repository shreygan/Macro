//
//  WrappedInputRow.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-11.
//

import SwiftUI

struct WrappedInputRow: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .focused($isFocused)
            .autoFloatingToolbar(for: keyboardType)
            .lineLimit(1...10)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .numericKeyboardFilter(text: $text, type: keyboardType)
    }
}
