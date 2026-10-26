//
//  AppSeeder.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/29/26.
//

import Foundation
import SwiftData

struct AppSeeder {
    static let defaultEntrySources = ["Home", "Work"]
    static let defaultCategorySources = [
        "Meal", "Snack", "Breakfast", "Lunch", "Dinner", "Dessert",
    ]
    static let defaultServingSizeUnits = [
        "serving", "cup", "piece", "slice", "oz", "container", "bar",
    ]
    static let defaultServingSizePlural: [String?] = [
        "servings", "cups", "pieces", "slices", nil, "containers", "bars",
    ]
    static let defaultFoodGroupSources = [
        "Vegetables", "Proteins", "Grains", "Dairy", "Oils", "Condiments",
        "Fruits", "Others",
    ]

    struct DrinkSeed {
        struct Size {
            let name: String
            let volumeML: Double
        }

        struct Nutrition {
            var calories: Double
            var protein: Double = 0
            var carbs: Double = 0
            var fat: Double = 0
            var fiber: Double = 0
        }

        let key: String
        let name: String
        let symbol: String
        let tint: DrinkTint
        let servingUnit: String
        let sizes: [Size]
        var caffeineMg: Double? = nil
        var abv: Double? = nil
        var nutrition: Nutrition? = nil
        var isPinned = false
    }

    static let defaultDrinks = [
        DrinkSeed(
            key: "water",
            name: "Water",
            symbol: "drop.fill",
            tint: .blue,
            servingUnit: "serving",
            sizes: [.init(name: "Glass", volumeML: 250), .init(name: "Bottle", volumeML: 500)],
            isPinned: true
        ),
        DrinkSeed(
            key: "coffee",
            name: "Coffee",
            symbol: "mug.fill",
            tint: .brown,
            servingUnit: "cup",
            sizes: [.init(name: "Cup", volumeML: 240), .init(name: "Mug", volumeML: 350)],
            caffeineMg: 96,
            isPinned: true
        ),
        DrinkSeed(
            key: "sparklingWater",
            name: "Sparkling Water",
            symbol: "bubbles.and.sparkles.fill",
            tint: .teal,
            servingUnit: "serving",
            sizes: [.init(name: "Can", volumeML: 355), .init(name: "Bottle", volumeML: 500)]
        ),
        DrinkSeed(
            key: "espresso",
            name: "Espresso",
            symbol: "cup.and.saucer.fill",
            tint: .darkRoast,
            servingUnit: "serving",
            sizes: [.init(name: "Single", volumeML: 30), .init(name: "Double", volumeML: 60)],
            caffeineMg: 63
        ),
        DrinkSeed(
            key: "latte",
            name: "Latte",
            symbol: "cup.hot.lid.fill",
            tint: .latte,
            servingUnit: "serving",
            sizes: [.init(name: "Small", volumeML: 355), .init(name: "Large", volumeML: 473)],
            caffeineMg: 127,
            nutrition: .init(calories: 140, protein: 9, carbs: 14, fat: 5.5)
        ),
        DrinkSeed(
            key: "tea",
            name: "Tea",
            symbol: "cup.and.heat.waves.fill",
            tint: .amber,
            servingUnit: "cup",
            sizes: [.init(name: "Cup", volumeML: 240)],
            caffeineMg: 48
        ),
        DrinkSeed(
            key: "greenTea",
            name: "Green Tea",
            symbol: "leaf.fill",
            tint: .green,
            servingUnit: "cup",
            sizes: [.init(name: "Cup", volumeML: 240)],
            caffeineMg: 29
        ),
        DrinkSeed(
            key: "milk",
            name: "Milk (2%)",
            symbol: "carton.fill",
            tint: .navy,
            servingUnit: "cup",
            sizes: [.init(name: "Glass", volumeML: 240)],
            nutrition: .init(calories: 124, protein: 8.2, carbs: 11.9, fat: 4.9)
        ),
        DrinkSeed(
            key: "orangeJuice",
            name: "Orange Juice",
            symbol: "citrusslice.fill",
            tint: .orange,
            servingUnit: "cup",
            sizes: [.init(name: "Glass", volumeML: 240)],
            nutrition: .init(calories: 113, protein: 1.8, carbs: 26.2, fat: 0.5, fiber: 0.5)
        ),
        DrinkSeed(
            key: "cola",
            name: "Cola",
            symbol: "sodacan.fill",
            tint: .red,
            servingUnit: "serving",
            sizes: [.init(name: "Can", volumeML: 355), .init(name: "Bottle", volumeML: 591)],
            caffeineMg: 34,
            nutrition: .init(calories: 140, carbs: 39)
        ),
        DrinkSeed(
            key: "dietCola",
            name: "Diet Cola",
            symbol: "sodacan.fill",
            tint: .graphite,
            servingUnit: "serving",
            sizes: [.init(name: "Can", volumeML: 355), .init(name: "Bottle", volumeML: 591)],
            caffeineMg: 46
        ),
        DrinkSeed(
            key: "energyDrink",
            name: "Energy Drink",
            symbol: "bolt.fill",
            tint: .lime,
            servingUnit: "serving",
            sizes: [.init(name: "Can", volumeML: 250), .init(name: "Large Can", volumeML: 473)],
            caffeineMg: 80,
            nutrition: .init(calories: 110, carbs: 29)
        ),
        DrinkSeed(
            key: "sportsDrink",
            name: "Sports Drink",
            symbol: "bottle.squeeze.fill",
            tint: .mint,
            servingUnit: "serving",
            sizes: [.init(name: "Bottle", volumeML: 591)],
            nutrition: .init(calories: 140, carbs: 36)
        ),
        DrinkSeed(
            key: "electrolyteDrink",
            name: "Electrolyte Drink",
            symbol: "stickpack.fill",
            tint: .pink,
            servingUnit: "serving",
            sizes: [.init(name: "Bottle", volumeML: 500)]
        ),
        DrinkSeed(
            key: "beer",
            name: "Beer",
            symbol: "beerstein.fill",
            tint: .yellow,
            servingUnit: "serving",
            sizes: [.init(name: "Can", volumeML: 355), .init(name: "Pint", volumeML: 473)],
            abv: 5,
            nutrition: .init(calories: 153, protein: 1.6, carbs: 12.6)
        ),
        DrinkSeed(
            key: "wine",
            name: "Wine",
            symbol: "wineglass.fill",
            tint: .wine,
            servingUnit: "serving",
            sizes: [.init(name: "Glass", volumeML: 150)],
            abv: 12,
            nutrition: .init(calories: 115, protein: 0.1, carbs: 3.9)
        ),
        DrinkSeed(
            key: "spirits",
            name: "Spirits",
            symbol: "rocksglass.ice.fill",
            tint: .purple,
            servingUnit: "serving",
            sizes: [.init(name: "Shot", volumeML: 44), .init(name: "Double", volumeML: 88)],
            abv: 40,
            nutrition: .init(calories: 97)
        ),
    ]

