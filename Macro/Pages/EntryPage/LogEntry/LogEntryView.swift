//
//  LogEntryView.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-10.
//

import SwiftData
import SwiftUI

struct LogEntryView: View {
    @Environment(\.dismiss) var dismiss

    @State private var focusManager = SwipeFocusManager()

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    let food: FoodItem
    var name: String
    var isPushedView: Bool = true

    private let isCustomDefaultServing: Bool
    private let customServingSize: String
    private let servingWeight: String
    private let servingWeightUnit: String

    @State private var sourceSelection: String
    @State private var categorySelection: String

    @State private var date = Date()
    @State private var time = Date()
    @State private var location = "TODO"

    @State private var portionQuantity: String
    @State private var portionUnitSelection: String

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

    @State private var calorie: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String

    @State private var manualOverrideToggle: Bool = false

    @State private var stickyNote: String
    @State private var stickyNoteDate: Date

    @State private var newNote: String = ""
    @State private var isAddingNewNote: Bool = false
    @State private var isNewNotePinned: Bool = false
    @State private var isOriginalNotePinned: Bool

    @State private var showingAllNotes: Bool = false

    @State private var dateAdded: Date

    var mappedSourceOptions: [String] {
        sourceOptions.map { $0.source }
    }

    var mappedCategoryOptions: [String] {
        categoryOptions.map { $0.category }
    }

    var mappedUnitOptions: [String] {
        portionUnitOptions.map { $0.unit }
    }

    var availableUnits: [String] {
        var units: [String] = []
        let baseUnit = food.servingUnit?.unit ?? "serving"

        units.append(baseUnit)

        if food.servingWeight != nil && food.servingWeightUnit != baseUnit {
            units.append(food.servingWeightUnit)
        }

        return units
    }

    private var activeMultiplier: Double {
        let currentPortion = Double(portionQuantity) ?? 0

        let isWeightSelected =
            (portionUnitSelection == food.servingWeightUnit
                && food.servingWeight != nil)
        let basePortion =
            isWeightSelected ? food.servingWeight! : food.servingSize

        return EntryHelper.calculateMultiplier(
            targetPortion: currentPortion,
            basePortion: basePortion
        )
    }

