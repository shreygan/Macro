//
//  QuickLogPopover.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftData
import SwiftUI

struct QuickLogPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popoverDrag) private var popoverDrag

    @State private var rowFrames: [UUID: CGRect] = [:]

    @Query(sort: \FavoriteEntry.orderIndex) private var favoriteEntries: [FavoriteEntry]
    @Query(QuickLogPopover.recentEntriesDescriptor) private var loggedEntries: [LoggedEntry]

    var itemLimit: Int = 7
    var onSelect: (FoodItem) -> Void

    private static var recentEntriesDescriptor: FetchDescriptor<LoggedEntry> {
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.parentEntry == nil },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return descriptor
    }

    private func makeFavorites() -> [FoodItem] {
        Array(favoriteEntries.lazy.compactMap(\.foodItem).prefix(itemLimit))
    }

    private func makeRecents(excluding favorites: [FoodItem]) -> [FoodItem] {
        let limit = itemLimit - favorites.count
        guard limit > 0 else { return [] }

        var seen = Set(favorites.map(\.id))
        var result: [FoodItem] = []
        for entry in loggedEntries {
            guard let food = entry.originalFoodItem, seen.insert(food.id).inserted else { continue }
            result.append(food)
            if result.count == limit { break }
        }
        return result
    }

    private func food(at location: CGPoint?, in foods: [FoodItem]) -> FoodItem? {
        guard let location else { return nil }
        return foods.first { rowFrames[$0.id]?.contains(location) == true }
    }

    private func select(_ food: FoodItem) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dismiss()
        }
        onSelect(food)
    }

    var body: some View {
        let favorites = makeFavorites()
        let recents = makeRecents(excluding: favorites)
        let allFoods = favorites + recents
        let hoveredID = food(at: popoverDrag.location, in: allFoods)?.id
        let showsHeaders = !favorites.isEmpty && !recents.isEmpty

        VStack(alignment: .leading, spacing: 0) {
            if allFoods.isEmpty {
                ContentUnavailableView(
                    "Nothing Here Yet",
                    systemImage: "fork.knife",
                    description: Text("Favorites and recently logged foods will appear here.")
                )
                .padding(.vertical, 24)
            } else {
                section("Favorites", foods: favorites, showsHeader: showsHeaders, hoveredID: hoveredID)
                section("Recent", foods: recents, showsHeader: showsHeaders, hoveredID: hoveredID)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .sensoryFeedback(.selection, trigger: hoveredID) { _, newID in newID != nil }
        .onChange(of: popoverDrag.releaseCount) {
            if let food = food(at: popoverDrag.releaseLocation, in: allFoods) {
                select(food)
            }
        }
    }

    @ViewBuilder
    private func section(
        _ title: LocalizedStringKey,
        foods: [FoodItem],
        showsHeader: Bool,
        hoveredID: UUID?
    ) -> some View {
        if !foods.isEmpty {
            if showsHeader {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }

            ForEach(Array(foods.enumerated()), id: \.element.id) { index, food in
                Button {
                    select(food)
                } label: {
                    CompactMealRow(food: food)
                        .background {
                            if hoveredID == food.id {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.primary.opacity(0.1))
                                    .padding(.horizontal, 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    rowFrames[food.id] = frame
                }

                if index < foods.count - 1 {
                    let isNextToHighlight =
                        hoveredID == food.id || hoveredID == foods[index + 1].id
                    Divider()
                        .padding(.leading, 42)
                        .opacity(isNextToHighlight ? 0 : 1)
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self, FavoriteEntry.self, LoggedEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let foods = [
        FoodItem(name: "Oatmeal", servingSize: 1, servingWeightUnit: "g", isAIEstimated: false, calories: 150, protein: 5, carbs: 27, fat: 2.5, fiber: 4, isCustomDefaultServing: false),
        FoodItem(name: "Chicken Rice Bowl", type: .recipe, servingSize: 1, servingWeightUnit: "g", isAIEstimated: false, calories: 620, protein: 48, carbs: 70, fat: 14, fiber: 5, isCustomDefaultServing: false),
        FoodItem(name: "Protein Shake", type: .drink, servingSize: 1, servingWeightUnit: "ml", isAIEstimated: false, calories: 160, protein: 30, carbs: 6, fat: 2, fiber: 0, isCustomDefaultServing: false),
        FoodItem(name: "Big Numbers", servingSize: 1, servingWeightUnit: "g", isAIEstimated: false, calories: 12345.5, protein: 1234.5, carbs: 999.5, fat: 88.5, fiber: 12.5, isCustomDefaultServing: false),
        FoodItem(name: "Huge Numbers", servingSize: 1, servingWeightUnit: "g", isAIEstimated: false, calories: 1234567.5, protein: 123456.5, carbs: 12345.5, fat: 1234.5, fiber: 123.5, isCustomDefaultServing: false),
    ]
    foods.forEach { context.insert($0) }
    for (index, food) in foods.enumerated() {
        let favorite = FavoriteEntry(orderIndex: index, foodItem: food)
        context.insert(favorite)
    }

    return QuickLogPopover { _ in }
        .modelContainer(container)
}
