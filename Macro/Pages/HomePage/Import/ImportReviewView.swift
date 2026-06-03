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

    @Binding var items: [ParsedFoodItem]
    @Binding var duplicateCount: Int
    @Binding var errorCount: Int
    @Binding var isLoading: Bool

    @State private var itemToEdit: ParsedFoodItem?
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
                // TODO: Route to actual edit screen
                Text("Edit Screen for \(editingItem.name)")
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
    private func reviewRow(for item: ParsedFoodItem) -> some View {
        MealRow(
            name: item.name,
            source: item.source,
            isCustomDefaultServing: false,
            customServingSize: "",
            servingSize: "1",
            servingSizeUnit: "serving",
            servingWeight: "",
            servingWeightUnit: "",
            servingUnits: [],
            calorie: String(format: "%.0f", item.calories),
            protein: String(format: "%.1f", item.protein),
            carbs: String(format: "%.1f", item.carbs),
            fat: String(format: "%.1f", item.fat),
            fiber: String(format: "%.1f", item.fiber),
        ) {
            itemToEdit = item
        }
    }

    private func toggleFavorite(for item: ParsedFoodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
        }
    }

    private func saveAllToDatabase() {
        for parsedItem in items {
            let sourceName =
                parsedItem.source.isEmpty ? "" : parsedItem.source
            let source = fetchOrCreateSource(name: sourceName)

            let unit = fetchOrCreateUnit(name: "serving")

            let newFood = FoodItem(
                id: UUID(),
                name: parsedItem.name,
                type: .food,
                source: source,
                category: nil,
                foodGroup: nil,
                servingSize: 1.0,
                servingUnit: unit,
                servingWeight: nil,
                servingWeightUnit: "",
                isAIEstimated: false,
                calories: parsedItem.calories,
                protein: parsedItem.protein,
                carbs: parsedItem.carbs,
                fat: parsedItem.fat,
                fiber: parsedItem.fiber,
                isCustomDefaultServing: false,
                customServingSize: nil,
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
            ParsedFoodItem(
                source: "Chipotle",
                name: "Double Chicken Bowl",
                calories: 1050,
                protein: 85.0,
                carbs: 80.0,
                fat: 42.0,
                fiber: 15.0,
                isFavorite: true
            ),
            ParsedFoodItem(
                source: "",
                name: "Paneer Paratha",
                calories: 350,
                protein: 12.0,
                carbs: 40.0,
                fat: 15.0,
                fiber: 4.0
            ),
            ParsedFoodItem(
                source: "Generic",
                name: "Protein Shake",
                calories: 160,
                protein: 30.0,
                carbs: 4.0,
                fat: 2.0,
                fiber: 1.0
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
