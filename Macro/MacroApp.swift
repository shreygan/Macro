//
//  MacroApp.swift
//  Macro
//
//  Created by Shrey Gangwar on 4/14/26.
//

import SwiftData
import SwiftUI

@main
struct MacroApp: App {
    static let defaultEntrySources = ["Home", "Work"]
    static let defaultCategorySources = [
        "Meal", "Snack", "Breakfast", "Lunch", "Dinner", "Dessert",
    ]
    static let defaultServingSizeUnits = ["serving", "cup", "piece", "slice", "oz", "container", "bar"]
    static let defaultServingSizePlural = ["servings", "cups", "pieces", "slices", nil, "containers", "bars"]

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            EntrySource.self,
            CategorySource.self,
            ServingSizeUnit.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            let context = ModelContext(container)

            // --- SEED ENTRY SOURCES ---
            let entryDescriptor = FetchDescriptor<EntrySource>()
            let existingEntryCount = try context.fetchCount(entryDescriptor)

            if existingEntryCount == 0 {
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
            let existingCategoryCount = try context.fetchCount(
                categoryDescriptor
            )

            if existingCategoryCount == 0 {
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
            
            // --- SERVING SIZE UNIT SOURCES ---
            let unitDescriptor = FetchDescriptor<ServingSizeUnit>()
            let existingUnitCount = try context.fetchCount(
                unitDescriptor
            )

            if existingUnitCount == 0 {
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

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            //            WelcomeView()
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
