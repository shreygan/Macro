//
//  IngredientRowView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

struct IngredientRowView: View {
    @Binding var draft: LogRecipeIngredient
    let portionUnitOptions: [ServingSizeUnit]
    let shouldShowIngredientIcons: Bool
    let onDelete: () -> Void

    var body: some View {
        let baseUnit = draft.baseServingUnitName ?? "serving"
        let hasWeight = draft.baseServingWeight != nil

        let unitConversionBinding = Binding<String>(
            get: { draft.unit },
            set: { newUnit in
                let oldUnit = draft.unit
                guard oldUnit != newUnit else { return }

                let currentMultiplier = draft.activeMultiplier

                if newUnit == draft.baseServingWeightUnit,
                    let baseWeight = draft.baseServingWeight
                {
                    let convertedQuantity = currentMultiplier * baseWeight
                    draft.quantity = EntryHelper.format(convertedQuantity)
                } else {
                    let convertedQuantity =
                        currentMultiplier * draft.baseServingSize
                    draft.quantity = EntryHelper.format(convertedQuantity)
                }

                draft.unit = newUnit
            }
        )

        // Resolves the String? back to AppSymbols? for MealRow
        let rowIcon: AppSymbols? = {
            guard shouldShowIngredientIcons, let iconString = draft.icon else {
                return nil
            }
            return AppSymbols(rawValue: iconString)
        }()

        CustomSwipeRow {
            MealRow(
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
                HStack(spacing: 8) {
                    InputPill(
                        text: $draft.quantity,
                        keyboardType: .decimalPad
                    )

                    DropdownPill(
                        options: hasWeight
                            ? [baseUnit, draft.baseServingWeightUnit]
                            : [baseUnit],
                        displayCustomOption: false,
                        selection: unitConversionBinding
                    )
                }
            }
        } onDelete: {
            onDelete()
        }
        .transition(
            .asymmetric(
                insertion: .identity,
                removal: .opacity.combined(with: .scale(scale: 0.9))
            )
        )
    }
}