    private static let seededListsKey = "AppSeeder.hasSeededLists"

    private static let initialSyncWait: Duration = .seconds(120)

    static func resetListSeeding() {
        UserDefaults.standard.removeObject(forKey: seededListsKey)
    }

    @MainActor
    private static func hasUnseededDrinks(in context: ModelContext) -> Bool {
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        let seeded = users.reduce(into: Set<String>()) { $0.formUnion($1.seededDrinkKeys) }
        return !essentialDrinks.map(\.key).allSatisfy(seeded.contains)
    }

    static let essentialDrinkKeys: Set<String> = ["water", "coffee"]

    static var essentialDrinks: [DrinkSeed] {
        defaultDrinks.filter { essentialDrinkKeys.contains($0.key) }
    }

    static var starterDrinks: [DrinkSeed] {
        defaultDrinks.filter { !essentialDrinkKeys.contains($0.key) }
    }

    @MainActor
    static func seedDefaults(into context: ModelContext, after syncMonitor: CloudSyncMonitor) async {
        if !UserDefaults.standard.bool(forKey: seededListsKey) || hasUnseededDrinks(in: context),
            await syncMonitor.hasSyncedData(timeout: .seconds(10)) == true
        {
            let deadline = ContinuousClock.now + initialSyncWait
            while !syncMonitor.hasFinishedDownloadThisLaunch,
                ContinuousClock.now < deadline || syncMonitor.isInitialRestoreInProgress,
                !Task.isCancelled
            {
                try? await Task.sleep(for: .seconds(1))
            }
        }
        try? seedDefaults(into: context)
    }

    @MainActor
    static func seedDefaults(into context: ModelContext) throws {
        let shouldSeedLists = !UserDefaults.standard.bool(forKey: seededListsKey)

        if shouldSeedLists {
            // --- SEED ENTRY SOURCES ---
            let entryDescriptor = FetchDescriptor<EntrySource>()
            if try context.fetchCount(entryDescriptor) == 0 {
                for (index, source) in defaultEntrySources.enumerated() {
                    let newSource = EntrySource(
                        source: source,
                        isDefault: true,
                        displayOrder: index
                    )
                    context.insert(newSource)
                }
                print("Successfully seeded default EntrySources.")
            }

            // --- SEED CATEGORY SOURCES ---
            let categoryDescriptor = FetchDescriptor<CategorySource>()
            if try context.fetchCount(categoryDescriptor) == 0 {
                for (index, category) in defaultCategorySources.enumerated() {
                    let newCategory = CategorySource(
                        category: category,
                        isDefault: true,
                        displayOrder: index
                    )
                    context.insert(newCategory)
                }
                print("Successfully seeded default CategorySources.")
            }

            // --- SEED FOOD GROUP SOURCES ---
            let foodGroupDescriptor = FetchDescriptor<FoodGroupSource>()
            if try context.fetchCount(foodGroupDescriptor) == 0 {
                for (index, foodGroup) in defaultFoodGroupSources.enumerated() {
                    let newFoodGroup = FoodGroupSource(
                        foodGroup: foodGroup,
                        isDefault: true,
                        displayOrder: index
                    )
                    context.insert(newFoodGroup)
                }
                print("Successfully seeded default FoodGroupSources.")
            }
        }

        // --- SERVING SIZE UNIT SOURCES ---
        let unitDescriptor = FetchDescriptor<ServingSizeUnit>()
        if try context.fetchCount(unitDescriptor) == 0 {
            for (index, unit) in defaultServingSizeUnits.enumerated() {
                let newUnit = ServingSizeUnit(
                    unit: unit,
                    pluralVariant: defaultServingSizePlural[index],
                    isDefault: true,
                    displayOrder: index
                )
                context.insert(newUnit)
            }
            print("Successfully seeded default ServingSizeUnits.")
        }

        try insertDrinks(into: context)

        try context.save()
        UserDefaults.standard.set(true, forKey: seededListsKey)
    }

