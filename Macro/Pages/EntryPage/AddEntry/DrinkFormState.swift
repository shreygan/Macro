//
//  DrinkFormState.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import Foundation
import SwiftData

enum DrinkDetail: String, Codable, CaseIterable, Identifiable {
    case caffeine
    case alcohol
    case nutrition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: String(localized: "Nutrition")
        case .caffeine: String(localized: "Caffeine")
        case .alcohol: String(localized: "Alcohol")
        }
    }
}

enum AlcoholStrength: String, CaseIterable {
    case light
    case regular
    case strong
    case wine
    case fortified
    case spirits
    case custom

    var abv: Double? {
        switch self {
        case .light: 4.2
        case .regular: 5
        case .strong: 7
        case .wine: 12
        case .fortified: 17
        case .spirits: 40
        case .custom: nil
        }
    }

    var label: String {
        switch self {
        case .light: String(localized: "Light · 4.2%")
        case .regular: String(localized: "Regular · 5%")
        case .strong: String(localized: "Strong · 7%")
        case .wine: String(localized: "Wine · 12%")
        case .fortified: String(localized: "Fortified · 17%")
        case .spirits: String(localized: "Spirits · 40%")
        case .custom: String(localized: "Custom")
        }
    }

    var examples: String? {
        switch self {
        case .light: String(localized: "Light beer")
        case .regular: String(localized: "Beer, cider, hard seltzer")
        case .strong: String(localized: "IPA, strong cider")
        case .wine: String(localized: "Red, white, rosé")
        case .fortified: String(localized: "Port, sherry")
        case .spirits: String(localized: "Vodka, whisky, gin")
        case .custom: nil
        }
    }

    static var presets: [AlcoholStrength] {
        allCases.filter { $0 != .custom }
    }

    static func matching(_ abv: Double?) -> AlcoholStrength? {
        guard let abv else { return nil }
        return allCases.first { $0.abv == abv }
    }
}

struct DrinkSizeDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var volume = ""
    var exactML: Double?
}

struct DrinkFormState: Codable, Equatable {
    static let defaultSymbol = "waterglass.fill"
    static let defaultTint = DrinkTint.gray

    var symbol = defaultSymbol
    var tint = defaultTint
    var unit: VolumeUnit
    var volume = ""
    var exactVolumeML: Double?
    var servingName = ""
    var servingSizeID: UUID?
    var sizes: [DrinkSizeDraft] = []
    var details: [DrinkDetail] = []
    var caffeine = ""
    var abv = ""
    var isCustomABV = false
    var hydrationPercent = "100"
    var isPinned = false

    init(unit: VolumeUnit, isPinned: Bool = false) {
        self.unit = unit
        self.isPinned = isPinned
    }

    init(food: FoodItem, unit: VolumeUnit) {
        self.init(record: MacroBackup.drinkRecord(food), servingVolumeML: food.servingVolumeML, unit: unit)
    }

    init(record: MacroBackup.DrinkRecord?, servingVolumeML: Double?, unit: VolumeUnit) {
        self.unit = unit
        symbol = record?.symbol.flatMap { DrinkSymbol.contains($0) ? $0 : nil } ?? Self.defaultSymbol
        tint = record?.tint.flatMap(DrinkTint.init(rawValue:)) ?? Self.defaultTint
        volume = servingVolumeML.map { Self.text(forML: $0, unit: unit) } ?? ""
        exactVolumeML = servingVolumeML
        let recordSizes = (record?.sizes ?? []).sorted { $0.displayOrder < $1.displayOrder }
        let matchesServing: (MacroBackup.DrinkSizeRecord) -> Bool = { size in
            servingVolumeML.map { abs(size.volumeML - $0) < 0.5 } ?? false
        }
        let servingRecord =
            recordSizes.first { $0.isDefault && matchesServing($0) } ?? recordSizes.first(where: matchesServing)
        servingName = servingRecord?.name ?? ""
        servingSizeID = servingRecord?.id
        sizes = recordSizes.filter { $0.id != servingRecord?.id }.map {
            DrinkSizeDraft(
                id: $0.id,
                name: $0.name ?? "",
                volume: Self.text(forML: $0.volumeML, unit: unit),
                exactML: $0.volumeML
            )
        }
        isPinned = record?.hydrationOrder != nil

        guard let record else { return }
        if record.hasNutrition { details.append(.nutrition) }
        if let caffeine = record.caffeineMg {
            details.append(.caffeine)
            self.caffeine = EntryHelper.format(caffeine)
        }
        if let abv = record.abv {
            details.append(.alcohol)
            self.abv = EntryHelper.format(abv)
            isCustomABV = AlcoholStrength.matching(abv) == nil
        }
        hydrationPercent = EntryHelper.format(record.hydrationPercent)
    }

