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

    let entry: LoggedEntry

    @State private var isEditing: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    @Query(sort: \EntrySource.displayOrder) var sourceOptions: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var categoryOptions:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) var foodGroupOptions:
        [FoodGroupSource]
    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

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

    @State private var selectedPhotos: [LoggedPhoto] = []

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

    init(entry: LoggedEntry) {
        self.entry = entry

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

        let existingPhotos =
            entry.photos?
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { photoEntity -> LoggedPhoto? in
                guard let uiImage = UIImage(data: photoEntity.imageData) else {
                    return nil
                }
                return LoggedPhoto(
                    image: uiImage,
                    originalData: photoEntity.imageData,
                    pickerItem: nil,
                    scale: CGFloat(photoEntity.scale),
                    offset: CGSize(
                        width: photoEntity.offsetX,
                        height: photoEntity.offsetY
                    )
                )
            } ?? []
        _selectedPhotos = State(initialValue: existingPhotos)

        let originalFood = entry.originalFoodItem
        self.baseServingSize = originalFood?.servingSize ?? 1.0
        self.baseServingWeight = originalFood?.servingWeight
        self.baseServingWeightUnit = originalFood?.servingWeightUnit ?? "g"
        self.baseUnit = originalFood?.servingUnit?.unit ?? "serving"

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

    var availableUnits: [String] {
        var units: [String] = [baseUnit]
        if baseServingWeight != nil && baseServingWeightUnit != baseUnit {
            units.append(baseServingWeightUnit)
        }
        return units
    }

    private var activeMultiplier: Double {
        let currentPortion = Double(portionQuantity) ?? 0
        let isWeightSelected =
            (portionUnitSelection == baseServingWeightUnit
                && baseServingWeight != nil)
        let basePortion =
            isWeightSelected ? baseServingWeight! : baseServingSize
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
        guard let weight = baseServingWeight else { return "" }
        let scaledWeight = activeMultiplier * weight
        return scaledWeight.formatted(.number.precision(.fractionLength(0...2)))
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        RowGroup(.divider) {
                            DropdownPillRow(
                                title: "Source",
                                options: [""] + sourceOptions.map { $0.source },
                                isEnabled: isEditing,
                                selection: $sourceSelection
                            )

                            if entry.typeRawValue == EntryType.food.rawValue {
                                DropdownPillRow(
                                    title: "Category",
                                    options: [""]
                                        + categoryOptions.map { $0.category },
                                    isEnabled: isEditing,
                                    selection: $categorySelection
                                )
                            } else {
                                DropdownPillRow(
                                    title: "Food Group",
                                    options: [""]
                                        + foodGroupOptions.map { $0.foodGroup },
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

                    if isEditing || !stickyNote.isEmpty {
                        Card {
                            WrappedInputRow(
                                placeholder: "Add a note...",
                                text: $stickyNote,
                                isEditable: isEditing,
                                characterLimit: 2000
                            )
                        }
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

                    Card {
                        RowGroup(.divider) {
                            TextInputRow(
                                icon: .calorie,
                                title: "Calories",
                                titleExtension: "(Kcal)",
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
                        name: entry.name,
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
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        withAnimation {
                            saveChanges()
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .fontWeight(.semibold)
                } else {
                    Button {
                        withAnimation {
                            isEditing = true
                        }
                    } label: {
                        Image(systemName: "pencil")
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
                } else {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                withAnimation {
                    modelContext.delete(entry)
                    try? modelContext.save()
                    dismiss()
                }
            }
        } message: {
            Text(
                "Are you sure you want to delete this entry? This action cannot be undone."
            )
        }
        .onChange(of: portionUnitSelection) { oldUnit, newUnit in
            guard oldUnit != newUnit, let weight = baseServingWeight else {
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
        calorie = EntryHelper.scale(calorieStatic, by: activeMultiplier)
        protein = EntryHelper.scale(proteinStatic, by: activeMultiplier)
        carbs = EntryHelper.scale(carbsStatic, by: activeMultiplier)
        fat = EntryHelper.scale(fatStatic, by: activeMultiplier)
        fiber = EntryHelper.scale(fiberStatic, by: activeMultiplier)

        calorieDynamic = calorie
        proteinDynamic = protein
        carbsDynamic = carbs
        fatDynamic = fat
        fiberDynamic = fiber
    }

    private func saveChanges() {
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

        let trimmedNote = stickyNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        entry.logNote = trimmedNote.isEmpty ? nil : trimmedNote
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

        do {
            try modelContext.save()
        } catch {
            print("Error saving edited LoggedEntry: \(error)")
        }
    }

    private func discardChanges() {
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

        let existingPhotos =
            entry.photos?
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { photoEntity -> LoggedPhoto? in
                guard let uiImage = UIImage(data: photoEntity.imageData) else {
                    return nil
                }
                return LoggedPhoto(
                    image: uiImage,
                    originalData: photoEntity.imageData,
                    pickerItem: nil,
                    scale: CGFloat(photoEntity.scale),
                    offset: CGSize(
                        width: photoEntity.offsetX,
                        height: photoEntity.offsetY
                    )
                )
            } ?? []

        selectedPhotos = existingPhotos
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
            name: "Oatmeal with Berries",
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
                LoggedEntryDetailView(entry: mockLog)
            }
            .modelContainer(container)
        )

    }()
}
