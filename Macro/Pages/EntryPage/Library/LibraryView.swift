//
//  LibraryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import SwiftData
import SwiftUI

enum FoodSortOption {
    case name
    case dateAdded
    case lastLogged
    case mostLogged
    case calories
    case protein
    case carbs
    case fat
    case fiber
}

enum LibraryChip: Hashable {
    case all
    case favorites
    case type(EntryType)

    static let allChips: [LibraryChip] =
        [.all, .favorites]
        + [EntryType.ingredient, .food, .recipe, .drink].map { .type($0) }

    var title: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .type(let type): return "\(type.rawValue.capitalized)s"
        }
    }

    var symbol: String {
        switch self {
        case .all: return AppSymbols.all.rawValue
        case .favorites: return "star.fill"
        case .type(let type): return type.appSymbol.rawValue
        }
    }
}

nonisolated enum SwipeAction: Hashable, Sendable {
    case edit, delete, favorite
}

struct LibraryView<Header: View>: View {
    @Environment(\.modelContext) private var modelContext

    var title: String
    var searchPrompt: String
    var swipeActions: Set<SwipeAction>
    var onSelect: ((FoodItem) -> Void)? = nil
    var defaultType: LibraryFilterType
    var isTabRoot: Bool
    var popToRootTrigger: Int
    let headerContent: Header

