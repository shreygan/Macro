//
//  LoggedEntryDetailView.swift
//  Macro
//
//  Created by Shrey Gangwar on 8/3/26.
//

import SwiftData
import SwiftUI

struct LoggedEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.toastCenter) private var toastCenter

    let entry: LoggedEntry
    var isPushedView: Bool = true
    var isReadOnly: Bool = false

    @State private var isEditing: Bool = false
    @State private var foodToLogAgain: FoodItem? = nil
    @State private var showAddToLibrary = false
    @State private var foodToView: FoodItem? = nil
    @State private var isDismissing = false

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var foodGroupOptions:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    @State private var name: String
    @State private var sourceSelection: String
    @State private var categorySelection: String
    @State private var foodGroupSelection: String

    @State private var date: Date
    @State private var time: Date
    @State private var location: String

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

    @State private var manualOverrideToggle: Bool

    @State private var calorie: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String

    @State private var stickyNote: String
    @State private var pinnedNoteText: String
    @State private var showingAllNotes: Bool = false

    @State private var selectedPhotos: [LoggedPhoto] = []

    @State private var draftIngredients: [LogRecipeIngredient]
    @State private var showIngredientSelectionSheet = false
    @State private var focusManager = SwipeFocusManager()

    private let baseServingSize: Double
    private let baseServingWeight: Double?
    private let baseServingWeightUnit: String
    private let baseUnit: String

    private let calorieStatic: String
    private let proteinStatic: String
    private let carbsStatic: String
    private let fatStatic: String
    private let fiberStatic: String

    @State private var calorieDynamic: String
    @State private var proteinDynamic: String
    @State private var carbsDynamic: String
    @State private var fatDynamic: String
    @State private var fiberDynamic: String

    init(entry: LoggedEntry, isPushedView: Bool = true, isReadOnly: Bool = false) {
        self.entry = entry
        self.isPushedView = isPushedView
        self.isReadOnly = isReadOnly

        _name = State(initialValue: entry.name)
        _sourceSelection = State(initialValue: entry.source?.source ?? "")
        _categorySelection = State(initialValue: entry.category?.category ?? "")
        _foodGroupSelection = State(
            initialValue: entry.foodGroup?.foodGroup ?? ""
        )

        _date = State(initialValue: entry.timestamp)
        _time = State(initialValue: entry.timestamp)
        _location = State(initialValue: entry.location ?? "")

        _portionQuantity = State(
            initialValue: EntryHelper.format(entry.loggedQuantity)
        )
        _portionUnitSelection = State(initialValue: entry.loggedUnit)

        _manualOverrideToggle = State(initialValue: entry.isManualOverride)

        _calorie = State(initialValue: EntryHelper.format(entry.calories))
        _protein = State(initialValue: EntryHelper.format(entry.protein))
        _carbs = State(initialValue: EntryHelper.format(entry.carbs))
        _fat = State(initialValue: EntryHelper.format(entry.fat))
        _fiber = State(initialValue: EntryHelper.format(entry.fiber))

        _stickyNote = State(initialValue: entry.logNote ?? "")
        _pinnedNoteText = State(
            initialValue: entry.originalFoodItem?.stickyNote?.text ?? ""
        )

        _selectedPhotos = State(
            initialValue: EntryHelper.loggedPhotos(from: entry.photos)
        )

        _draftIngredients = State(
            initialValue: LogRecipeIngredient.makeDrafts(for: entry)
        )

        // Without the original item, the logged portion itself is the base
        // (the fallback macros below are the logged values too)
        let originalFood = entry.originalFoodItem
        self.baseServingSize =
            originalFood?.servingSize
            ?? (entry.loggedQuantity > 0 ? entry.loggedQuantity : 1.0)
        self.baseServingWeight = originalFood?.servingWeight
        self.baseServingWeightUnit = originalFood?.servingWeightUnit ?? "g"
        self.baseUnit = originalFood?.servingUnit?.unit ?? entry.loggedUnit

        let calStr = EntryHelper.format(
            originalFood?.calories ?? entry.calories
        )
        let proStr = EntryHelper.format(originalFood?.protein ?? entry.protein)
        let carbStr = EntryHelper.format(originalFood?.carbs ?? entry.carbs)
        let fatStr = EntryHelper.format(originalFood?.fat ?? entry.fat)
        let fibStr = EntryHelper.format(originalFood?.fiber ?? entry.fiber)

        self.calorieStatic = calStr
        self.proteinStatic = proStr
        self.carbsStatic = carbStr
        self.fatStatic = fatStr
        self.fiberStatic = fibStr

        _calorieDynamic = State(initialValue: calStr)
        _proteinDynamic = State(initialValue: proStr)
        _carbsDynamic = State(initialValue: carbStr)
        _fatDynamic = State(initialValue: fatStr)
        _fiberDynamic = State(initialValue: fibStr)
    }

    private var isRecipe: Bool { entry.entryType == .recipe }

    private var showsNotesCard: Bool {
        isEditing || !stickyNote.isEmpty || !pinnedNoteText.isEmpty
    }

    private var pinnedNoteUpdated: Date? {
        guard let note = entry.originalFoodItem?.stickyNote else {
            return pinnedNoteText.isEmpty ? nil : .now
        }
        return pinnedNoteText == note.text ? note.lastUpdated : .now
    }

    private var shouldShowIngredientIcons: Bool {
        draftIngredients.contains { $0.icon != nil }
    }

    private var totalIngredientCalories: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCalories }
    }
    private var totalIngredientProtein: Double {
        draftIngredients.reduce(0) { $0 + $1.activeProtein }
    }
    private var totalIngredientCarbs: Double {
        draftIngredients.reduce(0) { $0 + $1.activeCarbs }
    }
    private var totalIngredientFat: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFat }
    }
    private var totalIngredientFiber: Double {
        draftIngredients.reduce(0) { $0 + $1.activeFiber }
    }

    private var activeServingWeight: Double? {
        guard isRecipe, baseServingWeight == nil else {
            return baseServingWeight
        }
        let totalWeight = draftIngredients.compactMap { $0.activeWeight }
            .reduce(0, +)
        return totalWeight > 0 ? totalWeight : nil
    }

    var availableUnits: [String] {
        var units: [String] = [baseUnit]
        if activeServingWeight != nil && baseServingWeightUnit != baseUnit {
            units.append(baseServingWeightUnit)
        }
        return units
    }

    private var activeMultiplier: Double {
        let currentPortion = Double(portionQuantity) ?? 0
        let basePortion: Double
        if portionUnitSelection == baseServingWeightUnit,
            let weight = activeServingWeight
        {
            basePortion = weight
        } else {
            basePortion = baseServingSize
        }
        return EntryHelper.calculateMultiplier(
            targetPortion: currentPortion,
            basePortion: basePortion
        )
    }

    private var displayServingSize: String {
        let size = activeMultiplier * baseServingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard let weight = activeServingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
        return scaledWeight.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var isAvailable: Bool {
        !entry.isDeleted && entry.modelContext != nil
    }

    var body: some View {
        if isAvailable {
            content
        } else {
            Color.background
                .ignoresSafeArea()
                .onAppear {
                    guard !isDismissing else { return }
                    isDismissing = true
                    dismiss()
                }
        }
    }

    private var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        RowGroup(.divider) {
                            TextInputRow(
                                title: "Name",
                                placeholder: "-",
                                text: $name,
                                isEnabled: isEditing,
                                maxWidth: nil
                            )
                            .padding(.trailing, 10)

                            DropdownPillRow(
                                title: "Source",
                                options: [""]
                                    + sourceOptions.visibleNames(
                                        keeping: sourceSelection
                                    ),
                                isEnabled: isEditing,
                                selection: $sourceSelection
                            )

                            if entry.entryType == .food || isRecipe {
                                DropdownPillRow(
                                    title: "Category",
                                    options: [""]
                                        + categoryOptions.visibleNames(
                                            keeping: categorySelection
                                        ),
                                    isEnabled: isEditing,
                                    selection: $categorySelection
                                )
                            } else {
                                DropdownPillRow(
                                    title: "Food Group",
                                    options: [""]
                                        + foodGroupOptions.visibleNames(
                                            keeping: foodGroupSelection
                                        ),
                                    isEnabled: isEditing,
                                    selection: $foodGroupSelection
                                )
                            }

                            DateTimePillRow(
                                title: "Date & Time",
                                isEnabled: isEditing,
                                dateSelection: $date,
                                timeSelection: $time
                            )
                        }
                    }
                    .padding(.horizontal)

                    if showsNotesCard {
                        NotesCard(
                            pinnedNote: $pinnedNoteText,
                            logNote: $stickyNote,
                            pinnedUpdated: pinnedNoteUpdated,
                            allowsPinning: entry.originalFoodItem != nil,
                            isEditable: isEditing,
                            onViewAll: entry.originalFoodItem == nil || isReadOnly
                                ? nil : { showingAllNotes = true }
                        )
                        .padding([.top, .horizontal])
                    }

                    Card {
                        PortionPillRow(
                            title: "Portion",
                            isEnabled: isEditing,
                            quantity: $portionQuantity,
                            unit: $portionUnitSelection,
                            availableUnits: availableUnits,
                            servingUnits: portionUnitOptions
                        )
                    }
                    .padding([.top, .horizontal])

                    if isRecipe && (isEditing || !draftIngredients.isEmpty) {
                        Card("Ingredients") {
                            RowGroup(.divider) {
                                ForEach($draftIngredients) { $draft in
                                    IngredientRowView(
                                        draft: $draft,
                                        portionUnitOptions: portionUnitOptions,
                                        shouldShowIngredientIcons:
                                            shouldShowIngredientIcons,
                                        isEnabled: isEditing,
                                        onDelete: {
                                            draftIngredients.removeAll {
                                                $0.id == draft.id
                                            }
                                        }
                                    )
                                }
                            } bottomContent: {
                                if isEditing {
                                    ButtonRow(
                                        icon: .customSymbol("plus.circle.fill"),
                                        title: "Add Ingredient"
                                    ) {
                                        showIngredientSelectionSheet = true
                                    }
                                }
                            }
                        }
                        .padding([.top, .horizontal])
                    }

                    Card {
                        RowGroup(.divider) {
                            TextInputRow(
                                icon: .calorie,
                                title: "Calories",
                                titleExtension: "(kcal)",
                                text: $calorie,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .protein,
                                title: "Protein",
                                titleExtension: "(g)",
                                text: $protein,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .carbs,
                                title: "Carbohydrates",
                                titleExtension: "(g)",
                                text: $carbs,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .fat,
                                title: "Fat",
                                titleExtension: "(g)",
                                text: $fat,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )
                            TextInputRow(
                                icon: .fiber,
                                title: "Fiber",
                                titleExtension: "(g)",
                                text: $fiber,
                                keyboardType: .decimalPad,
                                isEnabled: isEditing && manualOverrideToggle
                            )

                            if isEditing || manualOverrideToggle {
                                ToggleRow(
                                    title: "Manual Override",
                                    isOn: $manualOverrideToggle
                                )
                                .disabled(!isEditing)
                            }
                        }
                    }
                    .padding([.top, .horizontal])

                    if isEditing || !selectedPhotos.isEmpty {
                        PhotoPickerCard(
                            images: $selectedPhotos,
                            isEditing: isEditing
                        )
                    }

                    Spacer()
                }
            }
            .safeAreaInset(edge: .top) {
                Card {
                    MealRow(
                        name: name.isEmpty ? "Unnamed Entry" : name,
                        source: sourceSelection,
                        isCustomDefaultServing: false,
                        customServingSize: "",
                        servingSize: displayServingSize,
                        servingSizeUnit: baseUnit,
                        servingWeight: displayServingWeight,
                        servingWeightUnit: baseServingWeightUnit,
                        servingUnits: portionUnitOptions,
                        calorie: calorie,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        fiber: fiber
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
            .withCustomKeyboardToolbar()
        }
        .environment(focusManager)
        .sheet(isPresented: $showIngredientSelectionSheet) {
            IngredientSelectionView { selectedItem in
                draftIngredients.append(LogRecipeIngredient(item: selectedItem))
                showIngredientSelectionSheet = false
            }
        }
        .sheet(isPresented: $showingAllNotes) {
            if let food = entry.originalFoodItem {
                NotesHistoryView(food: food, currentEntryID: entry.id)
            }
        }
        .sheet(item: $foodToLogAgain) { foodToLog in
            NavigationStack {
                if foodToLog.type == .recipe {
                    LogRecipeView(
                        recipe: foodToLog,
                        previousEntry: entry,
                        isPushedView: false
                    )
                    .environment(\.rootDismiss) { dismiss() }
                } else {
                    LogEntryView(
                        food: foodToLog,
                        previousEntry: entry,
                        isPushedView: false
                    )
                    .environment(\.rootDismiss) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAddToLibrary) {
            if entry.libraryEntryType == .recipe {
                AddRecipeView(
                    offersLogNow: true,
                    prefill: entry.addRecipePrefill,
                    onCreate: linkToLibrary
                )
            } else {
                AddEntryView(
                    entryType: entry.libraryEntryType,
                    offersLogNow: true,
                    prefill: entry.addEntryPrefill,
                    onCreate: linkToLibrary
                )
            }
        }
        .sheet(item: $foodToView) { food in
            NavigationStack {
                FoodDetailView(food: food, isPushedView: false)
            }
            .environment(\.tabBarHeight, 0)
        }
        .navigationTitle(name.isEmpty ? "Unnamed Entry" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        withAnimation {
                            if saveChanges() {
                                isEditing = false
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .fontWeight(.semibold)
                } else if !isReadOnly {
                    Menu {
                        if let originalFood = entry.originalFoodItem {
                            Button {
                                foodToLogAgain = originalFood
                            } label: {
                                Label(
                                    "Log Again",
                                    systemImage: "plus.square.on.square"
                                )
                            }

                            Button {
                                foodToView = originalFood
                            } label: {
                                Label(
                                    "View in Library",
                                    systemImage: "book.pages"
                                )
                            }
                        } else {
                            Button {
                                showAddToLibrary = true
                            } label: {
                                Label(
                                    "Add to Library",
                                    systemImage: "plus.square.dashed"
                                )
                            }
                        }

                        Button {
                            withAnimation {
                                isEditing = true
                            }
                        } label: {
                            Label("Edit Entry", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteEntry()
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button {
                        withAnimation {
                            discardChanges()
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                } else if !isPushedView {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .onChange(of: portionUnitSelection) { oldUnit, newUnit in
            guard oldUnit != newUnit, let weight = activeServingWeight else {
                return
            }
            let currentQuantity = Double(portionQuantity) ?? 0

            if oldUnit == baseUnit && newUnit == baseServingWeightUnit {
                let newQuantity = (currentQuantity / baseServingSize) * weight
                portionQuantity = EntryHelper.format(newQuantity)
            } else if oldUnit == baseServingWeightUnit && newUnit == baseUnit {
                let newQuantity = (currentQuantity / weight) * baseServingSize
                portionQuantity = EntryHelper.format(newQuantity)
            }
        }
        .onChange(of: portionQuantity) { _, _ in
            if !manualOverrideToggle { updateMacrosFromMultiplier() }
        }
        .onChange(of: draftIngredients) { _, _ in
            // Skipped outside edit mode so discarding keeps the logged macros
            if isEditing && !manualOverrideToggle {
                updateMacrosFromMultiplier()
            }
        }
        .onChange(of: manualOverrideToggle) { _, isManual in
            if isManual {
                calorie = calorieDynamic
                protein = proteinDynamic
                carbs = carbsDynamic
                fat = fatDynamic
                fiber = fiberDynamic
            } else {
                updateMacrosFromMultiplier()
            }
        }
        .onChange(of: calorie) {
            if manualOverrideToggle { calorieDynamic = calorie }
        }
        .onChange(of: protein) {
            if manualOverrideToggle { proteinDynamic = protein }
        }
        .onChange(of: carbs) {
            if manualOverrideToggle { carbsDynamic = carbs }
        }
        .onChange(of: fat) { if manualOverrideToggle { fatDynamic = fat } }
        .onChange(of: fiber) {
            if manualOverrideToggle { fiberDynamic = fiber }
        }
    }

    private func updateMacrosFromMultiplier() {
        if isRecipe {
            // Recipes derive their macros from the logged ingredients rather
            // than the (possibly since-edited) recipe item
            calorie = EntryHelper.format(
                totalIngredientCalories * activeMultiplier
            )
            protein = EntryHelper.format(
                totalIngredientProtein * activeMultiplier
            )
            carbs = EntryHelper.format(totalIngredientCarbs * activeMultiplier)
            fat = EntryHelper.format(totalIngredientFat * activeMultiplier)
            fiber = EntryHelper.format(totalIngredientFiber * activeMultiplier)
        } else {
            calorie = EntryHelper.scale(calorieStatic, by: activeMultiplier)
            protein = EntryHelper.scale(proteinStatic, by: activeMultiplier)
            carbs = EntryHelper.scale(carbsStatic, by: activeMultiplier)
            fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
            fiber = EntryHelper.scale(fiberStatic, by: activeMultiplier)
        }

        calorieDynamic = calorie
        proteinDynamic = protein
        carbsDynamic = carbs
        fatDynamic = fat
        fiberDynamic = fiber
    }

    private func saveChanges() -> Bool {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: time
        )

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        entry.timestamp = calendar.date(from: combinedComponents) ?? Date()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.name = trimmedName.isEmpty ? entry.name : trimmedName

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        entry.logNote = trimmedNote.isEmpty ? nil : trimmedNote

        if let food = entry.originalFoodItem {
            let trimmedPinned = pinnedNoteText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            EntryHelper.applyPinnedNote(
                trimmedPinned.isEmpty ? nil : trimmedPinned,
                to: food,
                in: modelContext
            )
        }
        entry.location = location.isEmpty ? nil : location

        let trimmedSource = sourceSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedSource.isEmpty && trimmedSource != "-" {
            if let existing = sourceOptions.first(where: {
                $0.source == trimmedSource
            }) {
                entry.source = existing
            } else {
                let nextOrder =
                    (sourceOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newSource = EntrySource(
                    source: trimmedSource,
                    displayOrder: nextOrder
                )
                modelContext.insert(newSource)
                entry.source = newSource
            }
        } else {
            entry.source = nil
        }

        let trimmedCategory = categorySelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedCategory.isEmpty && trimmedCategory != "-" {
            if let existing = categoryOptions.first(where: {
                $0.category == trimmedCategory
            }) {
                entry.category = existing
            } else {
                let nextOrder =
                    (categoryOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newCategory = CategorySource(
                    category: trimmedCategory,
                    displayOrder: nextOrder
                )
                modelContext.insert(newCategory)
                entry.category = newCategory
            }
        } else {
            entry.category = nil
        }

        let trimmedGroup = foodGroupSelection.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmedGroup.isEmpty && trimmedGroup != "-" {
            if let existing = foodGroupOptions.first(where: {
                $0.foodGroup == trimmedGroup
            }) {
                entry.foodGroup = existing
            } else {
                let nextOrder =
                    (foodGroupOptions.map { $0.displayOrder }.max() ?? 0) + 1
                let newGroup = FoodGroupSource(
                    foodGroup: trimmedGroup,
                    displayOrder: nextOrder
                )
                modelContext.insert(newGroup)
                entry.foodGroup = newGroup
            }
        } else {
            entry.foodGroup = nil
        }

        entry.loggedQuantity =
            Double(portionQuantity.replacingOccurrences(of: ",", with: "."))
            ?? 0.0
        entry.loggedUnit = portionUnitSelection
        entry.isManualOverride = manualOverrideToggle

        entry.calories =
            Double(calorie.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.protein =
            Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.carbs =
            Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.fat = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        entry.fiber =
            Double(fiber.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        if let oldPhotos = entry.photos {
            for photo in oldPhotos {
                modelContext.delete(photo)
            }
        }

        let photoEntities = selectedPhotos.enumerated().map { index, photo in
            EntryPhoto(
                imageData: photo.originalData,
                scale: Double(photo.scale),
                offsetX: Double(photo.offset.width),
                offsetY: Double(photo.offset.height),
                displayOrder: index
            )
        }
        entry.photos = photoEntities

        if isRecipe {
            if let oldChildren = entry.childEntries {
                for child in oldChildren {
                    modelContext.delete(child)
                }
            }

            // Child entries store the amounts actually eaten, so scale the
            // per-recipe drafts by the current portion
            let multiplier = activeMultiplier
            entry.childEntries = draftIngredients.enumerated().map {
                index, draft in
                LoggedEntry(
                    name: draft.name,
                    typeRawValue: EntryType.ingredient.rawValue,
                    originalFoodItem: draft.ingredientItem,
                    timestamp: entry.timestamp,
                    location: entry.location,
                    loggedQuantity:
                        (Double(
                            draft.quantity.replacingOccurrences(
                                of: ",",
                                with: "."
                            )
                        ) ?? 0.0) * multiplier,
                    loggedUnit: draft.unit,
                    calories: draft.activeCalories * multiplier,
                    protein: draft.activeProtein * multiplier,
                    carbs: draft.activeCarbs * multiplier,
                    fat: draft.activeFat * multiplier,
                    fiber: draft.activeFiber * multiplier,
                    displayOrder: index
                )
            }
        }

        do {
            try modelContext.save()
            return true
        } catch {
            toastCenter?.show(
                .failure(String(localized: "Couldn't Save Changes"), message: name)
            )
            modelContext.rollback()
            return false
        }
    }

    private func deleteEntry() {
        isDismissing = true
        let snapshot: MacroBackup.LogRecord?
        do {
            snapshot = try withAnimation {
                try EntryDeleter.delete(entry, in: modelContext)
            }
        } catch {
            isDismissing = false
            toastCenter?.show(
                .failure(String(localized: "Couldn't Delete Entry"), message: entry.name)
            )
            return
        }
        guard let snapshot else {
            isDismissing = false
            return
        }
        dismiss()
        toastCenter?.show(.entryDeleted(snapshot, in: modelContext, presenter: toastCenter))
    }

    private func linkToLibrary(_ food: FoodItem) {
        entry.originalFoodItem = food
        guard save(failureTitle: String(localized: "Couldn't Link to Library")) else { return }
        pinnedNoteText = food.stickyNote?.text ?? ""
    }

    private func save(failureTitle: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(failureTitle))
            return false
        }
    }

    private func discardChanges() {
        name = entry.name
        sourceSelection = entry.source?.source ?? ""
        categorySelection = entry.category?.category ?? ""
        foodGroupSelection = entry.foodGroup?.foodGroup ?? ""

        date = entry.timestamp
        time = entry.timestamp
        location = entry.location ?? ""

        portionQuantity = EntryHelper.format(entry.loggedQuantity)
        portionUnitSelection = entry.loggedUnit

        manualOverrideToggle = entry.isManualOverride

        calorie = EntryHelper.format(entry.calories)
        protein = EntryHelper.format(entry.protein)
        carbs = EntryHelper.format(entry.carbs)
        fat = EntryHelper.format(entry.fat)
        fiber = EntryHelper.format(entry.fiber)

        stickyNote = entry.logNote ?? ""
        pinnedNoteText = entry.originalFoodItem?.stickyNote?.text ?? ""

        selectedPhotos = EntryHelper.loggedPhotos(from: entry.photos)

        draftIngredients = LogRecipeIngredient.makeDrafts(for: entry)
    }
}

#Preview {
    { () -> AnyView in

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: LoggedEntry.self,
            FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            FoodGroupSource.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let mockSource = EntrySource(
            source: "Favorite Recipes",
            displayOrder: 1
        )
        let mockCategory = CategorySource(
            category: "Breakfast",
            displayOrder: 1
        )

        let servingUnit = ServingSizeUnit(
            unit: "serving",
            pluralVariant: "servings",
            isDefault: true,
            displayOrder: 1
        )
        let gramUnit = ServingSizeUnit(
            unit: "g",
            pluralVariant: "g",
            isDefault: false,
            displayOrder: 2
        )

        let mockFood = FoodItem(
            name: "Oatmeal",
            type: .food,
            source: mockSource,
            category: mockCategory,
            foodGroup: nil,
            servingSize: 1.0,
            servingUnit: servingUnit,
            servingWeight: 45.0,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150.0,
            protein: 5.0,
            carbs: 27.0,
            fat: 2.5,
            fiber: 4.0,
            isCustomDefaultServing: false,
            customServingSize: nil,
            stickyNote: Note(text: "Great for pre-workout")
        )

        let mockLog = LoggedEntry(
            name: mockFood.name,
            typeRawValue: mockFood.type.rawValue,
            originalFoodItem: mockFood,
            source: mockSource,
            category: mockCategory,
            foodGroup: nil,
            timestamp: Date(),
            location: "Home Kitchen",
            loggedQuantity: 1.5,
            loggedUnit: "serving",
            calories: 225.0,
            protein: 7.5,
            carbs: 40.5,
            fat: 3.75,
            fiber: 6.0,
            isManualOverride: false,
            logNote: "Added extra blueberries this time"
        )

        container.mainContext.insert(mockSource)
        container.mainContext.insert(mockCategory)
        container.mainContext.insert(servingUnit)
        container.mainContext.insert(gramUnit)
        container.mainContext.insert(mockFood)
        container.mainContext.insert(mockLog)

        return AnyView(
            NavigationStack {
                LoggedEntryDetailView(entry: mockLog, isPushedView: false)
            }
            .modelContainer(container)
        )

    }()
}
