//
//  FullWidthInputRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct FullWidthInputRow<Trailing: View>: View {
    var placeholder: String
    @Binding var text: String

    var keyboardType: UIKeyboardType = .default
    var focusOnAppear = false
    var selectRequest = 0
    var cursorToEndRequest = 0
    var onFocusChange: ((Bool) -> Void)?
    var trailing: Trailing

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var selection: TextSelection?
    @State private var selectsWhenFocused = false

    init(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        focusOnAppear: Bool = false,
        selectRequest: Int = 0,
        cursorToEndRequest: Int = 0,
        onFocusChange: ((Bool) -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.focusOnAppear = focusOnAppear
        self.selectRequest = selectRequest
        self.cursorToEndRequest = cursorToEndRequest
        self.onFocusChange = onFocusChange
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $draft, selection: $selection)
                .focused($isFocused)
                .autoFloatingToolbar(
                    for: keyboardType,
                    text: $text,
                    draft: $draft,
                    selection: $selection
                )
                .frame(maxWidth: .infinity, minHeight: RowMetrics.controlHeight, alignment: .leading)
                .numericKeyboardFilter(text: $draft, type: keyboardType)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, RowMetrics.verticalPadding)
        .onAppear {
            if focusOnAppear {
                selectAllWhenFocused()
            }
        }
        .onChange(of: selectRequest) {
            selectAllWhenFocused()
        }
        .onChange(of: cursorToEndRequest) {
            Task { @MainActor in
                selection = TextSelection(insertionPoint: draft.endIndex)
            }
        }
        .onChange(of: isFocused) { _, focused in
            onFocusChange?(focused)
            if focused { selectAllIfRequested() }
        }
    }

    private func selectAllWhenFocused() {
        selectsWhenFocused = true
        if isFocused {
            selectAllIfRequested()
        } else {
            isFocused = true
        }
    }

    private func selectAllIfRequested() {
        guard selectsWhenFocused else { return }
        selectsWhenFocused = false
        Task { @MainActor in
            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
        }
    }
}

extension FullWidthInputRow where Trailing == EmptyView {
    init(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        focusOnAppear: Bool = false,
        selectRequest: Int = 0,
        cursorToEndRequest: Int = 0,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.init(
            placeholder: placeholder,
            text: text,
            keyboardType: keyboardType,
            focusOnAppear: focusOnAppear,
            selectRequest: selectRequest,
            cursorToEndRequest: cursorToEndRequest,
            onFocusChange: onFocusChange
        ) {
            EmptyView()
        }
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()

        Card {

            FullWidthInputRow(
                placeholder: "Search for a food...",
                text: .constant("")
            )

            Divider().padding(.leading, 16)

            FullWidthInputRow(
                placeholder: "Quick add calories (kcal)",
                text: .constant(""),
                keyboardType: .numberPad
            )

            Divider().padding(.leading, 16)

            ToggleRow(
                icon: .customSymbol("star.fill", tint: .yellow),
                title: "Save to Favorites",
                isOn: .constant(false)
            )
        }
    }
}
