//
//  IngredientRowView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

struct IngredientRowView: View {
    @Environment(\.volumeUnit) private var volumeUnit

    @Binding var draft: LogRecipeIngredient
    let portionUnitOptions: [ServingSizeUnit]
    let shouldShowIngredientIcons: Bool
    var isEnabled: Bool = true
    let onDelete: () -> Void

    var body: some View {
        let baseUnit = draft.servingUnitName

        // Resolves the String? back to AppSymbols? for MealRow
        let rowIcon: AppSymbols? = {
            guard shouldShowIngredientIcons, let iconString = draft.icon else {
                return nil
            }
            return AppSymbols(rawValue: iconString)
        }()

        let mealRow = MealRow(
            name: draft.name,
            source: "",
            isCustomDefaultServing: false,
            customServingSize: "",
            servingSize: EntryHelper.format(
                draft.activeMultiplier * draft.baseServingSize
            ),
            servingSizeUnit: baseUnit,
            servingWeight: EntryHelper.format(draft.activeWeight),
            servingWeightUnit: draft.baseServingWeightUnit,
            servingUnits: portionUnitOptions,
            calorie: EntryHelper.format(draft.activeCalories),
            protein: EntryHelper.format(draft.activeProtein),
            carbs: EntryHelper.format(draft.activeCarbs),
            fat: EntryHelper.format(draft.activeFat),
            fiber: EntryHelper.format(draft.activeFiber),
            icon: rowIcon
        ) {
            if isEnabled {
                HStack(spacing: 8) {
                    InputPill(
                        text: $draft.displayedQuantity(in: volumeUnit),
                        keyboardType: .decimalPad
                    )

                    DropdownPill(
                        options: draft.unitOptions(in: volumeUnit),
                        displayCustomOption: false,
                        selection: $draft.displayedUnit(in: volumeUnit)
                    )
                }
                .transition(.opacity)
            }
        }
        .drink(draft.drinkRowInfo)

        // Swipe-to-delete is only available when editable
        ZStack {
            if isEnabled {
                CustomSwipeRow {
                    mealRow
                } onDelete: {
                    onDelete()
                }
            } else {
                mealRow
            }
        }
        .animation(.snappy(duration: 0.3), value: isEnabled)
    }
}
