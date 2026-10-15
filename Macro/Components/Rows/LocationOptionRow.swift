//
//  LocationOptionRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import SwiftUI

struct LocationOptionRow: View {
    var icon: String
    var iconTint: Color = .primary
    var title: String
    var subtitle: String? = nil
    var isSelected: Bool? = nil
    var reservesCheckmarkSpace: Bool = true
    var isLoading: Bool = false
    var showsChevron: Bool = false
    var thumbnail: RowThumbnail? = nil
    var action: () -> Void

    var body: some View {
        BaseRowLayout(
            icon: .customSymbol(icon, tint: iconTint),
            title: title,
            subtitle: subtitle?.collapsingWhitespace,
            thumbnail: thumbnail
        ) {
            if isLoading {
                ProgressView()
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.chevron)
                    .foregroundStyle(Color.tertiaryText)
                    .accessibilityHidden(true)
            } else if let isSelected, isSelected || reservesCheckmarkSpace {
                Image(systemName: "checkmark")
                    .font(.chevron)
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected == true ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { action() }
    }
}
