//
//  PillRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct PillRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    
    @Binding var text: String
    var unit: String? = nil
    
    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle
        ) {
            // Drop the pill into the right-hand slot!
            InputPill(text: $text, unit: unit)
        }
    }
}

#Preview {
    struct PillPreviewWrapper: View {
        @State private var weight = "175"
        @State private var bodyFat = "15"
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea()
                
                Card(title: "BODY METRICS") {
                    PillRow(
                        icon: .system("scalemass"),
                        title: "Current Weight",
                        text: $weight,
                        unit: "lbs"
                    )
                    
                    Divider().padding(.leading, 16)
                    
                    PillRow(
                        icon: .system("percent"),
                        title: "Body Fat",
                        text: $bodyFat,
                        unit: "%"
                    )
                }
                .padding()
            }
        }
    }
    return PillPreviewWrapper()
}
