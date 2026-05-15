//
//  KeyboardToolbarSystem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/14/26.
//

import SwiftUI

enum KeyboardAccessoryStyle {
    case doneButton
    //    case decimalPadActions
    //    case standardText
}

struct KeyboardAccessoryKey: FocusedValueKey {
    typealias Value = KeyboardAccessoryStyle
}

extension FocusedValues {
    /// The property that text fields will broadcast up the view hierarchy
    var activeKeyboardAccessory: KeyboardAccessoryStyle? {
        get { self[KeyboardAccessoryKey.self] }
        set { self[KeyboardAccessoryKey.self] = newValue }
    }
}

extension View {
    /// Attach this to the outermost container of any screen that has text inputs
    func withCustomKeyboardAccessories() -> some View {
        self.modifier(FloatingKeyboardModifier())
    }

    /// Automatically determines and broadcasts the correct floating toolbar based on the iOS keyboard type being used.
    func autoFloatingAccessory(for keyboardType: UIKeyboardType) -> some View {
        let requestedAccessory: KeyboardAccessoryStyle?

        switch keyboardType {
        case .numberPad:
            requestedAccessory = .doneButton
        case .decimalPad:
            requestedAccessory = .doneButton
        default:
            requestedAccessory = nil
        }

        return self.focusedValue(\.activeKeyboardAccessory, requestedAccessory)
    }
}

struct FloatingKeyboardModifier: ViewModifier {
    @State private var isSystemKeyboardVisible = false

    @FocusedValue(\.activeKeyboardAccessory) var activeAccessory

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {

            content

            if isSystemKeyboardVisible, let accessory = activeAccessory {
                accessoryView(for: accessory)
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
    private func accessoryView(for style: KeyboardAccessoryStyle) -> some View {
        HStack {
            Spacer()

            switch style {
            case .doneButton:
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