    private struct ResolvedSize {
        let id: UUID
        let name: String?
        let volumeML: Double
        let isServing: Bool
    }

    private static func trimmedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvedSizes(servingID: UUID) -> [ResolvedSize] {
        var result: [ResolvedSize] = []
        let serving = servingVolumeML
        if let serving {
            result.append(
                ResolvedSize(id: servingID, name: Self.trimmedName(servingName), volumeML: serving, isServing: true)
            )
        }
        for draft in sizes {
            guard let volume = milliliters(draft), duplicateName(of: draft) == nil else { continue }
            result.append(
                ResolvedSize(id: draft.id, name: Self.trimmedName(draft.name), volumeML: volume, isServing: false)
            )
        }
        return result
    }

    func record(keeping original: MacroBackup.DrinkRecord?) -> MacroBackup.DrinkRecord {
        MacroBackup.DrinkRecord(
            hydrationPercent: resolvedHydrationPercent,
            caffeineMg: caffeineValue,
            abv: details.contains(.alcohol) ? abvValue ?? 0 : nil,
            hasNutrition: details.contains(.nutrition),
            symbol: symbol,
            tint: tint.rawValue,
            hydrationOrder: original?.hydrationOrder,
            seedKey: original?.seedKey,
            sizes: resolvedSizes(servingID: servingSizeID ?? UUID()).enumerated().map { index, size in
                MacroBackup.DrinkSizeRecord(
                    id: size.id,
                    name: size.name,
                    volumeML: size.volumeML,
                    displayOrder: index,
                    isDefault: size.isServing
                )
            }
        )
    }

    private var resolvedHydrationPercent: Double {
        min(max(Self.parse(hydrationPercent) ?? 100, 0), 100)
    }

    var countsTowardWaterGoal: Bool {
        get { resolvedHydrationPercent > 0 }
        set { hydrationPercent = newValue ? "100" : "0" }
    }

    static func text(forML milliliters: Double, unit: VolumeUnit) -> String {
        let value = unit.value(fromML: milliliters)
        switch unit {
        case .milliliters: return EntryHelper.format(value.rounded())
        case .fluidOunces: return EntryHelper.format((value * 10).rounded() / 10)
        }
    }

    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    func milliliters(_ text: String, exact: Double? = nil) -> Double? {
        if let exact, text == Self.text(forML: exact, unit: unit) { return exact }
        guard let value = Self.parse(text), value > 0 else { return nil }
        return unit.milliliters(from: value)
    }

    func milliliters(_ size: DrinkSizeDraft) -> Double? {
        milliliters(size.volume, exact: size.exactML)
    }

    func duplicateName(of size: DrinkSizeDraft) -> String? {
        guard let volume = milliliters(size) else { return nil }
        if let serving = servingVolumeML, abs(volume - serving) < 0.5 {
            return Self.trimmedName(servingName) ?? String(localized: "Serving")
        }
        for other in sizes {
            if other.id == size.id { break }
            if let otherVolume = milliliters(other), abs(volume - otherVolume) < 0.5 {
                return Self.trimmedName(other.name) ?? String(localized: "another size")
            }
        }
        return nil
    }

    struct OptionalLines: Equatable {
        let duplicateNames: [String?]
        let sizesWithStandardDrinks: [Bool]
        let servingHasStandardDrinks: Bool
        let suggestsAlcoholCalories: Bool
    }

    var optionalLines: OptionalLines {
        OptionalLines(
            duplicateNames: sizes.map(duplicateName(of:)),
            sizesWithStandardDrinks: sizes.map { milliliters($0).flatMap(standardDrinks(forML:)) != nil },
            servingHasStandardDrinks: servingVolumeML.flatMap(standardDrinks(forML:)) != nil,
            suggestsAlcoholCalories: !details.contains(.nutrition) && suggestedAlcoholCalories != nil
        )
    }

