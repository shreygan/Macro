//
//  StorageView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/16/26.
//

import SwiftData
import SwiftUI

struct StorageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    @State private var counts: StorageCounts?
    @State private var sizes: StoreDiskUsage?

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    sizeCard
                        .padding(.horizontal)

                    libraryCard
                        .padding([.top, .horizontal])

                    logsCard
                        .padding([.top, .horizontal])

                    otherCard
                        .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: syncMonitor.lastDownload) {
            await load()
        }
    }

    private var sizeCard: some View {
        Card(String(localized: "On This \(UIDevice.current.model)")) {
            RowGroup(.divider) {
                sizeRow(
                    "internaldrive",
                    "Total",
                    sizes?.total,
                    info: String(localized: "Space Macro's data takes up on this \(UIDevice.current.model). Backups leave out the sync history, so they're usually smaller.")
                )
                sizeRow("photo.on.rectangle", "Photos", sizes?.photos)
                sizeRow(
                    "cylinder.split.1x2",
                    "Database",
                    sizes?.database,
                    info: String(localized: "Your library, logs, goals and settings, plus the history iCloud uses to keep your devices in sync.")
                )
            }
        }
    }

    private var libraryCard: some View {
        Card("Library") {
            RowGroup(.divider) {
                countRow("books.vertical", "Library Entries", counts?.libraryTotal)
                countRow(AppSymbols.food.rawValue, "Foods", counts?.foods)
                countRow(AppSymbols.recipe.rawValue, "Recipes", counts?.recipes)
                countRow(AppSymbols.ingredient.rawValue, "Ingredients", counts?.ingredients)
                countRow(AppSymbols.drink.rawValue, "Drinks", counts?.drinks)
                countRow("star", "Favorites", counts?.favorites)
                countRow("note.text", "Food Notes", counts?.foodNotes)
            }
        }
    }

    private var logsCard: some View {
        Card("Logs") {
            RowGroup(.divider) {
                countRow("list.bullet.rectangle", "Logs", counts?.logs)
                countRow("calendar", "Days Logged", counts?.daysLogged)
                valueRow(
                    "calendar.badge.clock",
                    "Logging Since",
                    counts.map { $0.firstLog?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "None") }
                )
                countRow("photo.on.rectangle", "Log Photos", counts?.logPhotos)
            }
        }
    }

    private var otherCard: some View {
        Card("Other") {
            RowGroup(.divider) {
                countRow("square.and.pencil", "Drafts", counts?.drafts)
                countRow("photo.on.rectangle", "Draft Photos", counts?.draftPhotos)
                countRow("target", "Goals", counts?.goals)
                countRow("mappin.and.ellipse", "Saved Locations", counts?.savedLocations)
                countRow("clock.arrow.circlepath", "Recent Locations", counts?.recentLocations)
                countRow("tag", "Custom List Items", counts?.customListItems)
            }
        }
    }

    private func sizeRow(_ symbol: String, _ title: String, _ bytes: Int64?, info: String? = nil) -> some View {
        valueRow(symbol, title, bytes.map { $0.formatted(.byteCount(style: .file)) }, info: info)
    }

    private func countRow(_ symbol: String, _ title: String, _ count: Int?) -> some View {
        valueRow(symbol, title, count.map { $0.formatted() })
    }

    private func valueRow(_ symbol: String, _ title: String, _ value: String?, info: String? = nil) -> some View {
        BaseRowLayout(icon: .customSymbol(symbol), title: title, info: info, fitsRightContent: true) {
            ZStack(alignment: .trailing) {
                if let value {
                    Text(value)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: value)
        }
    }

    private func load() async {
        counts = StorageCounts(context: modelContext)

        guard let storeURL = modelContext.container.configurations.first?.url else { return }
        let measured = await Task.detached(priority: .userInitiated) {
            StoreDiskUsage(storeURL: storeURL)
        }.value
        guard !Task.isCancelled else { return }
        sizes = measured
    }
}

private struct StorageCounts {
    var foods = 0
    var recipes = 0
    var ingredients = 0
    var drinks = 0
    var favorites = 0
    var foodNotes = 0
    var logs = 0
    var daysLogged = 0
    var firstLog: Date?
    var logPhotos = 0
    var draftPhotos = 0
    var drafts = 0
    var goals = 0
    var savedLocations = 0
    var recentLocations = 0
    var customListItems = 0

    var libraryTotal: Int { foods + recipes + ingredients + drinks }

    init(context: ModelContext) {
        let foodItems = (try? context.fetch(
            FetchDescriptor<FoodItem>(predicate: #Predicate { $0.isInLibrary })
        )) ?? []
        for item in foodItems {
            switch item.type {
            case .food: foods += 1
            case .recipe: recipes += 1
            case .ingredient: ingredients += 1
            case .drink: drinks += 1
            }
        }

        favorites = Self.count(FetchDescriptor<FavoriteEntry>(), in: context)
        foodNotes = Self.count(FetchDescriptor<Note>(), in: context)

        var logDescriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.parentEntry == nil },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        logDescriptor.propertiesToFetch = [\.timestamp]
        let topLevelLogs = (try? context.fetch(logDescriptor)) ?? []
        logs = topLevelLogs.count
        firstLog = topLevelLogs.first?.timestamp

        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        let dayStartMinutes = users.first?.dayStartMinutes ?? 0
        let calendar = Calendar.current
        daysLogged = Set(topLevelLogs.map { calendar.logicalDay(for: $0.timestamp, dayStartMinutes: dayStartMinutes) }).count
        goals = users.reduce(0) { $0 + ($1.goalsHistory?.count ?? 0) }

        logPhotos = Self.count(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.parentEntry != nil }), in: context)
        draftPhotos = Self.count(FetchDescriptor<EntryPhoto>(predicate: #Predicate { $0.parentDraft != nil }), in: context)
        drafts = Self.count(FetchDescriptor<EntryDraft>(), in: context)
        savedLocations = Self.count(FetchDescriptor<SavedLocation>(), in: context)
        recentLocations = Self.count(FetchDescriptor<RecentLocation>(), in: context)

        customListItems =
            Self.count(FetchDescriptor<EntrySource>(predicate: #Predicate { !$0.isDefault }), in: context)
            + Self.count(FetchDescriptor<CategorySource>(predicate: #Predicate { !$0.isDefault }), in: context)
            + Self.count(FetchDescriptor<FoodGroupSource>(predicate: #Predicate { !$0.isDefault }), in: context)
            + Self.count(FetchDescriptor<ServingSizeUnit>(predicate: #Predicate { !$0.isDefault }), in: context)
    }

    private static func count<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> Int {
        (try? context.fetchCount(descriptor)) ?? 0
    }
}

#Preview {
    NavigationStack {
        StorageView()
    }
    .environment(CloudSyncMonitor())
    .modelContainer(
        try! ModelContainer(
            for: User.self, FoodItem.self, LoggedEntry.self, SavedLocation.self, RecentLocation.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    )
}
