//
//  DropdownPill.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/8/26.
//

import SwiftUI

struct DropdownPill: View {
    var options: [String]
    var displayCustomOption: Bool = true
    var isEnabled: Bool = true

    @Binding var selection: String

    @State private var isCustomMode: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isCustomMode && displayCustomOption && isEnabled {
                TextField("", text: $selection)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 10)
                    .focused($isFocused)
                    .autoFloatingToolbar(for: .default)
                    .pillBackground()
                    .onSubmit { validateAndRevert() }
                    .onChange(of: isFocused) { _, isNowFocused in
                        if !isNowFocused { validateAndRevert() }
                    }

            } else {
                Menu {
                    Picker("Options", selection: $selection) {
                        ForEach(options, id: \.self) { option in
                            Text(option.isEmpty ? "-" : option).tag(option)
                        }
                    }
                    .pickerStyle(.inline)

                    if displayCustomOption {
                        Divider()

                        Button {
                            switchToCustomMode()
                        } label: {
                            Label("Custom...", systemImage: "pencil")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selection.isEmpty ? "-" : selection)
                            .foregroundColor(
                                !isEnabled || selection.isEmpty
                                    ? .secondary : .primary
                            )

                        if isEnabled {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.dropdownChevron)
                                .foregroundColor(.tertiaryText)
                                .transition(
                                    .scale(scale: 0.8).combined(with: .opacity)
                                )
                        }
                    }
                    .pillBackground(isEnabled: isEnabled)
                }
                .disabled(!isEnabled)
                .id(selection)
                .fixedSize()
                .onAppear {
                    if selection.isEmpty && !options.contains("") {
                        if let first = options.first {
                            selection = first
                        }
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: isCustomMode)
        .animation(.snappy(duration: 0.3), value: isEnabled)
        .onChange(of: isEnabled) { _, newValue in
            if !newValue && isCustomMode {
                validateAndRevert()
            }
        }
    }

    private func switchToCustomMode() {
        isCustomMode = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.selectAll(_:)),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
    }

    private func validateAndRevert() {
        if selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if options.contains("") {
                selection = ""
            } else if let first = options.first {
                selection = first
            }
            isCustomMode = false
        }
    }
}

#Preview {
    struct DropdownPreviewWrapper: View {
        @State private var servingSize = "1 Cup"

        var body: some View {
            ZStack {
                Color.background.ignoresSafeArea()

                Card("PORTION") {
                    BaseRowLayout(
                        icon: .customSymbol("cup.and.saucer.fill", tint: .blue),
                        title: "Serving Size"
                    ) {
                        DropdownPill(
                            options: [
                                "1 Cup", "1/2 Cup", "1 Tbsp", "100g",
                                "Really Long Option",
                            ],
                            isEnabled: true,
                            selection: $servingSize,
                        )
                    }

                    BaseRowLayout(
                        icon: .customSymbol("cup.and.saucer.fill", tint: .blue),
                        title: "Serving Size"
                    ) {
                        DropdownPill(
                            options: [
                                "1 Cup", "1/2 Cup", "1 Tbsp", "100g",
                                "Really Long Option",
                            ],
                            isEnabled: false,
                            selection: $servingSize,
                        )
                    }
                    
                    TextInputRow(
                        icon: .customSymbol("flame.fill", tint: .orange),
                        title: "Calories",
                        titleExtension: "(kcal)",
                        text: .constant("test"),
                        isEnabled: false
                    )
                }
                .padding()
                
            }
        }
    }
    return DropdownPreviewWrapper()
}
