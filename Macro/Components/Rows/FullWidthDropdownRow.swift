//
//  FullWidthDropdownRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/8/26.
//

import SwiftUI

struct FullWidthDropdownRow: View {
    var placeholder: String
    var options: [String]
    
    @Binding var selection: String
    
    var body: some View {
        HStack(spacing: 8) {
            
            TextField(placeholder, text: $selection)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
                    .frame(width: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    struct FullWidthDropdownPreview: View {
        @State private var foodSearch = ""
        @State private var mealType = ""

        var body: some View {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea()

                Card(title: "QUICK ADD") {

                    RowGroup(separator: .divider) {
                        FullWidthInputRow(
                            placeholder: "Search for food...",
                            text: $foodSearch
                        )

                        FullWidthDropdownRow(
                            placeholder: "Select Meal Time...",
                            options: ["Breakfast", "Lunch", "Dinner", "Snack"],
                            selection: $mealType
                        )
                    }

                }
                .padding()
            }
        }
    }

    return FullWidthDropdownPreview()
}
