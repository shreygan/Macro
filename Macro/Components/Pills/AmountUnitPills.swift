//
//  AmountUnitPills.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/23/26.
//

import SwiftUI

struct AmountUnitPills: View {
    @Environment(\.volumeUnit) private var volumeUnit

    @Binding var amount: String
    @Binding var unit: String
    var options: [String] = ["g", "ml"]
    var placeholder: Double? = nil
    var keepsAmountOnUnitChange = true

    @State private var fluidOuncesText: String?

    private static let milliliters = VolumeUnit.milliliters.rawValue
    private static let fluidOunces = VolumeUnit.fluidOunces.rawValue

    var body: some View {
        InputPill(
            text: Binding(get: { displayedAmount }, set: setDisplayedAmount),
            keyboardType: .decimalPad,
            placeholder: placeholderText
        )
        DropdownPill(
            options: displayedOptions,
            displayCustomOption: false,
            selection: Binding(get: { displayedUnit }, set: selectDisplayedUnit)
        )
    }

    private var showsFluidOunces: Bool {
        volumeUnit == .fluidOunces && unit == Self.milliliters
    }

    private var displayedOptions: [String] {
        guard volumeUnit == .fluidOunces else { return options }
        return options.map { $0 == Self.milliliters ? Self.fluidOunces : $0 }
    }

    private var displayedUnit: String {
        showsFluidOunces ? Self.fluidOunces : unit
    }

    private var displayedAmount: String {
        guard showsFluidOunces else { return amount }
        if let fluidOuncesText, Self.millilitersText(fromFluidOunces: fluidOuncesText) == amount {
            return fluidOuncesText
        }
        guard let milliliters = Self.number(amount) else { return amount }
        return VolumeUnit.fluidOunces.editableText(fromML: milliliters)
    }

    private var placeholderText: String {
        guard let placeholder, placeholder > 0 else { return "-" }
        return showsFluidOunces
            ? VolumeUnit.fluidOunces.editableText(fromML: placeholder)
            : EntryHelper.format(placeholder)
    }

    private func setDisplayedAmount(_ text: String) {
        guard showsFluidOunces else {
            amount = text
            return
        }
        fluidOuncesText = text
        amount = Self.millilitersText(fromFluidOunces: text) ?? text
    }

    private func selectDisplayedUnit(_ newUnit: String) {
        let storedUnit = newUnit == Self.fluidOunces ? Self.milliliters : newUnit
        guard storedUnit != unit else { return }
        if keepsAmountOnUnitChange {
            let text = displayedAmount
            if newUnit == Self.fluidOunces {
                fluidOuncesText = text
                amount = Self.millilitersText(fromFluidOunces: text) ?? text
            } else {
                fluidOuncesText = nil
                amount = text
            }
        } else {
            fluidOuncesText = nil
        }
        unit = storedUnit
    }

    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private static func millilitersText(fromFluidOunces text: String) -> String? {
        guard let value = number(text) else { return nil }
        return EntryHelper.format(VolumeUnit.fluidOunces.milliliters(from: value))
    }
}

#Preview {
    @Previewable @State var amount = "236.588"
    @Previewable @State var unit = "ml"

    Card {
        RowGroup(.divider) {
            BaseRowLayout(title: "Serving Weight") {
                AmountUnitPills(amount: $amount, unit: $unit)
            }
            BaseRowLayout(title: "Stored") {
                Text("\(amount) \(unit)")
            }
        }
    }
    .padding()
    .environment(\.volumeUnit, .fluidOunces)
}
