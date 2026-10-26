//
//  IngredientPortion.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/21/26.
//

import SwiftUI

protocol IngredientPortion {
    var quantity: String { get set }
    var unit: String { get set }
    var baseServingWeight: Double? { get }
    var baseServingWeightUnit: String { get }
    var servingUnitName: String { get }
    var fluidOuncesText: String? { get set }
    mutating func updateUnit(to newUnit: String)
}

extension IngredientPortion {
    func showsFluidOunces(in volumeUnit: VolumeUnit) -> Bool {
        volumeUnit == .fluidOunces && baseServingWeight != nil
            && baseServingWeightUnit == VolumeUnit.milliliters.rawValue
    }

    private func isShowingFluidOunces(in volumeUnit: VolumeUnit) -> Bool {
        showsFluidOunces(in: volumeUnit) && unit == baseServingWeightUnit
    }

    func unitOptions(in volumeUnit: VolumeUnit) -> [String] {
        guard baseServingWeight != nil else { return [servingUnitName] }
        let weightUnit = showsFluidOunces(in: volumeUnit) ? VolumeUnit.fluidOunces.rawValue : baseServingWeightUnit
        return [servingUnitName, weightUnit]
    }

    func displayedUnit(in volumeUnit: VolumeUnit) -> String {
        isShowingFluidOunces(in: volumeUnit) ? VolumeUnit.fluidOunces.rawValue : unit
    }

    mutating func selectDisplayedUnit(_ newUnit: String, in volumeUnit: VolumeUnit) {
        fluidOuncesText = nil
        updateUnit(to: newUnit == VolumeUnit.fluidOunces.rawValue ? baseServingWeightUnit : newUnit)
    }

    func displayedQuantity(in volumeUnit: VolumeUnit) -> String {
        guard isShowingFluidOunces(in: volumeUnit) else { return quantity }
        if let fluidOuncesText, Self.milliliters(fromFluidOunces: fluidOuncesText) == quantity {
            return fluidOuncesText
        }
        guard let milliliters = Double(quantity) else { return quantity }
        return VolumeUnit.fluidOunces.editableText(fromML: milliliters)
    }

    mutating func setDisplayedQuantity(_ text: String, in volumeUnit: VolumeUnit) {
        guard isShowingFluidOunces(in: volumeUnit) else {
            quantity = text
            return
        }
        fluidOuncesText = text
        quantity = Self.milliliters(fromFluidOunces: text) ?? text
    }

    private static func milliliters(fromFluidOunces text: String) -> String? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return EntryHelper.format(VolumeUnit.fluidOunces.milliliters(from: value))
    }
}

extension Binding where Value: IngredientPortion {
    func displayedQuantity(in volumeUnit: VolumeUnit) -> Binding<String> {
        Binding<String>(
            get: { wrappedValue.displayedQuantity(in: volumeUnit) },
            set: { wrappedValue.setDisplayedQuantity($0, in: volumeUnit) }
        )
    }

    func displayedUnit(in volumeUnit: VolumeUnit) -> Binding<String> {
        Binding<String>(
            get: { wrappedValue.displayedUnit(in: volumeUnit) },
            set: { wrappedValue.selectDisplayedUnit($0, in: volumeUnit) }
        )
    }
}
