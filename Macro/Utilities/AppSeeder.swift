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

    @MainActor
    static func seedDefaults(into context: ModelContext) throws {
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

        try context.save()
    }
}
