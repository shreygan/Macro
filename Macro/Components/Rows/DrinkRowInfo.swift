//
//  DrinkRowInfo.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/20/26.
//

import SwiftData
import SwiftUI

struct DrinkRowInfo: Equatable {
    var symbol: String
    var tint: DrinkTint
    var sizeName: String?
    var amounts: DrinkAmounts
    var hasMacros: Bool
    var drinkCount: Int? = nil

    func amountText(unit: VolumeUnit) -> String? {
        if let drinkCount {
            let count = drinkCount == 1
                ? String(localized: "1 drink") : String(localized: "\(drinkCount) drinks")
            return "\(count) · \(unit.formattedTotal(amounts.volumeML))"
        }
        guard amounts.volumeML > 0 else { return nil }
        let amount = unit.formattedAmount(amounts.volumeML)
        guard let sizeName, !sizeName.isEmpty else { return amount }
        return "\(sizeName) · \(amount)"
    }

    func factsText(unit: VolumeUnit, includesHydration: Bool = true) -> String? {
        var amounts = amounts
        if !includesHydration {
            amounts.hydrationML = amounts.volumeML
        }
        let parts = amounts.summary(unit: unit, calories: 0, usesTotals: drinkCount != nil)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct HydrationDaySummary: Equatable {
    let logs: [LoggedEntry]

    var calories: Double { logs.reduce(0) { $0 + $1.calories } }
    var protein: Double { logs.reduce(0) { $0 + $1.protein } }
    var carbs: Double { logs.reduce(0) { $0 + $1.carbs } }
    var fat: Double { logs.reduce(0) { $0 + $1.fat } }
    var fiber: Double { logs.reduce(0) { $0 + $1.fiber } }

    var rowInfo: DrinkRowInfo {
        DrinkRowInfo(
            symbol: DrinkFormState.defaultSymbol,
            tint: DrinkFormState.defaultTint,
            sizeName: nil,
            amounts: logs.reduce(.zero) { $0 + $1.drinkAmounts },
            hasMacros: calories > 0 || protein > 0 || carbs > 0 || fat > 0 || fiber > 0,
            drinkCount: logs.count
        )
    }
}

extension DrinkRowInfo {
    init(food: FoodItem, amounts: DrinkAmounts, hasMacros: Bool) {
        self.init(
            symbol: food.drinkSymbol,
            tint: food.drinkTint,
            sizeName: HydrationLogger.sizeName(for: food, volumeML: amounts.volumeML),
            amounts: amounts,
            hasMacros: hasMacros
        )
    }

    init?(food: FoodItem?, multiplier: Double, hasMacros: Bool) {
        guard let food, food.type == .drink else { return nil }
        self.init(
            food: food,
            amounts: DrinkAmounts(food: food, multiplier: multiplier),
            hasMacros: hasMacros
        )
    }

    init?(food: FoodItem) {
        self.init(
            food: food,
            multiplier: EntryHelper.defaultPortionMultiplier(for: food),
            hasMacros: food.calories > 0 || food.protein > 0 || food.carbs > 0 || food.fat > 0
                || food.fiber > 0
        )
    }

    init?(entry: LoggedEntry) {
        guard entry.typeRawValue == EntryType.drink.rawValue,
            (entry.childEntries ?? []).isEmpty
        else { return nil }
        let food = entry.originalFoodItem.flatMap { $0.type == .drink ? $0 : nil }
        self.init(
            symbol: food?.drinkSymbol ?? DrinkFormState.defaultSymbol,
            tint: food?.drinkTint ?? DrinkFormState.defaultTint,
            sizeName: entry.sizeName,
            amounts: entry.drinkAmounts,
            hasMacros: entry.calories > 0 || entry.protein > 0 || entry.carbs > 0 || entry.fat > 0
                || entry.fiber > 0
        )
    }
}

extension DrinkFormState {
    func rowInfo(
        multiplier: Double,
        calories: String,
        protein: String,
        carbs: String,
        fat: String,
        fiber: String
    ) -> DrinkRowInfo {
        let value = { (text: String) in (Self.parse(text) ?? 0) * multiplier }
        return rowInfo(
            multiplier: multiplier,
            hasMacros: [calories, protein, carbs, fat, fiber].contains { value($0) > 0 }
        )
    }

    func rowInfo(multiplier: Double = 1, hasMacros: Bool) -> DrinkRowInfo {
        let volume = (servingVolumeML ?? 0) * multiplier
        let hydrationPercent = min(max(Self.parse(hydrationPercent) ?? 100, 0), 100)
        let caffeine = isOn(.caffeine) ? (Self.parse(caffeine) ?? 0) * multiplier : 0
        let trimmedName = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrinkRowInfo(
            symbol: symbol,
            tint: tint,
            sizeName: multiplier == 1 && !trimmedName.isEmpty ? trimmedName : nil,
            amounts: DrinkAmounts(
                volumeML: volume,
                hydrationML: volume * hydrationPercent / 100,
                caffeineMg: caffeine,
                alcoholGrams: volume * (abvValue ?? 0) / 100 * DrinkAmounts.ethanolDensity
            ),
            hasMacros: isOn(.nutrition) && hasMacros
        )
    }
}

extension DraftRecipeIngredient {
    var drinkRowInfo: DrinkRowInfo? {
        DrinkRowInfo(
            food: item,
            multiplier: activeMultiplier,
            hasMacros: activeCalories > 0 || activeProtein > 0 || activeCarbs > 0 || activeFat > 0
                || activeFiber > 0
        )
    }
}

extension LogRecipeIngredient {
    var drinkRowInfo: DrinkRowInfo? {
        DrinkRowInfo(
            food: ingredientItem,
            multiplier: activeMultiplier,
            hasMacros: activeCalories > 0 || activeProtein > 0 || activeCarbs > 0 || activeFat > 0
                || activeFiber > 0
        )
    }
}

extension DraftFoodItem {
    func drinkRowInfo(multiplier: Double) -> DrinkRowInfo? {
        guard type == .drink else { return nil }
        let form = DrinkFormState(
            record: drink,
            servingVolumeML: servingWeightUnit == VolumeUnit.milliliters.rawValue ? servingWeight : nil,
            unit: .milliliters
        )
        return form.rowInfo(
            multiplier: multiplier,
            hasMacros: calories > 0 || protein > 0 || carbs > 0 || fat > 0 || fiber > 0
        )
    }
}

extension DraftLogEntry {
    var drinkRowInfo: DrinkRowInfo? {
        guard entryType == .drink, components.isEmpty, let hydration else { return nil }
        return DrinkRowInfo(
            symbol: DrinkFormState.defaultSymbol,
            tint: DrinkFormState.defaultTint,
            sizeName: hydration.sizeName,
            amounts: DrinkAmounts(
                volumeML: hydration.volumeML,
                hydrationML: hydration.hydrationML,
                caffeineMg: hydration.caffeineMg,
                alcoholGrams: hydration.alcoholGrams
            ),
            hasMacros: calories > 0 || protein > 0 || carbs > 0 || fat > 0 || fiber > 0
        )
    }
}

struct DrinkBadge: View {
    let symbol: String
    let tint: DrinkTint

    var body: some View {
        Image(symbol: symbol)
            .font(.smallIcon)
            .foregroundStyle(tint.color)
            .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    @Entry var volumeUnit: VolumeUnit = .localeDefault
    @Entry var tracksHydration: Bool = true
}

struct UserSettingsEnvironment: ViewModifier {
    @Query private var users: [User]

    func body(content: Content) -> some View {
        content
            .environment(\.volumeUnit, users.first?.volumeUnit ?? .localeDefault)
            .environment(\.tracksHydration, users.first?.tracksHydration ?? true)
    }
}

extension View {
    func userSettingsEnvironment() -> some View {
        modifier(UserSettingsEnvironment())
    }
}

#Preview {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = container.mainContext
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: context)
    let units = (try? context.fetch(FetchDescriptor<ServingSizeUnit>())) ?? []

    func drink(_ name: String, symbol: String, tint: DrinkTint, ml: Double, kcal: Double, p: Double, c: Double, f: Double) -> FoodItem {
        let food = FoodItem(
            name: name, type: .drink, servingSize: 1, servingWeight: ml, servingWeightUnit: "ml",
            isAIEstimated: false, calories: kcal, protein: p, carbs: c, fat: f, fiber: 0,
            isCustomDefaultServing: false
        )
        food.symbol = symbol
        food.tintRawValue = tint.rawValue
        food.hasNutrition = kcal > 0
        context.insert(food)
        return food
    }
    drink("Modelo Especial", symbol: "wineglass.fill", tint: .yellow, ml: 355, kcal: 153, p: 1.6, c: 13, f: 0).abv = 4.4
    _ = drink("Protein Shake", symbol: "dumbbell.fill", tint: .purple, ml: 340, kcal: 150, p: 30, c: 4, f: 2.5)
    let salad = FoodItem(
        name: "Grilled Chicken Salad", type: .food, servingSize: 1, servingWeightUnit: "g", isAIEstimated: false,
        calories: 450, protein: 42, carbs: 12, fat: 18, fiber: 6, isCustomDefaultServing: false
    )
    context.insert(salad)
    let foods = (try? context.fetch(FetchDescriptor<FoodItem>(sortBy: [SortDescriptor(\.name)]))) ?? []
    let coffee = foods.first { $0.seedKey == "coffee" }
    let loggedCoffee = coffee.flatMap {
        try? HydrationLogger.log($0, volumeML: 350, sizeName: "Mug", at: .now, in: context)
    }

    var drinkDraftState = AddEntryDraftState.empty
    var drinkForm = DrinkFormState(unit: .milliliters)
    drinkForm.symbol = "leaf.fill"
    drinkForm.tint = .green
    drinkForm.volume = "330"
    drinkForm.servingName = "Bottle"
    drinkDraftState.drink = drinkForm
    let drinkDraft = EntryDraft(kind: .addFood, type: .drink, name: "Iced Green Tea")
    drinkDraft.encodeState(drinkDraftState)
    context.insert(drinkDraft)

    return ZStack {
        Color.background.ignoresSafeArea()
        ScrollView {
            Card {
                VStack(spacing: 0) {
                    if let loggedCoffee {
                        LogHistoryRow(entry: loggedCoffee, servingUnits: units) {}
                    }
                    DraftRow(draft: drinkDraft, servingUnits: units) {}
                }
            }
            .padding([.horizontal, .top])

            Card {
                VStack(spacing: 0) {
                    ForEach(foods) { food in
                        MealRow(food: food, servingUnits: units, icon: food.type.appSymbol) {}
                        Divider().padding(.leading, 16)
                    }
                    if let loggedCoffee {
                        MealRow(
                            name: loggedCoffee.name, source: "", isCustomDefaultServing: false,
                            customServingSize: "", servingSize: "350", servingSizeUnit: "ml",
                            servingWeight: "", servingWeightUnit: "", servingUnits: units,
                            calorie: String(loggedCoffee.calories), action: {}
                        )
                        .drink(DrinkRowInfo(entry: loggedCoffee))
                    }
                }
            }
            .padding()

            Card {
                VStack(spacing: 0) {
                    ForEach(foods) { food in
                        CompactMealRow(food: food)
                    }
                }
            }
            .frame(width: 260)
        }
    }
    .modelContainer(container)
    .environment(\.volumeUnit, .milliliters)
}
