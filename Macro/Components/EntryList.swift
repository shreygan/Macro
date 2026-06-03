//
//  EntryList.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftUI

struct EntryList<Item: Identifiable & Equatable, RowContent: View>: View {
    var title: String? = nil

    var items: [Item]
    var allowSwipeActions: Bool = true

    @ViewBuilder var rowContent: (Item) -> RowContent

    var onDelete: ((Item) -> Void)? = nil
    var onEdit: ((Item) -> Void)? = nil
    var onFavorite: ((Item) -> Void)? = nil

    var body: some View {
        Card(title) {
            RowGroup(.divider) {
                ForEach(items) { item in
                    if allowSwipeActions {
                        let editAction: (() -> Void)? =
                            onEdit != nil ? { onEdit?(item) } : nil
                        let favoriteAction: (() -> Void)? =
                            onFavorite != nil ? { onFavorite?(item) } : nil

                        CustomSwipeRow(
                            content: { rowContent(item) },
                            onDelete: {
                                onDelete?(item)
                            },
                            onEdit: editAction,
                            onFavorite: favoriteAction
                        )
                        .transition(
                            .asymmetric(
                                insertion: .identity,
                                removal: .opacity.combined(
                                    with: .scale(scale: 0.9)
                                )
                            )
                        )
                    } else {
                        rowContent(item)
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: items)
    }
}

#Preview {
    struct EntryListPreviewWrapper: View {
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
                source: "Mom's Cooking",
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

        var body: some View {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    EntryList(
                        title: "Testing",
                        items: mockItems,
                        allowSwipeActions: true,
                        rowContent: { item in
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
                                fiber: String(format: "%.1f", item.fiber)
                            ) {
                                print("Tapped row for \(item.name)")
                            }
                        },
                        onDelete: { item in
                            withAnimation {
                                mockItems.removeAll(where: { $0.id == item.id })
                            }
                        },
                        onEdit: { item in
                            print("Triggered edit for \(item.name)")
                        },
                        onFavorite: { item in
                            if let index = mockItems.firstIndex(where: {
                                $0.id == item.id
                            }) {
                                mockItems[index].isFavorite.toggle()
                            }
                        }
                    )
                    .padding()
                }
            }
            .withGlobalSwipeDismissal()
        }
    }

    return EntryListPreviewWrapper()
}
