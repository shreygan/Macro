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
    
    var placeholder: String = "Enter..."
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var isEnabled: Bool = true
    
    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .frame(maxWidth: 120)
                .foregroundStyle(isEnabled ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel))
                .opacity(isEnabled ? 1.0 : 0.7)
                .disabled(!isEnabled)
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
                        icon: .system("flame.fill", tint: .orange),
                        title: "Calories",
                        titleExtension: "(kcal)",
                        text: $activeText,
                        isEnabled: true
                    )
                                
                    TextInputRow(
                        icon: .system("bolt.fill", tint: .blue),
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
