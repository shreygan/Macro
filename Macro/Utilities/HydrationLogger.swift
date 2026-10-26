//
//  HydrationLogger.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import Foundation
import SwiftData

struct PendingDrinkSize: Codable, Equatable, Identifiable {
    var id = UUID()
    var foodID: UUID
    var name: String?
    var volumeML: Double
}

struct DrinkLogPrefill: Identifiable {
    let id = UUID()
    let drink: FoodItem
    var volumeML: Double
    var timestamp: Date
    var pendingSizes: [PendingDrinkSize]
}

struct HydrationChip: Identifiable {
    let food: FoodItem
    let volumeML: Double
    let sizeName: String?

    var id: String { "\(food.id.uuidString)-\(Int(volumeML.rounded()))" }
}

enum HydrationLogger {
    static let menuRecentAmountLimit = 2
    static let recentAmountLimit = 3
    static let recentLogLimit = 50

    static func isSameVolume(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.5
    }

    @discardableResult
    static func log(
        _ drink: FoodItem,
        volumeML: Double,
        sizeName: String?,
        at timestamp: Date,
        in context: ModelContext
    ) throws -> LoggedEntry {
        let entry = LoggedEntry(
            name: drink.name,
            typeRawValue: drink.type.rawValue,
            timestamp: timestamp,
            loggedQuantity: volumeML,
            loggedUnit: VolumeUnit.milliliters.rawValue,
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: 0
        )
        context.insert(entry)
        entry.isHydrationLog = true
        apply(drink, volumeML: volumeML, sizeName: sizeName, to: entry)
        if let location = defaultLocation(for: drink, in: context) {
            entry.setLocation(location, in: context)
            RecentLocationStore.record(location, usedAt: timestamp, in: context)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return entry
    }

    static func defaultLocation(for drink: FoodItem, in context: ModelContext) -> EntryLocation? {
        drink.defaultLocation.map { DefaultLocationResolver.resolved($0, in: context) }
    }

    static func apply(
        _ drink: FoodItem,
        volumeML: Double,
        sizeName: String?,
        to entry: LoggedEntry
    ) {
        let servingVolume = drink.servingVolumeML ?? 0
        let multiplier = servingVolume > 0 ? volumeML / servingVolume : 0

        entry.name = drink.name
        entry.typeRawValue = drink.type.rawValue
        entry.originalFoodItem = drink
        entry.source = drink.source
        entry.category = drink.category
        entry.foodGroup = drink.foodGroup
        entry.loggedQuantity = volumeML
        entry.loggedUnit = VolumeUnit.milliliters.rawValue
        entry.calories = drink.calories * multiplier
        entry.protein = drink.protein * multiplier
        entry.carbs = drink.carbs * multiplier
        entry.fat = drink.fat * multiplier
        entry.fiber = drink.fiber * multiplier
        entry.drinkAmounts = DrinkAmounts(
            food: drink,
            quantity: volumeML,
            unit: VolumeUnit.milliliters.rawValue
        )
        entry.sizeName = sizeName
    }

    static func update(_ entry: LoggedEntry, to drink: FoodItem?, volumeML: Double) {
        let isSameDrink = entry.originalFoodItem?.id == drink?.id
        if let drink, drink.type == .drink, !isSameDrink || entry.volumeML <= 0 {
            apply(drink, volumeML: volumeML, sizeName: sizeName(for: drink, volumeML: volumeML), to: entry)
            return
        }
        guard isSameDrink, !isSameVolume(volumeML, entry.volumeML) else { return }
        guard entry.volumeML > 0 else {
            setVolume(volumeML, of: entry, drink: drink)
            return
        }

        let ratio = volumeML / entry.volumeML
        entry.loggedQuantity = volumeML
        entry.loggedUnit = VolumeUnit.milliliters.rawValue
        entry.calories *= ratio
        entry.protein *= ratio
        entry.carbs *= ratio
        entry.fat *= ratio
        entry.fiber *= ratio
        entry.drinkAmounts = entry.drinkAmounts.scaled(by: ratio)
        entry.sizeName = drink.flatMap { sizeName(for: $0, volumeML: volumeML) }
    }

    private static func setVolume(_ volumeML: Double, of entry: LoggedEntry, drink: FoodItem?) {
        if entry.loggedUnit == VolumeUnit.milliliters.rawValue, entry.loggedQuantity > 0 {
            let ratio = volumeML / entry.loggedQuantity
            entry.calories *= ratio
            entry.protein *= ratio
            entry.carbs *= ratio
            entry.fat *= ratio
            entry.fiber *= ratio
        }
        entry.loggedQuantity = volumeML
        entry.loggedUnit = VolumeUnit.milliliters.rawValue
        entry.volumeML = volumeML
        entry.hydrationML = drink == nil ? volumeML : 0
        entry.sizeName = drink.flatMap { sizeName(for: $0, volumeML: volumeML) }
    }

    static func timestamp(forDay day: Date, dayStartMinutes: Int, now: Date = .now) -> Date {
        let calendar = Calendar.current
        let range = calendar.logicalDayRange(for: day, dayStartMinutes: dayStartMinutes)
        if range.contains(now) { return now }
        return place(now, inDay: day, dayStartMinutes: dayStartMinutes)
    }

    static func place(_ time: Date, inDay day: Date, dayStartMinutes: Int) -> Date {
        let calendar = Calendar.current
        let range = calendar.logicalDayRange(for: day, dayStartMinutes: dayStartMinutes)
        if range.contains(time) { return time }

        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        var candidate =
            calendar.date(
                bySettingHour: components.hour ?? 12,
                minute: components.minute ?? 0,
                second: components.second ?? 0,
                of: range.lowerBound
            ) ?? range.lowerBound
        if candidate < range.lowerBound {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        if candidate >= range.upperBound {
            candidate = range.upperBound.addingTimeInterval(-60)
        }
        return candidate
    }

    static func loggedTitle(forDay day: Date, logicalToday: Date) -> String {
        Calendar.current.isDate(day, inSameDayAs: logicalToday)
            ? String(localized: "Logged for Today")
            : String(localized: "Logged for \(EntryHelper.logDayText(day))")
    }

    static func sizeName(for food: FoodItem, volumeML: Double) -> String? {
        food.sortedDrinkSizes.first { isSameVolume($0.volumeML, volumeML) }?.name
    }

    static func menuSizes(for food: FoodItem) -> [HydrationChip] {
        let sizes = food.sortedDrinkSizes
        guard !sizes.isEmpty else {
            return food.servingVolumeML.map { [HydrationChip(food: food, volumeML: $0, sizeName: nil)] } ?? []
        }
        let serving = food.defaultDrinkSize
        let ordered = serving.map { serving in [serving] + sizes.filter { $0.id != serving.id } } ?? sizes
        return ordered.map { HydrationChip(food: food, volumeML: $0.volumeML, sizeName: $0.name) }
    }

    static func addSizes(_ pending: [PendingDrinkSize], to food: FoodItem, in context: ModelContext) {
        guard !pending.isEmpty else { return }
        var sizes = food.sortedDrinkSizes
        if sizes.isEmpty, let serving = food.servingVolumeML {
            let size = DrinkSize(volumeML: serving, displayOrder: 0, isDefault: true)
            context.insert(size)
            size.food = food
            sizes.append(size)
        }
        var order = (sizes.map(\.displayOrder).max() ?? -1) + 1
        for item in pending where !sizes.contains(where: { isSameVolume($0.volumeML, item.volumeML) }) {
            let size = DrinkSize(name: item.name, volumeML: item.volumeML, displayOrder: order)
            context.insert(size)
            size.food = food
            sizes.append(size)
            order += 1
        }
    }

    static func recentLogsDescriptor(
        for food: FoodItem,
        includesEntries: Bool = false
    ) -> FetchDescriptor<LoggedEntry> {
        let foodID = food.id
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate {
                ($0.isHydrationLog || (includesEntries && $0.parentEntry == nil))
                    && $0.volumeML > 0 && $0.originalFoodItem?.id == foodID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = recentLogLimit
        return descriptor
    }

    static func recentAmounts(
        for food: FoodItem,
        includesEntries: Bool = false,
        excluding excludedEntry: LoggedEntry? = nil,
        in context: ModelContext
    ) -> [Double] {
        let logs = (try? context.fetch(recentLogsDescriptor(for: food, includesEntries: includesEntries))) ?? []
        let volumes = logs
            .filter { $0.persistentModelID != excludedEntry?.persistentModelID }
            .map(\.volumeML)
        return recentAmounts(for: food, volumes: volumes)
    }

    static func recentAmounts(for food: FoodItem, volumes: [Double], limit: Int = recentAmountLimit) -> [Double] {
        let sizes = menuSizes(for: food).map(\.volumeML)
        var amounts: [Double] = []
        for volume in volumes {
            guard !sizes.contains(where: { isSameVolume($0, volume) }),
                !amounts.contains(where: { isSameVolume($0, volume) })
            else { continue }
            amounts.append(volume)
            if amounts.count == limit { break }
        }
        return amounts
    }
}

extension VolumeUnit {
    var totalUnitLabel: String {
        switch self {
        case .milliliters: "L"
        case .fluidOunces: "fl oz"
        }
    }

    func editableText(fromML milliliters: Double) -> String {
        let value = value(fromML: milliliters)
        switch self {
        case .milliliters: return EntryHelper.format(value.rounded())
        case .fluidOunces: return EntryHelper.format((value * 10).rounded() / 10)
        }
    }

    func formattedAmount(_ milliliters: Double) -> String {
        "\(formattedValue(milliliters)) \(rawValue)"
    }

    func formattedValue(_ milliliters: Double) -> String {
        let value = value(fromML: milliliters)
        switch self {
        case .milliliters:
            return value.formatted(.number.precision(.fractionLength(0)))
        case .fluidOunces:
            return value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    func formattedTotalValue(_ milliliters: Double) -> String {
        switch self {
        case .milliliters:
            return (milliliters / 1000).formatted(.number.precision(.fractionLength(0...2)))
        case .fluidOunces:
            return value(fromML: milliliters).formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    func formattedCompactAmount(_ milliliters: Double) -> String {
        self == .milliliters && milliliters >= 1000 ? formattedTotal(milliliters) : formattedAmount(milliliters)
    }

    func formattedTotal(_ milliliters: Double) -> String {
        "\(formattedTotalValue(milliliters)) \(totalUnitLabel)"
    }

    func spokenTotal(_ milliliters: Double) -> String {
        let measurement: Measurement<UnitVolume>
        let fractionDigits: ClosedRange<Int>
        switch self {
        case .milliliters:
            measurement = Measurement(value: milliliters / 1000, unit: .liters)
            fractionDigits = 0...2
        case .fluidOunces:
            measurement = Measurement(value: value(fromML: milliliters), unit: .fluidOunces)
            fractionDigits = 0...1
        }
        return measurement.formatted(
            .measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(fractionDigits)))
        )
    }

    func spokenProgress(_ milliliters: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return spokenTotal(milliliters) }
        let progress = String(localized: "\(formattedTotalValue(milliliters)) of \(spokenTotal(goal))")
        guard milliliters >= goal else { return progress }
        return String(localized: "\(progress), goal reached")
    }
}

extension DrinkAmounts {
    nonisolated static func standardDrinks(alcoholGrams: Double) -> Double {
        alcoholGrams / 14
    }

    nonisolated static func standardDrinksText(_ drinks: Double) -> String {
        let rounded = (drinks * 10).rounded() / 10
        if rounded == 0 {
            return String(localized: "<0.1 standard drinks")
        }
        if rounded == 1 {
            return String(localized: "1 standard drink")
        }
        return String(localized: "\(rounded.formatted(.number.precision(.fractionLength(0...1)))) standard drinks")
    }

    func summary(unit: VolumeUnit, calories: Double, usesTotals: Bool = false) -> [String] {
        var parts: [String] = []
        if hydrationML <= 0, volumeML > 0 {
            parts.append(String(localized: "Excluded from water goal"))
        } else if !HydrationLogger.isSameVolume(hydrationML, volumeML) {
            let amount = usesTotals ? unit.formattedTotal(hydrationML) : unit.formattedAmount(hydrationML)
            parts.append(String(localized: "Counts as \(amount)"))
        }
        if caffeineMg > 0 {
            parts.append(String(localized: "\(caffeineMg.formatted(.number.precision(.fractionLength(0)))) mg caffeine"))
        }
        if calories > 0 {
            parts.append(String(localized: "\(EntryHelper.formatMacro(calories)) kcal"))
        }
        if alcoholGrams > 0 {
            parts.append(Self.standardDrinksText(Self.standardDrinks(alcoholGrams: alcoholGrams)))
        }
        return parts
    }
}