    var suggestedAlcoholCalories: Double? {
        guard let kcal = alcoholCaloriesPerServing?.rounded(), kcal >= 1 else { return nil }
        return kcal
    }

    var servingVolumeML: Double? {
        milliliters(volume, exact: exactVolumeML)
    }

    var hasValidVolume: Bool {
        servingVolumeML != nil
    }

    var hasIncompleteSizes: Bool {
        sizes.contains { Self.trimmedName($0.name) != nil && milliliters($0) == nil }
    }

    var isPristine: Bool {
        self == DrinkFormState(unit: unit, isPinned: isPinned)
    }

    var caffeineValue: Double? {
        guard details.contains(.caffeine) else { return nil }
        return Self.parse(caffeine)
    }

    var abvValue: Double? {
        guard details.contains(.alcohol) else { return nil }
        return Self.parse(abv)
    }

    var strength: AlcoholStrength {
        get {
            if isCustomABV { return .custom }
            return AlcoholStrength.matching(Self.parse(abv)) ?? .custom
        }
        set {
            if let abv = newValue.abv {
                isCustomABV = false
                self.abv = EntryHelper.format(abv)
            } else {
                isCustomABV = true
            }
        }
    }

    var alcoholCaloriesPerServing: Double? {
        guard let abv = abvValue, abv > 0, let volume = servingVolumeML, volume > 0 else { return nil }
        return DrinkAmounts.alcoholCalories(volumeML: volume, abv: abv)
    }

    func standardDrinks(forML milliliters: Double) -> Double? {
        guard let abv = abvValue, abv > 0 else { return nil }
        return DrinkAmounts.standardDrinks(alcoholGrams: milliliters * abv / 100 * DrinkAmounts.ethanolDensity)
    }

    mutating func add(_ detail: DrinkDetail) {
        guard !details.contains(detail) else { return }
        details.append(detail)
        switch detail {
        case .alcohol where abv.isEmpty:
            strength = .regular
        default:
            break
        }
    }

    mutating func remove(_ detail: DrinkDetail) {
        details.removeAll { $0 == detail }
    }

    func isOn(_ detail: DrinkDetail) -> Bool {
        details.contains(detail)
    }

    @discardableResult
    mutating func addSize() -> UUID {
        let size = DrinkSizeDraft()
        sizes.append(size)
        return size.id
    }

    @MainActor
    func apply(to food: FoodItem, in context: ModelContext, asCopy: Bool = false) {
        guard !asCopy else {
            var copy = self
            copy.servingSizeID = nil
            copy.sizes = sizes.map { size in
                var fresh = size
                fresh.id = UUID()
                return fresh
            }
            copy.apply(to: food, in: context)
            return
        }
        food.symbol = symbol
        food.tintRawValue = tint.rawValue
        food.servingWeight = servingVolumeML
        food.servingWeightUnit = VolumeUnit.milliliters.rawValue
        food.hasNutrition = details.contains(.nutrition)
        if !food.hasNutrition {
            food.calories = 0
            food.protein = 0
            food.carbs = 0
            food.fat = 0
            food.fiber = 0
        }
        food.caffeineMg = caffeineValue
        food.abv = details.contains(.alcohol) ? abvValue ?? 0 : nil
        food.hydrationPercent = resolvedHydrationPercent
        if isPinned && hasValidVolume {
            FoodItem.pinToLogDrink(food, in: context)
        } else {
            food.hydrationOrder = nil
        }

        let kept = resolvedSizes(servingID: servingSizeID ?? UUID())
        let existing = food.drinkSizes ?? []
        for size in existing where !kept.contains(where: { $0.id == size.id }) {
            context.delete(size)
        }
        var updated: [DrinkSize] = []
        for (index, resolved) in kept.enumerated() {
            let size: DrinkSize
            if let match = existing.first(where: { $0.id == resolved.id }) {
                size = match
            } else {
                size = DrinkSize(id: resolved.id, volumeML: resolved.volumeML, displayOrder: index)
                context.insert(size)
            }
            size.name = resolved.name
            size.volumeML = resolved.volumeML
            size.displayOrder = index
            size.isDefault = resolved.isServing
            size.food = food
            updated.append(size)
        }
        food.drinkSizes = updated
    }
}