    private var displayServingSize: String {
        let size = activeMultiplier * food.servingSize
        return size.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayServingWeight: String {
        guard let weight = food.servingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
        return scaledWeight.formatted(.number.precision(.fractionLength(0...2)))
    }

    init(food: FoodItem, isPushedView: Bool = true) {
        self.food = food
        self.name = food.name
        self.isPushedView = isPushedView

        _sourceSelection = State(initialValue: food.source?.source ?? "Home")
        _categorySelection = State(
            initialValue: food.category?.category ?? "Meal"
        )

        let startingPortionDouble: Double
        if food.isCustomDefaultServing, let custom = food.customServingSize {
            startingPortionDouble = custom
        } else {
            startingPortionDouble = food.servingSize
        }

        _portionQuantity = State(
            initialValue: String(format: "%g", startingPortionDouble)
        )
        _portionUnitSelection = State(
            initialValue: food.servingUnit?.unit ?? "serving"
        )

        self.isCustomDefaultServing = food.isCustomDefaultServing
        self.customServingSize = EntryHelper.format(food.customServingSize)
        self.servingWeight = EntryHelper.format(food.servingWeight)
        self.servingWeightUnit = food.servingWeightUnit

        let calStr = EntryHelper.format(food.calories)
        let proStr = EntryHelper.format(food.protein)
        let carbStr = EntryHelper.format(food.carbs)
        let fatStr = EntryHelper.format(food.fat)
        let fibStr = EntryHelper.format(food.fiber)

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

        _calorie = State(initialValue: calStr)
        _protein = State(initialValue: proStr)
        _carbs = State(initialValue: carbStr)
        _fat = State(initialValue: fatStr)
        _fiber = State(initialValue: fibStr)

        let initialNoteText = food.stickyNote?.text ?? ""
        _stickyNote = State(initialValue: initialNoteText)
        _isOriginalNotePinned = State(initialValue: !initialNoteText.isEmpty)
        _stickyNoteDate = State(
            initialValue: food.stickyNote?.lastUpdated ?? Date()
        )

        _dateAdded = State(initialValue: food.dateAdded)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card {
                            RowGroup(.divider) {
                                DropdownPillRow(
                                    title: "Source",
                                    options: sourceOptions.map { $0.source },
                                    selection: $sourceSelection
                                )
                                DropdownPillRow(
                                    title: "Category",
                                    options: categoryOptions.map {
                                        $0.category
                                    },
                                    selection: $categorySelection
                                )
                                DateTimePillRow(
                                    title: "Date & Time",
                                    dateSelection: $date,
                                    timeSelection: $time
                                )
                                PillRow(title: "Location", text: $location)
                            }
                        }
                        .padding([.leading, .trailing])

                        // TODO: make view all notes button only appear if there is previously logged entries with notes (TODO after logging implemented)

                        // TODO: think deeply about how to handle time stamps and editing pinned / previous notes. Very complex problem. Like if i edit sticky note does timestamp update to latest? does it stay old? also, do we grey it out and have them swipe on row to edit / unpin

                        Card {
                            RowGroup(.divider) {
                                if !stickyNote.isEmpty {
                                    let deleteOriginalNoteAction: () -> Void = {
                                        withAnimation(
                                            .spring(
                                                response: 0.3,
                                                dampingFraction: 0.8
                                            )
                                        ) {
                                            stickyNote = ""
                                            isOriginalNotePinned = false
                                        }
                                    }

                                    let pinOriginalNoteAction: () -> Void = {
                                        withAnimation {
                                            isOriginalNotePinned.toggle()
                                            if isOriginalNotePinned {
                                                isNewNotePinned = false
                                            }
                                        }
                                    }

                                    CustomSwipeRow(
                                        content: {
                                            WrappedInputRow(
                                                placeholder: "Sticky Note",
                                                text: $stickyNote,
                                                isSticky: isOriginalNotePinned,
                                                timestamp: stickyNoteDate
                                            )
                                        },
                                        onDelete: deleteOriginalNoteAction,
                                        onPin: pinOriginalNoteAction,
                                        isPinned: isOriginalNotePinned
                                    )
                                    .transition(
                                        .opacity.combined(
                                            with: .move(edge: .top)
                                        )
                                    )
                                }

                                if isAddingNewNote {
                                    let deleteNoteAction: () -> Void = {
                                        withAnimation(
                                            .spring(
                                                response: 0.3,
                                                dampingFraction: 0.8
                                            )
                                        ) {
                                            isAddingNewNote = false
                                            newNote = ""
                                            isNewNotePinned = false
                                        }
                                    }

                                    let pinNoteAction: () -> Void = {
                                        withAnimation {
                                            isNewNotePinned.toggle()
                                            if isNewNotePinned {
                                                isOriginalNotePinned = false
                                            }
                                        }
                                    }

                                    CustomSwipeRow(
                                        content: {
                                            WrappedInputRow(
                                                placeholder: "Add a note...",
                                                text: $newNote,
                                                isSticky: isNewNotePinned,
                                                timestamp: Date()
                                            )
                                        },
                                        onDelete: deleteNoteAction,
                                        onPin: pinNoteAction,
                                        isPinned: isNewNotePinned
                                    )
                                    .transition(
                                        .opacity.combined(
                                            with: .move(edge: .top)
                                        )
                                    )

                                    ButtonRow(
                                        title: "View All Notes",
                                        topPadding: 16,
                                        action: { showingAllNotes = true }
                                    )
                                    .transition(.opacity)

                                } else {
                                    DoubleButtonRow(
                                        topPadding: 16,
                                        leftTitle: "Add New Note",
                                        leftAction: {
                                            withAnimation(
                                                .spring(
                                                    response: 0.3,
                                                    dampingFraction: 0.8
                                                )
                                            ) {
                                                isAddingNewNote = true
                                            }
                                        },
                                        rightTitle: "View All Notes",
                                        rightAction: {
                                            showingAllNotes = true
                                        }
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card {
                            BaseRowLayout(title: "Portion") {
                                HStack(spacing: 8) {
                                    InputPill(
                                        text: $portionQuantity,
                                        keyboardType: .decimalPad
                                    )
                                    DropdownPill(
                                        options: availableUnits,
                                        displayCustomOption: false,
                                        selection: $portionUnitSelection,
                                    )
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card {
                            RowGroup(.divider) {
                                TextInputRow(
                                    icon: .calorie,
                                    title: "Calories",
                                    titleExtension: "(Kcal)",
                                    text: $calorie,
                                    keyboardType: .decimalPad,
                                    isEnabled: manualOverrideToggle
                                )

                                TextInputRow(
                                    icon: .protein,
                                    title: "Protein",
                                    titleExtension: "(g)",
                                    text: $protein,
                                    keyboardType: .decimalPad,
                                    isEnabled: manualOverrideToggle
                                )

                                TextInputRow(
                                    icon: .carbs,
                                    title: "Carbohydrates",
                                    titleExtension: "(g)",
                                    text: $carbs,
                                    keyboardType: .decimalPad,
                                    isEnabled: manualOverrideToggle
                                )

                                TextInputRow(
                                    icon: .fat,
                                    title: "Fat",
                                    titleExtension: "(g)",
                                    text: $fat,
                                    keyboardType: .decimalPad,
                                    isEnabled: manualOverrideToggle
                                )

                                TextInputRow(
                                    icon: .fiber,
                                    title: "Fiber",
                                    titleExtension: "(g)",
                                    text: $fiber,
                                    keyboardType: .decimalPad,
                                    isEnabled: manualOverrideToggle
                                )

                                ToggleRow(
                                    title: "Manual Override",
                                    isOn: $manualOverrideToggle
                                )
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        MealPhotoGalleryCard()
                            .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .safeAreaInset(edge: .top) {
                    Card {
                        MealRow(
                            name: name.isEmpty ? "New Food" : name,
                            source: sourceSelection,
                            isCustomDefaultServing: false,
                            customServingSize: "",
                            servingSize: displayServingSize,
                            servingSizeUnit: food.servingUnit?.unit
                                ?? "serving",
                            servingWeight: displayServingWeight,
                            servingWeightUnit: food.servingWeightUnit,
                            servingUnits: portionUnitOptions,
                            calorie: calorie,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            fiber: fiber
                        )
                    }
                    .padding([.leading, .trailing])
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                }
                .withCustomKeyboardToolbar()
                .scrollDismissesKeyboard(.immediately)
                .navigationTitle(
                    food.type == .food ? "Log Food" : "Log Ingredient"
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !isPushedView {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {

                        Button {
                            // TODO: Implement actual Logging & Saving logic later
                            print(
                                "Logging."
                            )

                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.primary)
                        }
                        .tint(Color.blue)
                        .buttonStyle(.glassProminent)
                    }
                }
                .onChange(of: portionUnitSelection) { oldUnit, newUnit in
                    guard oldUnit != newUnit, let weight = food.servingWeight
                    else { return }
                    let currentQuantity = Double(portionQuantity) ?? 0
                    let baseUnit = food.servingUnit?.unit ?? "serving"

                    if oldUnit == baseUnit && newUnit == food.servingWeightUnit
                    {
                        let newQuantity =
                            (currentQuantity / food.servingSize) * weight
                        portionQuantity = newQuantity.formatted(
                            .number.precision(.fractionLength(0...2))
                        )

                    } else if oldUnit == food.servingWeightUnit
                        && newUnit == baseUnit
                    {
                        let newQuantity =
                            (currentQuantity / weight) * food.servingSize
                        portionQuantity = newQuantity.formatted(
                            .number.precision(.fractionLength(0...2))
                        )
                    }
                }
                .onChange(of: portionQuantity) { _, _ in
                    if !manualOverrideToggle {
                        calorie = EntryHelper.scale(
                            calorieStatic,
                            by: activeMultiplier
                        )
                        protein = EntryHelper.scale(
                            proteinStatic,
                            by: activeMultiplier
                        )
                        carbs = EntryHelper.scale(
                            carbsStatic,
                            by: activeMultiplier
                        )
                        fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
                        fiber = EntryHelper.scale(
                            fiberStatic,
                            by: activeMultiplier
                        )

                        calorieDynamic = calorie
                        proteinDynamic = protein
                        carbsDynamic = carbs
                        fatDynamic = fat
                        fiberDynamic = fiber
                    }
                }
                .onChange(of: manualOverrideToggle) { oldValue, isManual in
                    if isManual {
                        calorie = calorieDynamic
                        protein = proteinDynamic
                        carbs = carbsDynamic
                        fat = fatDynamic
                        fiber = fiberDynamic
                    } else {
                        calorie = EntryHelper.scale(
                            calorieStatic,
                            by: activeMultiplier
                        )
                        protein = EntryHelper.scale(
                            proteinStatic,
                            by: activeMultiplier
                        )
                        carbs = EntryHelper.scale(
                            carbsStatic,
                            by: activeMultiplier
                        )
                        fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
                        fiber = EntryHelper.scale(
                            fiberStatic,
                            by: activeMultiplier
                        )
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
                .onChange(of: fat) {
                    if manualOverrideToggle { fatDynamic = fat }
                }
                .onChange(of: fiber) {
                    if manualOverrideToggle { fiberDynamic = fiber }
                }
            }
        }
        .environment(focusManager)
        .sheet(isPresented: $showingAllNotes) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("TODO: View All Notes Implementation")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("All Notes")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FoodItem.self,
            EntrySource.self,
            CategorySource.self,
            ServingSizeUnit.self,
            configurations: config
        )

        let defaultSource = EntrySource(
            source: "Home",
            isDefault: true,
            displayOrder: 1
        )
        let defaultCategory = CategorySource(
            category: "Breakfast",
            isDefault: true,
            displayOrder: 1
        )
        let defaultUnit = ServingSizeUnit(
            unit: "serving",
            isDefault: true,
            displayOrder: 1
        )

        container.mainContext.insert(defaultSource)
        container.mainContext.insert(defaultCategory)
        container.mainContext.insert(defaultUnit)

        let dummyFood = FoodItem(
            name: "Oatmeal",
            source: defaultSource,
            category: defaultCategory,
            servingSize: 2,
            servingUnit: defaultUnit,
            servingWeight: 40,
            servingWeightUnit: "g",
            isAIEstimated: false,
            calories: 150,
            protein: 5,
            carbs: 27,
            fat: 2.5,
            fiber: 4,
            isCustomDefaultServing: false,
            stickyNote: Note(
                text: "Testing and sticky note!",
                lastUpdated: Date()
            )
        )

        container.mainContext.insert(dummyFood)

        return LogEntryView(food: dummyFood)
            .modelContainer(container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
