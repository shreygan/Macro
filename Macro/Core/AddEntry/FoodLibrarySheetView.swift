//
//  FoodLibrarySheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/12/26.
//

import SwiftData
import SwiftUI

struct FoodLibrarySheetView: View {

    @Query(sort: \FoodItem.dateAdded, order: .reverse) var savedMeals:
        [FoodItem]

    @Query(sort: \ServingSizeUnit.displayOrder) var portionUnitOptions:
        [ServingSizeUnit]

    @State private var selectedFood: FoodItem?

    var body: some View {
        ScrollView {
            Card("Foods") {
                RowGroup(.divider) {
                    ForEach(savedMeals) { food in

                        let displayPortion =
                            (food.isCustomDefaultServing
                                && food.customServingSize != nil)
                            ? food.customServingSize!
                            : food.servingSize

                        let multiplier = EntryHelper.calculateMultiplier(
                            targetPortion: displayPortion,
                            basePortion: food.servingSize
                        )

                        let baseCalStr = EntryHelper.format(food.calories)
                        let baseProStr = EntryHelper.format(food.protein)
                        let baseCarbsStr = EntryHelper.format(food.carbs)
                        let baseFatStr = EntryHelper.format(food.fat)
                        let baseFiberStr = EntryHelper.format(food.fiber)

                        Button {
                            selectedFood = food
                        } label: {
                            MealRow(
                                name: food.name,
                                source: food.source?.source ?? "None",
                                isCustomDefaultServing: food
                                    .isCustomDefaultServing,
                                customServingSize: EntryHelper.format(
                                    food.customServingSize
                                ),
                                servingSize: EntryHelper.format(
                                    displayPortion
                                ),
                                servingSizeUnit: food.servingUnit?.unit
                                    ?? "serving",
                                servingWeight: EntryHelper.format(
                                    food.servingWeight
                                ),
                                servingWeightUnit: food.servingWeightUnit,
                                servingUnits: portionUnitOptions,

                                calorie: EntryHelper.scale(
                                    baseCalStr,
                                    by: multiplier
                                ),
                                protein: EntryHelper.scale(
                                    baseProStr,
                                    by: multiplier
                                ),
                                carbs: EntryHelper.scale(
                                    baseCarbsStr,
                                    by: multiplier
                                ),
                                fat: EntryHelper.scale(
                                    baseFatStr,
                                    by: multiplier
                                ),
                                fiber: EntryHelper.scale(
                                    baseFiberStr,
                                    by: multiplier
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedFood) { foodToLog in
            LogFoodSheetView(food: foodToLog)
        }
    }
}

#Preview {
    FoodLibrarySheetView()
}
