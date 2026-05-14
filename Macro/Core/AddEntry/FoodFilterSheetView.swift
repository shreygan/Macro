//
//  FoodFilterSheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/13/26.
//

import SwiftData
import SwiftUI

struct FoodFilterSheetView: View {
    @Environment(\.dismiss) var dismiss

    @Query(sort: \EntrySource.displayOrder) var availableSources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) var availableCategories:
        [CategorySource]

    @Binding var selectedSources: Set<String>
    @Binding var selectedCategories: Set<String>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    FilterRowView(
                        title: "Source",
                        items: availableSources.map { $0.source },
                        selection: $selectedSources
                    )

                    FilterRowView(
                        title: "Category",
                        items: availableCategories.map { $0.category },
                        selection: $selectedCategories
                    )
                }
                .padding(.vertical)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        withAnimation {
                            selectedSources.removeAll()
                            selectedCategories.removeAll()
                        }
                    }
                    .disabled(
                        selectedSources.isEmpty && selectedCategories.isEmpty
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }
}

struct FilterRowView: View {
    let title: String
    let items: [String]
    @Binding var selection: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                let allSelected =
                    selection.count == items.count && !items.isEmpty

                Button(allSelected ? "Deselect All" : "Select All") {
                    withAnimation {
                        if allSelected {
                            selection.removeAll()
                        } else {
                            selection = Set(items)
                        }
                    }
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        let isSelected = selection.contains(item)

                        Button {
                            withAnimation(.snappy) {
                                if isSelected {
                                    selection.remove(item)
                                } else {
                                    selection.insert(item)
                                }
                            }
                        } label: {
                            Text(item)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .padding(.horizontal, 16)
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
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview("Filter Sheet") {
    @Previewable @State var selectedSources: Set<String> = [
        "USDA", "Scanned Barcode",
    ]
    @Previewable @State var selectedCategories: Set<String> = []

    FoodFilterSheetView(
        selectedSources: $selectedSources,
        selectedCategories: $selectedCategories
    )

    .modelContainer(
        {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(
                for: EntrySource.self,
                CategorySource.self,
                configurations: config
            )

            container.mainContext.insert(
                EntrySource(source: "USDA", displayOrder: 1)
            )
            container.mainContext.insert(
                EntrySource(source: "User Created", displayOrder: 2)
            )
            container.mainContext.insert(
                EntrySource(source: "Scanned Barcode", displayOrder: 3)
            )
            container.mainContext.insert(
                EntrySource(source: "Home", displayOrder: 3)
            )
            container.mainContext.insert(
                EntrySource(source: "Work", displayOrder: 3)
            )

            container.mainContext.insert(
                CategorySource(category: "Breakfast", displayOrder: 1)
            )
            container.mainContext.insert(
                CategorySource(category: "Lunch", displayOrder: 2)
            )
            container.mainContext.insert(
                CategorySource(category: "Dinner", displayOrder: 3)
            )
            container.mainContext.insert(
                CategorySource(category: "Snack", displayOrder: 1)
            )
            container.mainContext.insert(
                CategorySource(category: "Meal", displayOrder: 2)
            )
            container.mainContext.insert(
                CategorySource(category: "Other", displayOrder: 3)
            )

            return container
        }()
    )
}
