//
//  DropdownPillRow.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-10.
//

import SwiftUI

struct DropdownPillRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    
    var options: [String]
    @Binding var selection: String
    
    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            DropdownPill(
                options: options,
                selection: $selection,
            )
        }
    }
}

#Preview {
    struct DropdownPillPreviewWrapper: View {
        @State private var options = ["1 Cup", "1/2 Cup", "1 Tbsp", "100g"]
        @State private var selection = "1 Cup"
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea()
                
                Card("Portion") {
                    DropdownPillRow(
                        title: "Portion Size One",
                        options: options,
                        selection: $selection
                    )
                    
                    Divider().padding(.leading, 16)
                    
                    DropdownPillRow(
                        title: "Portion Size Two",
                        options: options,
                        selection: $selection
                    )
                }
                .padding()
            }
        }
    }
    return DropdownPillPreviewWrapper()
}