    @MainActor
    static func seedDrinks(into context: ModelContext) throws {
        try insertDrinks(into: context)
        try context.save()
    }

    @MainActor
    private static func insertDrinks(into context: ModelContext) throws {
        let users = try context.fetch(FetchDescriptor<User>())
        guard !users.isEmpty else { return }
        let alreadySeeded = users.reduce(into: Set<String>()) { $0.formUnion($1.seededDrinkKeys) }
        let pending = essentialDrinks.filter { !alreadySeeded.contains($0.key) }
        guard !pending.isEmpty else { return }

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let existingKeys = Set(foods.compactMap(\.seedKey))
        var nextOrder = (foods.compactMap(\.hydrationOrder).max() ?? -1) + 1
        let units = try context.fetch(FetchDescriptor<ServingSizeUnit>())

        for seed in pending where !existingKeys.contains(seed.key) {
            guard let drink = insertDrink(seed, units: units, into: context) else { continue }
            drink.isInLibrary = false
            if seed.isPinned {
                drink.hydrationOrder = nextOrder
                nextOrder += 1
            }
            print("Successfully seeded default drink \(seed.key).")
        }

        for user in users {
            user.seededDrinkKeys.formUnion(pending.map(\.key))
        }
    }

    @MainActor
    static func storedDrink(for seed: DrinkSeed, in context: ModelContext) throws -> FoodItem? {
        let key = seed.key
        let existing = try context.fetch(
            FetchDescriptor<FoodItem>(predicate: #Predicate { $0.seedKey == key })
        )
        if let drink = existing.first { return drink }
        let units = try context.fetch(FetchDescriptor<ServingSizeUnit>())
        guard let drink = insertDrink(seed, units: units, into: context) else { return nil }
        drink.isInLibrary = false
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return drink
    }

    @MainActor
    @discardableResult
    private static func insertDrink(
        _ seed: DrinkSeed,
        units: [ServingSizeUnit],
        into context: ModelContext
    ) -> FoodItem? {
        guard let drink = makeDrink(seed, servingUnit: units.first { $0.unit == seed.servingUnit }) else {
            return nil
        }
        context.insert(drink)
        drink.seedKey = seed.key
        for (index, seedSize) in seed.sizes.enumerated() {
            let size = DrinkSize(
                name: seedSize.name,
                volumeML: seedSize.volumeML,
                displayOrder: index,
                isDefault: index == 0
            )
            context.insert(size)
            size.food = drink
        }
        return drink
    }

    static func previewDrink(for seed: DrinkSeed) -> FoodItem? {
        guard let drink = makeDrink(seed, servingUnit: nil) else { return nil }
        drink.drinkSizes = seed.sizes.enumerated().map { index, seedSize in
            DrinkSize(name: seedSize.name, volumeML: seedSize.volumeML, displayOrder: index, isDefault: index == 0)
        }
        return drink
    }

    private static func makeDrink(_ seed: DrinkSeed, servingUnit: ServingSizeUnit?) -> FoodItem? {
        guard let defaultSize = seed.sizes.first else { return nil }
        let drink = FoodItem(
            name: seed.name,
            type: .drink,
            servingSize: 1,
            servingUnit: servingUnit,
            servingWeight: defaultSize.volumeML,
            servingWeightUnit: VolumeUnit.milliliters.rawValue,
            isAIEstimated: false,
            calories: seed.nutrition?.calories ?? 0,
            protein: seed.nutrition?.protein ?? 0,
            carbs: seed.nutrition?.carbs ?? 0,
            fat: seed.nutrition?.fat ?? 0,
            fiber: seed.nutrition?.fiber ?? 0,
            isCustomDefaultServing: false
        )
        drink.symbol = seed.symbol
        drink.tintRawValue = seed.tint.rawValue
        drink.caffeineMg = seed.caffeineMg
        drink.abv = seed.abv
        drink.hasNutrition = seed.nutrition != nil
        return drink
    }
}
