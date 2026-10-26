//
//  DrinkAmounts.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import Foundation
import SwiftData

struct DrinkAmounts: Equatable {
    static let ethanolDensity = 0.789
    static let alcoholKcalPerGram = 7.0

    static func alcoholCalories(volumeML: Double, abv: Double) -> Double {
        volumeML * abv / 100 * ethanolDensity * alcoholKcalPerGram
    }

    var volumeML: Double = 0
    var hydrationML: Double = 0
    var caffeineMg: Double = 0
    var alcoholGrams: Double = 0

    static let zero = DrinkAmounts()

    init(volumeML: Double = 0, hydrationML: Double = 0, caffeineMg: Double = 0, alcoholGrams: Double = 0) {
        self.volumeML = volumeML
        self.hydrationML = hydrationML
        self.caffeineMg = caffeineMg
        self.alcoholGrams = alcoholGrams
    }

    init(food: FoodItem, quantity: Double, unit: String) {
        guard ServingBase(food).measures(unit) else {
            self.init()
            return
        }
        let multiplier = EntryHelper.portionMultiplier(
            quantity: quantity,
            unit: unit,
            servingSize: food.servingSize,
            servingWeight: food.servingWeight,
            servingWeightUnit: food.servingWeightUnit
        )
        self.init(food: food, multiplier: multiplier ?? 0)
    }

    init(food: FoodItem, multiplier: Double) {
        guard food.type == .drink else { return }
        volumeML = (food.servingVolumeML ?? 0) * multiplier
        hydrationML = volumeML * food.hydrationPercent / 100
        caffeineMg = (food.caffeineMg ?? 0) * multiplier
        alcoholGrams = volumeML * (food.abv ?? 0) / 100 * Self.ethanolDensity
    }

    static func + (lhs: DrinkAmounts, rhs: DrinkAmounts) -> DrinkAmounts {
        DrinkAmounts(
            volumeML: lhs.volumeML + rhs.volumeML,
            hydrationML: lhs.hydrationML + rhs.hydrationML,
            caffeineMg: lhs.caffeineMg + rhs.caffeineMg,
            alcoholGrams: lhs.alcoholGrams + rhs.alcoholGrams
        )
    }

    func overriding(caffeineMg: Double?, abv: Double?) -> DrinkAmounts {
        var amounts = self
        if let caffeineMg {
            amounts.caffeineMg = caffeineMg
        }
        if let abv {
            amounts.alcoholGrams = volumeML * abv / 100 * Self.ethanolDensity
        }
        return amounts
    }

    var abv: Double? {
        guard volumeML > 0, alcoholGrams > 0 else { return nil }
        return alcoholGrams / Self.ethanolDensity / volumeML * 100
    }

    func scaled(by ratio: Double) -> DrinkAmounts {
        DrinkAmounts(
            volumeML: volumeML * ratio,
            hydrationML: hydrationML * ratio,
            caffeineMg: caffeineMg * ratio,
            alcoholGrams: alcoholGrams * ratio
        )
    }
}

struct DrinkSnapshot {
    let foodID: UUID?
    let quantity: Double
    let unit: String
    let amounts: DrinkAmounts
    let sizeName: String?

    init(_ entry: LoggedEntry) {
        foodID = entry.originalFoodItem?.id
        quantity = entry.loggedQuantity
        unit = entry.loggedUnit
        amounts = entry.drinkAmounts
        sizeName = entry.sizeName
    }

    func isSamePortion(quantity: Double, unit: String) -> Bool {
        unit == self.unit && EntryHelper.format(quantity) == EntryHelper.format(self.quantity)
    }

    func amounts(for food: FoodItem?, quantity: Double, unit: String) -> DrinkAmounts {
        let isSameFood = food?.id == foodID
        if isSameFood, isSamePortion(quantity: quantity, unit: unit) {
            return amounts
        }
        if isSameFood, amounts.volumeML > 0, let ratio = ratio(to: quantity, unit: unit, food: food) {
            return amounts.scaled(by: ratio)
        }
        guard let food, food.type == .drink else { return .zero }
        return DrinkAmounts(food: food, quantity: quantity, unit: unit)
    }

    private func ratio(to quantity: Double, unit: String, food: FoodItem?) -> Double? {
        if unit == self.unit {
            return self.quantity > 0 ? quantity / self.quantity : nil
        }
        guard let food else { return nil }
        let multiplier = { (quantity: Double, unit: String) in
            EntryHelper.portionMultiplier(
                quantity: quantity,
                unit: unit,
                servingSize: food.servingSize,
                servingWeight: food.servingWeight,
                servingWeightUnit: food.servingWeightUnit
            )
        }
        guard let from = multiplier(self.quantity, self.unit), from > 0,
            let to = multiplier(quantity, unit)
        else { return nil }
        return to / from
    }
}

extension FoodItem {
    var servingVolumeML: Double? {
        servingWeightUnit == VolumeUnit.milliliters.rawValue ? servingWeight : nil
    }

    static var drinksDescriptor: FetchDescriptor<FoodItem> {
        let drink = EntryType.drink
        return FetchDescriptor(
            predicate: #Predicate { $0.type == drink },
            sortBy: [SortDescriptor(\.name)]
        )
    }
}

extension LoggedEntry {
    var drinkAmounts: DrinkAmounts {
        get {
            DrinkAmounts(
                volumeML: volumeML,
                hydrationML: hydrationML,
                caffeineMg: caffeineMg,
                alcoholGrams: alcoholGrams
            )
        }
        set {
            volumeML = newValue.volumeML
            hydrationML = newValue.hydrationML
            caffeineMg = newValue.caffeineMg
            alcoholGrams = newValue.alcoholGrams
        }
    }
}

extension LoggedEntry {
    func snapshotDrinkAmounts(children: [LoggedEntry]? = nil) {
        let children = children ?? childEntries ?? []
        if !children.isEmpty {
            for child in children {
                child.snapshotDrinkAmounts(children: [])
            }
            drinkAmounts = children.reduce(.zero) { $0 + $1.drinkAmounts }
            sizeName = nil
            return
        }
        guard let food = originalFoodItem, food.type == .drink else {
            drinkAmounts = .zero
            sizeName = nil
            return
        }
        drinkAmounts = DrinkAmounts(food: food, quantity: loggedQuantity, unit: loggedUnit)
        sizeName = HydrationLogger.sizeName(for: food, volumeML: volumeML)
    }

    func updateDrinkAmounts(from snapshot: DrinkSnapshot) {
        let food = originalFoodItem
        if food?.id == snapshot.foodID, snapshot.isSamePortion(quantity: loggedQuantity, unit: loggedUnit) {
            drinkAmounts = snapshot.amounts
            sizeName = snapshot.sizeName
            return
        }
        drinkAmounts = snapshot.amounts(for: food, quantity: loggedQuantity, unit: loggedUnit)
        sizeName = food.flatMap { HydrationLogger.sizeName(for: $0, volumeML: volumeML) }
    }
}
