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

struct FilterChipIconStyle: ButtonStyle {
    static let diameter = FontSize.compactLineHeight + 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonIcon)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Color.controlFill)
            .foregroundStyle(Color.primary)
            .clipShape(Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == FilterChipIconStyle {
    static var filterChipIcon: FilterChipIconStyle { FilterChipIconStyle() }
}

extension View {
    func chipScrollFade(width: CGFloat = 16) -> some View {
        mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width)
            }
        }
    }
}
