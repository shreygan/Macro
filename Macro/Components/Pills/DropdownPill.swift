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

    @Binding var selection: String

    @State private var isCustomMode: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isCustomMode && displayCustomOption {
                TextField("", text: $selection)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 10)
                    .focused($isFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.39)
                    .background(
                        Capsule().fill(Color(UIColor.tertiarySystemFill))
                    )
                    .onSubmit { validateAndRevert() }
                    .onChange(of: isFocused) { _, isNowFocused in
                        if !isNowFocused { validateAndRevert() }
                    }

            } else {
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            selection = option
                        }
                    }

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
                        Text(selection)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(UIColor.tertiarySystemFill))
                    )

                }
                .onAppear {
                    if selection.isEmpty, let first = options.first {
                        selection = first
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: isCustomMode)
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
            if let first = options.first {
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
                Color.gray.opacity(0.15).ignoresSafeArea()

                Card("PORTION") {
                    BaseRowLayout(
                        icon: .system("cup.and.saucer.fill", tint: .blue),
                        title: "Serving Size"
                    ) {
                        DropdownPill(
                            options: ["1 Cup", "1/2 Cup", "1 Tbsp", "100g"],
                            selection: $servingSize
                        )
                    }
                }
                .padding()
            }
        }
    }
    return DropdownPreviewWrapper()
}
