//
//  PortionPillRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 8/6/26.
//

import SwiftUI

// TODO: make this a generic double input pill row not just for Portion

struct PortionPillRow: View {
    var title: String = "Portion"
    var isEnabled: Bool = true

    @Binding var quantity: String
    @Binding var unit: String

    var availableUnits: [String]
    var servingUnits: [ServingSizeUnit]

    private var formattedPortion: String {
        let q =
            quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "0" : quantity
        let matchedUnit = servingUnits.first(where: { $0.unit == unit })
        let displayUnit = matchedUnit?.displayString(for: q) ?? unit

        return "\(q) \(displayUnit)"
    }

    var body: some View {
        BaseRowLayout(title: title) {
            HStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .trailing) {
                    HStack(spacing: 8) {
                        InputPill(
                            text: $quantity,
                            keyboardType: .decimalPad
                        )

                        DropdownPill(
                            options: availableUnits,
                            displayCustomOption: false,
                            isEnabled: isEnabled,
                            selection: $unit
                        )
                    }
                    .opacity(isEnabled ? 1.0 : 0.0)
                    .allowsHitTesting(isEnabled)
                    .accessibilityHidden(!isEnabled)

                    Text(formattedPortion)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                        .opacity(isEnabled ? 0.0 : 1.0)
                        .accessibilityHidden(isEnabled)
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: isEnabled)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isEditing: Bool = false
        @State private var quantity: String = "1.5"
        @State private var unit: String = "serving"

        let mockServingUnits = [
            ServingSizeUnit(
                unit: "serving",
                pluralVariant: "servings",
                displayOrder: 1
            ),
            ServingSizeUnit(
                unit: "slice",
                pluralVariant: "slices",
                displayOrder: 2
            ),
        ]

        var body: some View {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack {
                        PortionPillRow(
                            title: "Portion",
                            isEnabled: isEditing,
                            quantity: $quantity,
                            unit: $unit,
                            availableUnits: ["serving", "g", "ml", "slice"],
                            servingUnits: mockServingUnits
                        )
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Button {
                        isEditing.toggle()
                    } label: {
                        Text(
                            isEditing
                                ? "Switch to Read-Only" : "Switch to Edit Mode"
                        )
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    return PreviewWrapper()
}
