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
            EntryDraft.self,
            SavedLocation.self,
            RecentLocation.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.Shreyanka.Macro")
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

    @State private var syncMonitor: CloudSyncMonitor
    @State private var backupStore: CloudBackupStore

    init() {
        MacroBackupFile.removeTemporaryFiles()
        let syncMonitor = CloudSyncMonitor()
        let backupStore = CloudBackupStore()
        _syncMonitor = State(initialValue: syncMonitor)
        _backupStore = State(initialValue: backupStore)
        AutomaticBackup.register(store: backupStore, container: sharedModelContainer, syncMonitor: syncMonitor)
        let context = sharedModelContainer.mainContext
        Task { await AppSeeder.seedDefaults(into: context, after: syncMonitor) }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .textInputAutocapitalization(.never)
                .toastHost()
                .environment(syncMonitor)
                .environment(backupStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
