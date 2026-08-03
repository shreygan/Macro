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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            FoodGroupSource.self,
            ServingSizeUnit.self,
            FavoriteEntry.self,
            LoggedEntry.self,
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

            Task { @MainActor in
                try AppSeeder.seedDefaults(into: context)
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .textInputAutocapitalization(.never)
        }
        .modelContainer(sharedModelContainer)
    }
}
