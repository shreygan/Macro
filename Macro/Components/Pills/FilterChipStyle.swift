//
//  FilterChipStyle.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftUI

struct FilterChipStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.compactValue)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.controlFill)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == FilterChipStyle {
    static func filterChip(isSelected: Bool) -> FilterChipStyle {
        FilterChipStyle(isSelected: isSelected)
    }
}