    @Query(sort: \FoodItem.dateAdded, order: .reverse) var savedMeals:
        [FoodItem]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]
    @Query private var sourceOptions: [EntrySource]
    @Query private var categoryOptions: [CategorySource]

    @State private var selectedChip: LibraryChip = .all
    @State private var listToManage: LibraryListKind? = nil
    @Environment(\.tabBarHeight) private var tabBarHeight

    @State private var foodToLog: FoodItem? = nil

    @State private var selectedFood: FoodItem?
    @State private var searchText = ""

    @State private var sortOption: FoodSortOption = .dateAdded
    @State private var sortDescending: Bool = true
    @State private var logStats: [UUID: FoodLogStats] = [:]

    @State private var showFilterSheet = false
    @State private var selectedTypes: Set<String>
    @State private var selectedSources: Set<String> = []
    @State private var selectedCategories: Set<String> = []

    @State private var showDeleteAlert = false
    @State private var foodToDelete: FoodItem?

    @State private var foodToEdit: FoodItem?

    @State private var entryTypeToAdd: EntryType?
    @State private var newEntryName = ""

    private var addableEntryType: EntryType {
        guard selectedTypes.count == 1,
            let singleType = selectedTypes.first,
            let type = EntryType(rawValue: singleType.lowercased())
        else {
            return .food
        }
        return type
    }

    private var dynamicTitle: String {
        if !isTabRoot, selectedTypes.count == 1,
            let singleType = selectedTypes.first
        {
            return "\(singleType)s"
        }
        return title
    }

    private var usesLogStats: Bool {
        sortOption == .lastLogged || sortOption == .mostLogged
    }

    private var hasListFilters: Bool {
        !selectedSources.isEmpty || !selectedCategories.isEmpty
    }

    var filteredFoods: [FoodItem] {
        // 1. Search text filter
        var result =
            searchText.isEmpty
            ? savedMeals
            : savedMeals.filter { food in
                food.name.localizedStandardContains(searchText)
                    || (food.source?.source.localizedStandardContains(
                        searchText
                    ) ?? false)
            }

        // 2. Type filter
        if !selectedTypes.isEmpty {
            result = result.filter { food in
                return selectedTypes.contains(food.type.rawValue.capitalized)
            }
        }

        // 3. Source filter
        if !selectedSources.isEmpty {
            result = result.filter { food in
                guard let sourceName = food.source?.source else { return false }
                return selectedSources.contains(sourceName)
            }
        }

        // 4. Category filter
        if !selectedCategories.isEmpty {
            result = result.filter { food in
                guard let categoryName = food.category?.category else {
                    return false
                }
                return selectedCategories.contains(categoryName)
            }
        }

        if selectedChip == .favorites {
            result = result.filter { $0.favoriteEntry != nil }
        }

        // 5. Sort filtered results
        let stats = logStats

        return result.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name)
                    == .orderedAscending
            case .dateAdded:
                return sortDescending
                    ? lhs.dateAdded > rhs.dateAdded
                    : lhs.dateAdded < rhs.dateAdded
            case .lastLogged:
                let lhsDate = stats[lhs.id]?.lastLogged ?? .distantPast
                let rhsDate = stats[rhs.id]?.lastLogged ?? .distantPast
                return sortDescending ? lhsDate > rhsDate : lhsDate < rhsDate
            case .mostLogged:
                let lhsCount = stats[lhs.id]?.count ?? 0
                let rhsCount = stats[rhs.id]?.count ?? 0
                if lhsCount == rhsCount {
                    return lhs.name.localizedStandardCompare(rhs.name)
                        == .orderedAscending
                }
                return sortDescending
                    ? lhsCount > rhsCount : lhsCount < rhsCount
            case .calories:
                return sortDescending
                    ? lhs.calories > rhs.calories : lhs.calories < rhs.calories
            case .protein:
                return sortDescending
                    ? lhs.protein > rhs.protein : lhs.protein < rhs.protein
            case .carbs:
                return sortDescending
                    ? lhs.carbs > rhs.carbs : lhs.carbs < rhs.carbs
            case .fat:
                return sortDescending ? lhs.fat > rhs.fat : lhs.fat < rhs.fat
            case .fiber:
                return sortDescending
                    ? lhs.fiber > rhs.fiber : lhs.fiber < rhs.fiber
            }
        }
    }

    init(
        title: String = "Library",
        searchPrompt: String = "What did you eat today?",
        defaultType: LibraryFilterType = .all,
        swipeActions: Set<SwipeAction> = [.edit, .delete, .favorite],
        isTabRoot: Bool = false,
        popToRootTrigger: Int = 0,
        onSelect: ((FoodItem) -> Void)? = nil,
        @ViewBuilder headerContent: () -> Header = { EmptyView() }
    ) {
        self.title = title
        self.searchPrompt = searchPrompt
        self.defaultType = defaultType
        self.isTabRoot = isTabRoot
        self.popToRootTrigger = popToRootTrigger
        self.swipeActions = swipeActions
        self.onSelect = onSelect
        self.headerContent = headerContent()

        let initialTypes: Set<String> =
            defaultType == .all ? [] : [defaultType.displayName]
        self._selectedTypes = State(initialValue: initialTypes)
    }

    var body: some View {
        let foods = filteredFoods

        ZStack {
            (isTabRoot ? Color.clear : Color.background)
                .ignoresSafeArea()

            if foods.isEmpty {
                VStack(spacing: 0) {
                    headerContent
                        .padding([.horizontal, .bottom])

                    emptyStateView
                }
                .transition(.opacity)
                .zIndex(1)

            } else {
                ScrollView {
                    VStack {
                        headerContent
                            .padding([.horizontal, .bottom])

                        EntryList(
                            items: foods,
                            allowSwipeActions: !swipeActions.isEmpty,
                            rowContent: { food in
                                if isTabRoot {
                                    foodRow(for: food)
                                        .contextMenu {
                                            FoodActionMenuItems(
                                                food: food,
                                                onLog: { foodToLog = food },
                                                onEdit: { foodToEdit = food },
                                                onDelete: {
                                                    confirmDelete(food)
                                                }
                                            )
                                        }
                                } else {
                                    foodRow(for: food)
                                }
                            },
                            onDelete: swipeActions.contains(.delete)
                                ? { food in
                                    confirmDelete(food)
                                } : nil,
                            onEdit: swipeActions.contains(.edit)
                                ? { food in
                                    foodToEdit = food
                                } : nil,
                            onFavorite: swipeActions.contains(.favorite)
                                ? { food in
                                    FoodItemStore.toggleFavorite(
                                        food,
                                        in: modelContext
                                    )
                                } : nil,
                            isFavorited: { food in
                                food.favoriteEntry != nil
                            }
                        )
                        .padding([.horizontal, .bottom])
                    }
                }
                .contentMargins(
                    .bottom,
                    tabBarHeight > 0 ? tabBarHeight + 12 : 0,
                    for: .scrollContent
                )
                .contentMargins(.bottom, tabBarHeight, for: .scrollIndicators)
                .ignoresSafeArea(edges: tabBarHeight > 0 ? .bottom : [])
                .id(selectedChip)
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .withGlobalSwipeDismissal()
        .animation(.easeInOut(duration: 0.25), value: foods.isEmpty)
        .navigationTitle(dynamicTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaBar(edge: .top) {
            if isTabRoot {
                chipsBar
            }
        }
        .searchable(
            text: $searchText,
            placement: isTabRoot
                ? .navigationBarDrawer(displayMode: .always) : .automatic,
            prompt: searchPrompt
        )
        .searchDictationBehavior(.automatic)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .navigationDestination(item: $selectedFood) { food in
            if isTabRoot {
                FoodDetailView(food: food)
            } else if food.type == .recipe {
                LogRecipeView(recipe: food)
            } else {
                LogEntryView(food: food)
            }
        }
        .navigationDestination(item: $listToManage) { kind in
            ManageListView(kind: kind)
        }
        .onAppear(perform: refreshLogStats)
        .onChange(of: usesLogStats) {
            refreshLogStats()
        }
        .onChange(of: popToRootTrigger) {
            selectedFood = nil
            listToManage = nil
        }
        .onChange(of: sourceOptions.map(\.source)) { _, names in
            selectedSources.formIntersection(names)
        }
        .onChange(of: categoryOptions.map(\.category)) { _, names in
            selectedCategories.formIntersection(names)
        }
        .sheet(item: $foodToLog, onDismiss: refreshLogStats) { food in
            LogFoodSheet(food: food)
        }
        .sheet(item: $foodToEdit) { food in
            if food.type == .recipe {
                EditRecipeView(recipe: food)
            } else {
                EditEntryView(foodItem: food)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { entryTypeToAdd != nil },
                set: { if !$0 { entryTypeToAdd = nil } }
            ),
            onDismiss: { newEntryName = "" }
        ) {
            if let type = entryTypeToAdd {
                addEntrySheet(for: type)
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterView(
                selectedTypes: $selectedTypes,
                selectedSources: $selectedSources,
                selectedCategories: $selectedCategories,
                defaultType: defaultType,
                showsTypeFilter: !isTabRoot
            )
            .presentationDetents([.height(isTabRoot ? 250 : 350)])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterButton
                sortMenu
                if isTabRoot {
                    manageMenu
                }
            }
        }
        .deleteFoodAlert(isPresented: $showDeleteAlert, food: $foodToDelete)
    }

    private func foodRow(for food: FoodItem) -> some View {
        MealRow(
            food: food,
            servingUnits: portionUnitOptions,
            icon: selectedTypes.count != 1 ? food.type.appSymbol : nil
        ) {
            handleSelect(food)
        }
    }

    private func handleSelect(_ food: FoodItem) {
        if let onSelect = onSelect {
            onSelect(food)
        } else {
            selectedFood = food
        }
    }

    private func refreshLogStats() {
        logStats = usesLogStats ? FoodItemStore.logStats(in: modelContext) : [:]
    }

    private func confirmDelete(_ food: FoodItem) {
        foodToDelete = food
        showDeleteAlert = true
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if searchText.isEmpty && hasListFilters {
            ContentUnavailableView {
                Label(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            } description: {
                Text("No items match the selected filters.")
                    .font(.subheadline)
            } actions: {
                Button("Clear Filters") {
                    withAnimation {
                        selectedSources.removeAll()
                        selectedCategories.removeAll()
                    }
                }
                .tint(.blue)
            }
        } else if selectedChip == .favorites && searchText.isEmpty {
            ContentUnavailableView(
                "No Favorites",
                systemImage: "star",
                description: Text(
                    "Swipe on an item and tap the star to add it to your favorites."
                )
                .font(.subheadline)
            )
        } else {
            typeEmptyStateView
        }
    }

    @ViewBuilder
    private var typeEmptyStateView: some View {
        let singleType = selectedTypes.count == 1 ? selectedTypes.first : nil
        let itemName = singleType?.lowercased() ?? "item"
        let symbolName =
            singleType.flatMap { AppSymbols.from($0)?.rawValue }
            ?? "magnifyingglass"

        ContentUnavailableView {
            if !searchText.isEmpty {
                Label(
                    singleType.map { "No \($0)s match \"\(searchText)\"" }
                        ?? "No Results for \"\(searchText)\"",
                    systemImage: symbolName
                )
            } else if let type = singleType {
                Label("No \(type)s", systemImage: symbolName)
            } else {
                Label("Library is Empty", systemImage: symbolName)
            }
        } description: {
            Group {
                if !searchText.isEmpty {
                    Text("Try a new search or create a new \(itemName).")
                } else if let type = singleType {
                    let descriptionKey = type.lowercased() + "_description"
                    Text(LocalizedStringKey(descriptionKey))
                } else {
                    Text("Add some items to your library to get started.")
                }
            }
            .font(.subheadline)
        } actions: {
            if !searchText.isEmpty {
                Button("Create New \(singleType ?? "Food")") {
                    newEntryName = searchText
                    entryTypeToAdd = addableEntryType
                }
                .tint(.blue)
            } else if let type = singleType {
                Button("Add \(type)") { entryTypeToAdd = addableEntryType }
                    .tint(.blue)
            } else {
                Button("Add Food") { entryTypeToAdd = .food }
                    .tint(.blue)
            }
        }
    }

    @ViewBuilder
    private func addEntrySheet(for type: EntryType) -> some View {
        if type == .recipe {
            AddRecipeView(prefill: .named(newEntryName))
        } else {
            AddEntryView(
                entryType: type,
                onSelectInstantly: onSelect.map { select in
                    { food in
                        entryTypeToAdd = nil
                        select(food)
                    }
                },
                prefill: .named(newEntryName)
            )
        }
    }

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            let defaultTypesSet: Set<String> =
                defaultType == .all ? [] : [defaultType.displayName]
            let hasFilters =
                (!isTabRoot && selectedTypes != defaultTypesSet)
                || hasListFilters
            Image(
                systemName: hasFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .tint(.primary)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                Text("Name").tag(FoodSortOption.name)
                Text("Date Added").tag(FoodSortOption.dateAdded)
                if isTabRoot {
                    Text("Recently Logged").tag(FoodSortOption.lastLogged)
                    Text("Most Logged").tag(FoodSortOption.mostLogged)
                }
                Text("Calories").tag(FoodSortOption.calories)
                Text("Protein").tag(FoodSortOption.protein)
                Text("Carbohydrates").tag(FoodSortOption.carbs)
                Text("Fat").tag(FoodSortOption.fat)
                Text("Fiber").tag(FoodSortOption.fiber)
            }
            if sortOption != .name {
                Divider()
                Picker("Order", selection: $sortDescending) {
                    if sortOption == .dateAdded || sortOption == .lastLogged {
                        Text("Newest First").tag(true)
                        Text("Oldest First").tag(false)
                    } else if sortOption == .mostLogged {
                        Text("Most First").tag(true)
                        Text("Least First").tag(false)
                    } else {
                        Text("Highest First").tag(true)
                        Text("Lowest First").tag(false)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var manageMenu: some View {
        Menu {
            ForEach(LibraryListKind.allCases) { kind in
                Button {
                    listToManage = kind
                } label: {
                    Label("Edit \(kind.title)", systemImage: kind.symbol)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    private var chipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryChip.allChips, id: \.self) { chip in
                    let isSelected = selectedChip == chip

                    Button {
                        withAnimation(.snappy) {
                            selectedChip = chip
                            if case .type(let type) = chip {
                                selectedTypes = [type.rawValue.capitalized]
                            } else {
                                selectedTypes = []
                            }
                        }
                    } label: {
                        Label(chip.title, systemImage: chip.symbol)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.15)
                            )
                            .foregroundStyle(
                                isSelected ? Color.white : Color.primary
                            )
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try ModelContainer(
            for: FoodItem.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let sampleFoods = [
            FoodItem(
                name: "Chicken Breast",
                servingSize: 1.0,
                servingWeight: 100,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 165,
                protein: 31,
                carbs: 0,
                fat: 3.6,
                fiber: 0.4,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Brown Rice",
                servingSize: 1.0,
                servingWeight: 195,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 216,
                protein: 5,
                carbs: 45,
                fat: 1.8,
                fiber: 3.5,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Avocado",
                servingSize: 0.5,
                servingWeight: 100,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 160,
                protein: 2,
                carbs: 8.5,
                fat: 14.7,
                fiber: 6.7,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Oatmeal",
                servingSize: 1.0,
                servingWeight: 234,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 158,
                protein: 6,
                carbs: 27,
                fat: 3.2,
                fiber: 4,
                isCustomDefaultServing: false
            ),
            FoodItem(
                name: "Scrambled Eggs",
                servingSize: 2.0,
                servingWeight: 122,
                servingWeightUnit: "g",
                isAIEstimated: true,
                calories: 199,
                protein: 14,
                carbs: 2,
                fat: 15,
                fiber: 0,
                isCustomDefaultServing: true,
                customServingSize: 2.0
            ),
        ]

        for food in sampleFoods {
            container.mainContext.insert(food)
        }

        return NavigationStack {
            LibraryView(defaultType: .all, swipeActions: [.delete, .edit])
        }
        .modelContainer(container)

    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
