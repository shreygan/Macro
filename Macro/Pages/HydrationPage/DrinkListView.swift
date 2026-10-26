//
//  DrinkListView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftData
import SwiftUI

private struct PinnedDrink: Identifiable {
    let id: UUID
    let food: FoodItem
}

extension FoodItem {
    func drinkAmountText(unit: VolumeUnit) -> String? {
        if let size = defaultDrinkSize {
            let amount = unit.formattedAmount(size.volumeML)
            guard let name = size.name, !name.isEmpty else { return amount }
            return "\(name) · \(amount)"
        }
        return servingVolumeML.map(unit.formattedAmount)
    }

    @MainActor
    static func pinToLogDrink(_ food: FoodItem, in context: ModelContext) {
        guard food.hydrationOrder == nil else { return }
        let pinned = (try? context.fetch(FetchDescriptor<FoodItem>(predicate: #Predicate { $0.hydrationOrder != nil }))) ?? []
        food.hydrationOrder = (pinned.compactMap(\.hydrationOrder).max() ?? -1) + 1
    }
}

struct DrinkListView: View {
    enum Mode {
        case manage
        case choose(selectedID: UUID?, onSelect: (FoodItem) -> Void)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    @Query private var users: [User]
    @Query(FoodItem.drinksDescriptor) private var allDrinks: [FoodItem]

    let mode: Mode
    var isPushed = false
    var allowsDelete = true

    @State private var pinned: [PinnedDrink] = []
    @State private var query = ""
    @State private var focusManager = SwipeFocusManager()
    @State private var foodToShow: FoodItem?
    @State private var showNewDrink = false
    @State private var foodToEdit: FoodItem?
    @State private var foodToDelete: FoodItem?
    @State private var deletingID: UUID?
    @State private var orderSaveTask: Task<Void, Never>?
    @State private var storedBuiltInIDs: Set<UUID> = []

    private var isManaging: Bool {
        if case .manage = mode { return true }
        return false
    }

    private var selectedID: UUID? {
        if case .choose(let selectedID, _) = mode { return selectedID }
        return nil
    }

    private var unit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var drinks: [FoodItem] {
        isManaging ? allDrinks : allDrinks.filter(\.isLoggableDrink)
    }

    private var matchingDrinks: [FoodItem] {
        guard isSearching else { return drinks }
        let aliases = DrinkAliasSearch(trimmedQuery)
        return drinks.filter { $0.name.localizedStandardContains(trimmedQuery) || aliases.includes($0) }
    }

    private var pinnedFromStore: [PinnedDrink] {
        drinks
            .filter { $0.hydrationOrder != nil }
            .sorted { ($0.hydrationOrder ?? 0, $0.name) < ($1.hydrationOrder ?? 0, $1.name) }
            .map { PinnedDrink(id: $0.id, food: $0) }
    }

    private var matchingPinned: [FoodItem] {
        let matches = Set(matchingDrinks.map(\.id))
        return pinnedFromStore.map(\.food).filter { matches.contains($0.id) }
    }

    private var otherDrinks: [FoodItem] {
        matchingDrinks.filter { $0.hydrationOrder == nil && ($0.seedKey == nil || $0.isInLibrary) }
    }

    private var builtIns: [FoodItem] {
        BuiltInCatalog.items(stored: allDrinks, type: .drink)
            .filter { $0.hydrationOrder == nil && $0.isLoggableDrink }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var matchingBuiltIns: [FoodItem] {
        guard isSearching else { return builtIns }
        let aliases = DrinkAliasSearch(trimmedQuery)
        return builtIns.filter { $0.name.localizedStandardContains(trimmedQuery) || aliases.includes($0) }
    }

    private var showsPinnedCard: Bool {
        !isSearching || !matchingPinned.isEmpty
    }

    private var reordersPinned: Bool {
        !isSearching
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Changes")))
        }
    }

    private func scheduleOrderSave() {
        orderSaveTask?.cancel()
        orderSaveTask = Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            persistOrder()
        }
    }

    private func flushPendingOrder() {
        guard orderSaveTask != nil else { return }
        persistOrder()
    }

    private func persistOrder() {
        orderSaveTask?.cancel()
        orderSaveTask = nil
        for (index, item) in pinned.enumerated() where item.food.hydrationOrder != index {
            item.food.hydrationOrder = index
        }
        save()
    }

    private func unpin(_ food: FoodItem) {
        withAnimation(.snappy) {
            pinned.removeAll { $0.id == food.id }
            food.hydrationOrder = nil
            persistOrder()
        }
    }

    private func delete(_ food: FoodItem) {
        flushPendingOrder()
        deletingID = food.id
        foodToDelete = food
    }

    private func pin(_ food: FoodItem) {
        flushPendingOrder()
        guard let food = stored(food) else { return }
        storedBuiltInIDs.remove(food.id)
        withAnimation(.snappy) {
            FoodItem.pinToLogDrink(food, in: modelContext)
            pinned = pinnedFromStore
            save()
        }
    }

    private func tap(_ food: FoodItem) {
        switch mode {
        case .manage:
            flushPendingOrder()
            foodToShow = stored(food)
        case .choose(_, let onSelect):
            onSelect(food)
            dismiss()
        }
    }

    private func stored(_ food: FoodItem) -> FoodItem? {
        guard !BuiltInCatalog.isStored(food) else { return food }
        do {
            let stored = try BuiltInCatalog.stored(food, in: modelContext)
            storedBuiltInIDs.insert(stored.id)
            return stored
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Open \(food.name)")))
            return nil
        }
    }

    private func discardIfUnused(_ food: FoodItem) {
        guard storedBuiltInIDs.remove(food.id) != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            BuiltInCatalog.discardIfUnused(food, in: modelContext)
        }
    }

    private func newDrink() {
        flushPendingOrder()
        showNewDrink = true
    }

    var body: some View {
        Group {
            if isPushed {
                list
            } else {
                NavigationStack {
                    list
                }
                .presentationDetents([.large])
            }
        }
        .environment(focusManager)
        .onAppear { pinned = pinnedFromStore }
        .onDisappear { flushPendingOrder() }
        .onChange(of: pinnedFromStore.map(\.id)) { _, ids in
            if ids != pinned.map(\.id) {
                pinned = pinnedFromStore
            }
        }
        .onChange(of: pinned.map(\.id)) { _, ids in
            if ids != pinnedFromStore.map(\.id) {
                scheduleOrderSave()
            }
        }
        .sheet(isPresented: $showNewDrink) {
            if case .choose = mode {
                AddEntryView(entryType: .drink, onSelectInstantly: tap, pinsDrink: true)
            } else {
                AddEntryView(entryType: .drink, pinsDrink: true, onCreate: { _ in })
            }
        }
        .sheet(item: $foodToEdit) { food in
            EditEntryView(foodItem: food)
        }
        .deleteFoodAlert(food: $foodToDelete) {
            withAnimation(.snappy) {
                pinned.removeAll { $0.id == deletingID }
            }
            deletingID = nil
        }
    }

    private var list: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack {
                    if showsPinnedCard {
                        Card(String(localized: "Pinned"), titleBottomPadding: 4) {
                            pinnedContent
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }

                    if !otherDrinks.isEmpty {
                        Card(String(localized: "Other Drinks"), titleBottomPadding: 4) {
                            VStack(spacing: 0) {
                                ForEach(otherDrinks) { food in
                                    if food.id != otherDrinks.first?.id {
                                        Divider().padding(.horizontal, 16)
                                    }
                                    drinkRow(food, isPinned: false)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.bottom, 6)
                        }
                        .padding(showsPinnedCard ? [.top, .horizontal] : [.horizontal])
                        .transition(.opacity)
                    }

                    if !matchingBuiltIns.isEmpty {
                        Card(String(localized: "Built-In"), titleBottomPadding: 4) {
                            VStack(spacing: 0) {
                                ForEach(matchingBuiltIns) { food in
                                    if food.id != matchingBuiltIns.first?.id {
                                        Divider().padding(.horizontal, 16)
                                    }
                                    builtInRow(food)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.bottom, 6)
                        }
                        .padding(showsPinnedCard || !otherDrinks.isEmpty ? [.top, .horizontal] : [.horizontal])
                        .transition(.opacity)
                    }

                    if isSearching && matchingDrinks.isEmpty && matchingBuiltIns.isEmpty {
                        ContentUnavailableView.search(text: trimmedQuery)
                            .padding(.top, 40)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.25), value: isSearching)
                .animation(.easeInOut(duration: 0.25), value: matchingDrinks.isEmpty && matchingBuiltIns.isEmpty)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: matchingDrinks.map(\.id))
                .animation(.snappy, value: otherDrinks.map(\.id))
                .animation(.snappy, value: matchingBuiltIns.map(\.id))
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle(isManaging ? "Manage Drinks" : "All Drinks")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Drinks"
        )
        .toolbar {
            if !isPushed {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newDrink()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Drink")
            }
        }
        .navigationDestination(item: $foodToShow) { food in
            FoodDetailView(food: food)
        }
        .onChange(of: foodToEdit) { oldFood, newFood in
            if newFood == nil, let oldFood {
                discardIfUnused(oldFood)
            }
        }
        .onChange(of: foodToShow) { oldFood, newFood in
            if newFood == nil, let oldFood {
                discardIfUnused(oldFood)
            }
        }
    }

    @ViewBuilder
    private var pinnedContent: some View {
        if !isSearching && pinned.isEmpty {
            Text("No pinned drinks.")
                .font(.compactTitle)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        }

        if reordersPinned {
            ReorderableRows(
                items: $pinned,
                insertion: .opacity.combined(with: .scale(scale: 0.9))
            ) { $item in
                swipeRow(item.food, isPinned: true)
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                ForEach(matchingPinned) { food in
                    if food.id != matchingPinned.first?.id {
                        Divider().padding(.horizontal, 16)
                    }
                    drinkRow(food, isPinned: true)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, isSearching ? 6 : 0)
            .transition(.opacity)
        }

        if !isSearching {
            ButtonRow(
                icon: .customSymbol("plus.circle.fill"),
                title: String(localized: "New Drink")
            ) {
                newDrink()
            }
            .transition(.opacity)
        }
    }

    private func drinkRow(_ food: FoodItem, isPinned: Bool) -> some View {
        swipeRow(food, isPinned: isPinned)
    }

    private func builtInRow(_ food: FoodItem) -> some View {
        CustomSwipeRow(
            content: { rowContent(food) },
            onEdit: {
                flushPendingOrder()
                foodToEdit = stored(food)
            },
            onPin: { pin(food) },
            isPinned: false
        )
    }

    private func swipeRow(_ food: FoodItem, isPinned: Bool) -> some View {
        CustomSwipeRow(
            content: { rowContent(food) },
            onDelete: allowsDelete ? { delete(food) } : nil,
            onEdit: {
                flushPendingOrder()
                foodToEdit = food
            },
            onPin: isPinned || food.isLoggableDrink
                ? { isPinned ? unpin(food) : pin(food) } : nil,
            isPinned: isPinned
        )
    }

    private func rowContent(_ food: FoodItem) -> some View {
        BaseRowLayout(
            icon: .customSymbol(food.drinkSymbol, tint: food.drinkTint.color),
            title: food.name,
            subtitle: food.isLoggableDrink
                ? food.drinkAmountText(unit: unit)
                : String(localized: "No serving volume")
        ) {
            if let alias = DrinkAliasSearch(trimmedQuery).alias(for: food) {
                AliasNote(alias: alias)
            }
            if food.id == selectedID {
                Image(systemName: "checkmark")
                    .font(.menuIcon)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tap(food) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(food.id == selectedID ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { tap(food) }
    }
}

#Preview("Manage") {
    DrinkListView(mode: .manage)
        .modelContainer(DrinkListView.previewContainer())
}

#Preview("Choose") {
    let container = DrinkListView.previewContainer()
    let water = (try? container.mainContext.fetch(FetchDescriptor<FoodItem>()))?.first { $0.seedKey == "water" }

    return DrinkListView(mode: .choose(selectedID: water?.id, onSelect: { _ in }))
        .modelContainer(container)
}

extension DrinkListView {
    static func previewContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        container.mainContext.insert(User(onboardingComplete: true))
        AppSeeder.resetListSeeding()
        try? AppSeeder.seedDefaults(into: container.mainContext)
        if let latte = AppSeeder.starterDrinks.first(where: { $0.key == "latte" }),
            let drink = try? AppSeeder.storedDrink(for: latte, in: container.mainContext)
        {
            drink.isInLibrary = true
        }
        let shake = FoodItem(
            name: "Protein Shake",
            type: .drink,
            servingSize: 1,
            servingWeight: 330,
            servingWeightUnit: "ml",
            isAIEstimated: false,
            calories: 160,
            protein: 30,
            carbs: 6,
            fat: 2,
            fiber: 0,
            isCustomDefaultServing: false
        )
        shake.symbol = "dumbbell.fill"
        shake.tintRawValue = DrinkTint.purple.rawValue
        container.mainContext.insert(shake)
        return container
    }
}
