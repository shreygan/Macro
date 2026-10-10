//
//  TagStyle.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftUI

enum TagVariant {
    case neutral
    case accent
}

struct TagStyle: ViewModifier {
    var variant: TagVariant

    func body(content: Content) -> some View {
        content
            .font(.tag)
            .foregroundStyle(
                variant == .accent ? Color.accentColor : Color.secondary
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                variant == .accent ? Color.accentFill : Color.controlFill,
                in: Capsule()
            )
    }
}

extension View {
    func tagStyle(_ variant: TagVariant = .neutral) -> some View {
        modifier(TagStyle(variant: variant))
    }
}
