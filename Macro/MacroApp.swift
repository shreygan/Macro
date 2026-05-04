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
            User.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
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
