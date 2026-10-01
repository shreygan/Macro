//
//  MultiDropdownPill.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftUI

struct MultiDropdownPill: View {
    var options: [String]
    var allLabel: String
    var isEnabled: Bool = true
    var maxLabelLength: Int = 24

    @Binding var selection: Set<String>

    private var label: String {
        label(for: options.filter(selection.contains))
    }

    private var possibleLabels: [String] {
        var labels: Set<String> = [allLabel]
        for (index, first) in options.enumerated() {
            labels.insert(label(for: [first]))
            for second in options.dropFirst(index + 1) {
                labels.insert(label(for: [first, second]))
            }
        }
        if options.count > 3 {
            labels.insert(label(for: Array(options.dropLast())))
        }
        return labels.sorted()
    }

    private func label(for selected: [String]) -> String {
        guard !selected.isEmpty else { return allLabel }
        let joined = selected.joined(separator: ", ")
        if selected.count <= 2 && joined.count <= maxLabelLength {
            return joined
        }
        return "\(selected.count) Selected"
    }

    var body: some View {
        Menu {
            Toggle(
                allLabel,
                isOn: Binding(
                    get: { selection.isEmpty },
                    set: { if $0 { selection = [] } }
                )
            )

            Divider()

            ForEach(options, id: \.self) { option in
                Toggle(
                    option,
                    isOn: Binding(
                        get: { selection.contains(option) },
                        set: { toggle(option, isOn: $0) }
                    )
                )
            }
        } label: {
            ZStack(alignment: .trailing) {
                ForEach(possibleLabels, id: \.self) { text in
                    pill(text).hidden()
                }

                pill(label)
            }
        }
        .menuActionDismissBehavior(.disabled)
        .disabled(!isEnabled)
        .fixedSize()
        .animation(.snappy(duration: 0.3), value: selection)
        .animation(.snappy(duration: 0.3), value: isEnabled)
        .onChange(of: options) { _, newOptions in
            selection.formIntersection(newOptions)
        }
    }

    private func pill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .contentTransition(.interpolate)

            if isEnabled {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tertiary)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(
                isEnabled ? Color(UIColor.tertiarySystemFill) : Color.clear
            )
        )
    }

    private func toggle(_ option: String, isOn: Bool) {
        if isOn {
            selection.insert(option)
        } else {
            selection.remove(option)
        }

        if selection.count == options.count {
            selection = []
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<String> = []

    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        Card("Library Entries") {
            BaseRowLayout(
                icon: .customSymbol("line.3.horizontal.decrease"),
                title: "Include"
            ) {
                MultiDropdownPill(
                    options: ["Favorites", "Foods", "Recipes", "Ingredients"],
                    allLabel: "All Entries",
                    selection: $selection
                )
            }
        }
        .padding()
    }
}
