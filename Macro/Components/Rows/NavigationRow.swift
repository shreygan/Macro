//
//  NavigationRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//


import SwiftUI

struct NavigationRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            BaseRowLayout(
                icon: icon,
                title: title,
                titleExtension: titleExtension,
                subtitle: subtitle
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
            }
        }
        .buttonStyle(.plain) 
    }
}
