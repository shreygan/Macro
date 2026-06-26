//
//  ImportReviewView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var items: [DraftFoodItem]
    @Binding var duplicateCount: Int
    @Binding var errorCount: Int
    @Binding var isLoading: Bool

    @State private var itemToEdit: DraftFoodItem?
    @State private var isShowingFilePicker = false

    var onProcessNewCSV: (URL) -> Void
    var onSaveComplete: () -> Void

    private var viewState: Int {
        if isLoading { return 0 }
        if items.isEmpty { return 1 }
        return 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.blue)
                        Text("Reading CSV...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id("loading_state")

                } else if items.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No Valid Data",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } description: {
                        if duplicateCount == 0 && errorCount == 0 {
                            Text("We couldn't parse any entries from your CSV.")
                        } else {
                            let dupes =
                                duplicateCount > 0
                                ? "\(duplicateCount) duplicate\(duplicateCount > 1 ? "s" : "")"
                                : nil
                            let errs =
                                errorCount > 0
                                ? "\(errorCount) invalid row\(errorCount > 1 ? "s" : "")"
                                : nil
                            let reason = [dupes, errs].compactMap { $0 }.joined(
                                separator: " and "
                            )

                            Text(
                                "We skipped \(reason). There are no new entries to import."
                            )
                        }
                    } actions: {
                        Button("Select Another CSV") {
                            isShowingFilePicker = true
                        }
                        .tint(.blue)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id("empty_state")

                } else {
                    ScrollView {
                        if duplicateCount > 0 || errorCount > 0 {
                            importSummaryCard
                                .padding([.horizontal, .bottom])
                        }

                        EntryList(
                            title: duplicateCount > 0 || errorCount > 0
                                ? "Entries" : nil,
                            items: items,
                            rowContent: { item in reviewRow(for: item) },
                            onDelete: { item in
                                items.removeAll(where: { $0.id == item.id })
                            },
                            onEdit: { item in itemToEdit = item }
                        )
                        .padding(.horizontal)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id("list_state")
                }
            }
            .animation(.snappy, value: viewState)
            .withGlobalSwipeDismissal()
            .navigationTitle("Review Import (\(items.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAllToDatabase()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.primary)
                    }
                    .tint(Color.blue)
                    .buttonStyle(.glassProminent)
                    .disabled(items.isEmpty)
                }
            }
            .sheet(item: $itemToEdit) { editingItem in
                let dummy = FoodItem(
                    name: "",
                    servingSize: 1.0,
                    servingWeightUnit: "",
                    isAIEstimated: false,
                    calories: 0,
                    protein: 0,
                    carbs: 0,
                    fat: 0,
                    fiber: 0,
                    isCustomDefaultServing: false
                )

                EditEntryView(
                    foodItem: dummy,
                    draftItem: editingItem,
                    isImportMode: true,
                    onImportSave: { updatedDraft in
                        if let index = items.firstIndex(where: {
                            $0.id == editingItem.id
                        }) {
                            items[index] = updatedDraft
                        }
                    }
                )
            }
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let fileURL = urls.first else { return }
                    onProcessNewCSV(fileURL)
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
        }
    }

    @ViewBuilder
    private var importSummaryCard: some View {
        Card("Summary", cornerRadius: 20) {
            RowGroup(.divider) {
                // Success Row
                BaseRowLayout(
                    icon: .customSymbol("checkmark.circle.fill", tint: .green),
                    title: "Ready to Import",
                    subtitle: "Valid entries found in CSV"
                ) {
                    Text("\(items.count)")
                }

                // Duplicates Row
                if duplicateCount > 0 {
                    BaseRowLayout(
                        icon: .customSymbol(
                            "square.on.square.intersection.dashed"
                        ),
                        title: "Duplicates",
                        subtitle: "Entries already in your library"
                    ) {
                        Text("\(duplicateCount)")
                    }
                }

                // Errors Row
                if errorCount > 0 {
                    BaseRowLayout(
                        icon: .customSymbol(
                            "exclamationmark.triangle.fill",
                            tint: .red
                        ),
                        title: "Errors",
                        subtitle: "Entries with incorrect types or other errors"
                    ) {
                        Text("\(errorCount)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewRow(for item: DraftFoodItem) -> some View {

        let activeMultiplier: Double = {
            guard item.isCustomDefaultServing,
                let target = item.customServingSize
            else {
                return 1.0
            }
            return EntryHelper.calculateMultiplier(
                targetPortion: target,
                basePortion: item.servingSize
            )
        }()

        let formatDropZero: (Double?) -> String = { value in
            guard let value = value else { return "" }
            return value.formatted(.number.precision(.fractionLength(0...1)))
        }

        MealRow(
            name: item.name,
            source: item.source,
            isCustomDefaultServing: item.isCustomDefaultServing,
            customServingSize: formatDropZero(item.customServingSize),
            servingSize: formatDropZero(item.servingSize),
            servingSizeUnit: item.servingUnit,
            servingWeight: formatDropZero(item.servingWeight),
            servingWeightUnit: item.servingWeightUnit,
            servingUnits: [],
            calorie: formatDropZero(item.calories * activeMultiplier),
            protein: formatDropZero(item.protein * activeMultiplier),
            carbs: formatDropZero(item.carbs * activeMultiplier),
            fat: formatDropZero(item.fat * activeMultiplier),
            fiber: formatDropZero(item.fiber * activeMultiplier),
            icon: item.type == .ingredient ? item.type.appSymbol : nil
        ) {
            itemToEdit = item
        }
    }

    private func toggleFavorite(for item: DraftFoodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
        }
    }

    private func saveAllToDatabase() {
        for draft in items {
            let sourceName = draft.source.isEmpty ? "" : draft.source
            let resolvedSource = fetchOrCreateSource(name: sourceName)
            let resolvedUnit = fetchOrCreateUnit(
                name: draft.servingUnit.isEmpty ? "serving" : draft.servingUnit
            )
            let resolvedCategory = fetchOrCreateCategory(name: draft.category)
            let resolvedGroup = fetchOrCreateFoodGroup(name: draft.foodGroup)

            let draftNoteText = (draft.stickyNote ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let resolvedStickyNote =
                draftNoteText.isEmpty ? nil : Note(text: draftNoteText)

            let newFood = FoodItem(
                id: UUID(),
                name: draft.name,
                type: draft.type,
                source: resolvedSource,
                category: resolvedCategory,
                foodGroup: resolvedGroup,
                servingSize: draft.servingSize,
                servingUnit: resolvedUnit,
                servingWeight: draft.servingWeight,
                servingWeightUnit: draft.servingWeightUnit,
                isAIEstimated: draft.isAIEstimated,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fat: draft.fat,
                fiber: draft.fiber,
                isCustomDefaultServing: draft.isCustomDefaultServing,
                customServingSize: draft.customServingSize,
                stickyNote: resolvedStickyNote,
                dateAdded: Date()
            )

            modelContext.insert(newFood)
        }

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        onSaveComplete()
    }

    private func fetchOrCreateSource(name: String) -> EntrySource {
        let descriptor = FetchDescriptor<EntrySource>(
            predicate: #Predicate { $0.source == name }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let allDescriptor = FetchDescriptor<EntrySource>()
        let currentCount = (try? modelContext.fetchCount(allDescriptor)) ?? 0

        let newSource = EntrySource(
            source: name,
            isDefault: false,
            displayOrder: currentCount
        )

        modelContext.insert(newSource)
        return newSource
    }

    private func fetchOrCreateCategory(name: String) -> CategorySource {
        let descriptor = FetchDescriptor<CategorySource>(
            predicate: #Predicate { $0.category == name }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let allDescriptor = FetchDescriptor<CategorySource>()
        let currentCount = (try? modelContext.fetchCount(allDescriptor)) ?? 0

        let newCategory = CategorySource(
            category: name,
            displayOrder: currentCount + 1
        )

        modelContext.insert(newCategory)
        return newCategory
    }

    private func fetchOrCreateFoodGroup(name: String) -> FoodGroupSource {
        let descriptor = FetchDescriptor<FoodGroupSource>(
            predicate: #Predicate { $0.foodGroup == name }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let allDescriptor = FetchDescriptor<FoodGroupSource>()
        let currentCount = (try? modelContext.fetchCount(allDescriptor)) ?? 0

        let newGroup = FoodGroupSource(
            foodGroup: name,
            isDefault: false,
            displayOrder: currentCount + 1
        )

        modelContext.insert(newGroup)
        return newGroup
    }

    private func fetchOrCreateUnit(name: String) -> ServingSizeUnit {
        let descriptor = FetchDescriptor<ServingSizeUnit>(
            predicate: #Predicate { $0.unit == name }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let allDescriptor = FetchDescriptor<ServingSizeUnit>()
        let currentCount = (try? modelContext.fetchCount(allDescriptor)) ?? 0

        let newUnit = ServingSizeUnit(
            unit: name,
            pluralVariant: name + "s",
            isDefault: false,
            displayOrder: currentCount
        )

        modelContext.insert(newUnit)
        return newUnit
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var mockItems = [
            DraftFoodItem(
                name: "Double Chicken Bowl",
                source: "Chipotle",
                category: "Meals",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "bowl",
                servingWeight: nil,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 1050,
                protein: 85.0,
                carbs: 80.0,
                fat: 42.0,
                fiber: 15.0,
                isCustomDefaultServing: false,
                customServingSize: nil,
                isFavorite: true
            ),
            DraftFoodItem(
                name: "Paneer Paratha",
                source: "Mom's Cooking",
                category: "Meals",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "paratha",
                servingWeight: 150.0,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 350,
                protein: 12.0,
                carbs: 40.0,
                fat: 15.0,
                fiber: 4.0,
                isCustomDefaultServing: false,
                customServingSize: nil
            ),
            DraftFoodItem(
                name: "Protein Shake",
                source: "Optimum Nutrition",
                category: "Supplements",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "scoop",
                servingWeight: 31.0,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: 160,
                protein: 30.0,
                carbs: 4.0,
                fat: 2.0,
                fiber: 1.0,
                isCustomDefaultServing: false,
                customServingSize: nil
            ),
        ]

        @State private var duplicateCount = 3
        @State private var errorCount = 0
        @State private var isLoading = false

        var body: some View {
            ImportReviewView(
                items: $mockItems,
                duplicateCount: $duplicateCount,
                errorCount: $errorCount,
                isLoading: $isLoading,
                onProcessNewCSV: { url in
                    print("Preview: Would process new CSV at \(url)")
                },
                onSaveComplete: {
                    print("Preview: Save completed")
                }
            )
            .modelContainer(
                for: [
                    FoodItem.self, EntrySource.self, ServingSizeUnit.self,
                ],
                inMemory: true
            )
        }
    }

    return PreviewWrapper()
}
