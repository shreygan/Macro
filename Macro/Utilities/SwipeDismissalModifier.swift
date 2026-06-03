//
//  SwipeDismissalModifier.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftUI

struct SwipeDismissalModifier: ViewModifier {
    @State private var focusManager = SwipeFocusManager()

    func body(content: Content) -> some View {
        content
            .environment(focusManager)
            .onTapGesture {
                focusManager.activeRowID = nil
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let isVerticalScroll =
                            abs(value.translation.height)
                            > abs(value.translation.width)
                        if isVerticalScroll && focusManager.activeRowID != nil {
                            focusManager.activeRowID = nil
                        }
                    }
            )
    }
}

extension View {
    func withGlobalSwipeDismissal() -> some View {
        self.modifier(SwipeDismissalModifier())
    }
}
