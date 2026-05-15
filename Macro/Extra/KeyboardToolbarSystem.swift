//
//  KeyboardToolbarSystem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/14/26.
//

import SwiftUI

enum KeyboardToolbarStyle {
    case done
    //    case decimalPadActions
    //    case standardText
}

struct KeyboardToolbarKey: FocusedValueKey {
    typealias Value = KeyboardToolbarStyle
}

extension FocusedValues {
    /// The property that text fields will broadcast up the view hierarchy
    var activeKeyboardToolbar: KeyboardToolbarStyle? {
        get { self[KeyboardToolbarKey.self] }
        set { self[KeyboardToolbarKey.self] = newValue }
    }
}

extension View {
    /// Attach this to the outermost container of any screen that has text inputs
    func withCustomKeyboardToolbar() -> some View {
        self.modifier(FloatingKeyboardModifier())
    }

    /// Automatically determines and broadcasts the correct floating toolbar based on the iOS keyboard type being used.
    func autoFloatingToolbar(for keyboardType: UIKeyboardType) -> some View {
        let requestedToolbar: KeyboardToolbarStyle?

        switch keyboardType {
        case .numberPad:
            requestedToolbar = .done
        case .decimalPad:
            requestedToolbar = .done
        default:
            requestedToolbar = nil
        }

        return self.focusedValue(\.activeKeyboardToolbar, requestedToolbar)
    }
}

struct FloatingKeyboardModifier: ViewModifier {
    @State private var isSystemKeyboardVisible = false

    @FocusedValue(\.activeKeyboardToolbar) var activeToolbar

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {

            content

            if isSystemKeyboardVisible, let toolbar = activeToolbar {
                toolbarView(for: toolbar)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isSystemKeyboardVisible = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                isSystemKeyboardVisible = false
            }
        }
    }

    @ViewBuilder
    private func toolbarView(for style: KeyboardToolbarStyle) -> some View {
        HStack {
            Spacer()

            switch style {
            case .done:
                glassButton(icon: "checkmark", action: hideKeyboard)
            //            case .decimalPadActions:
            //                HStack(spacing: 12) {
            //                    glassButton(icon: "plus.forwardslash.minus") {
            //                        print("Toggle +/-")
            //                    }
            //                    glassButton(icon: "checkmark", action: hideKeyboard)
            //                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func glassButton(icon: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
