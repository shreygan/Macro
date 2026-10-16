//
//  PillBackground.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftUI

struct PillBackground: ViewModifier {
    var isEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            .font(.rowValue)
            .frame(height: FontSize.rowLineHeight)
            .padding(.horizontal, 10)
            .padding(.vertical, RowMetrics.pillVerticalPadding)
            .background(
                Capsule().fill(
                    isEnabled ? Color.controlFill : Color.clear
                )
            )
    }
}

extension View {
    func pillBackground(isEnabled: Bool = true) -> some View {
        modifier(PillBackground(isEnabled: isEnabled))
    }
}
