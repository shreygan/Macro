//
//  LogFoodSheetView.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-10.
//

import SwiftUI

struct LogFoodSheetView: View {
    @Environment(\.dismiss) var dismiss

    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    
    var sourceOptions: [String] = ["Home", "Work", "Other"]
    @State private var sourceSelection: String = "Home"
    
    var categoryOptions: [String] = ["Breakfast", "Lunch", "Dinner", "Snack", "Meal"]
    @State private var categorySelections: String = "Meal"
    
    @State private var date = Date()
    @State private var time = Date()
    @State private var location = "TODO"
    
    @State private var portionQuantity = "1"
    var portionUnitOptions = ["1 Cup", "100 grams", "serving"]
    @State private var portionUnitSelection: String = "serving"

    private let calorieStatic = "955"
    private let proteinStatic = "84"
    private let carbsStatic = "68"
    private let fatStatic = "38"
    private let fiberStatic = "11"
    
    @State private var calorieDynamic = "955"
    @State private var proteinDynamic = "84"
    @State private var carbsDynamic = "68"
    @State private var fatDynamic = "38"
    @State private var fiberDynamic = "11"
    
    @State private var calorie = "955"
    @State private var protein = "84"
    @State private var carbs = "68"
    @State private var fat = "38"
    @State private var fiber = "11"
    
    @State private var manualOverrideToggle: Bool = false
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card {
                            MealRow(
                                title: "Double Chicken Bowl",
                                subtitle: "Chipotle, 1 bowl",
                                calorie: calorie,
                                protein: protein,
                                carbs: carbs,
                                fat: fat,
                                fiber: fiber
                            )
                        }
                        .padding([.top, .leading, .trailing])
                        
                        Card {
                            RowGroup(.divider) {
                                DropdownPillRow(title: "Source", options: sourceOptions, selection: $sourceSelection)
                                DropdownPillRow(title: "Category", options: categoryOptions, selection: $categorySelections)
                                DateTimePillRow(title: "Date & Time", dateSelection: $date, timeSelection: $time)
                                PillRow(title: "Location", text: $location)
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card {
                            BaseRowLayout(title: "Portion") {
                                HStack(spacing: 8) {
                                    InputPill(text: $portionQuantity)
                                    DropdownPill(options: portionUnitOptions, selection: $portionUnitSelection)
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])
                        
                        Card {
                            RowGroup(.divider) {
                                TextInputRow(
                                    icon: .custom(Image("Calorie")),
                                    title: "Calories",
                                    titleExtension: "(Kcal)",
                                    text: $calorie,
                                    keyboardType: .numberPad,
                                    isEnabled: manualOverrideToggle
                                )
                                
                                TextInputRow(
                                    icon: .custom(Image("Protein")),
                                    title: "Protein",
                                    titleExtension: "(g)",
                                    text: $protein,
                                    keyboardType: .numberPad,
                                    isEnabled: manualOverrideToggle
                                )
                                
                                TextInputRow(
                                    icon: .custom(Image("Carbs")),
                                    title: "Carbohydrates",
                                    titleExtension: "(g)",
                                    text: $carbs,
                                    keyboardType: .numberPad,
                                    isEnabled: manualOverrideToggle
                                )
                                
                                TextInputRow(
                                    icon: .custom(Image("Fat")),
                                    title: "Fat",
                                    titleExtension: "(g)",
                                    text: $fat,
                                    keyboardType: .numberPad,
                                    isEnabled: manualOverrideToggle
                                )
                                
                                TextInputRow(
                                    icon: .custom(Image("Fiber")),
                                    title: "Fiber",
                                    titleExtension: "(g)",
                                    text: $fiber,
                                    keyboardType: .numberPad,
                                    isEnabled: manualOverrideToggle
                                )
                                
                                ToggleRow(
                                    title: "Manual Override",
                                    isOn: $manualOverrideToggle
                                )
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .navigationTitle("Log Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.tertiary)
                        }
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
                        calorie = calorieStatic
                        protein = proteinStatic
                        carbs = carbsStatic
                        fat = fatStatic
                        fiber = fiberStatic
                    }
                }
                .onChange(of: calorie) { if manualOverrideToggle { calorieDynamic = calorie } }
                .onChange(of: protein) { if manualOverrideToggle { proteinDynamic = protein } }
                .onChange(of: carbs) { if manualOverrideToggle { carbsDynamic = carbs } }
                .onChange(of: fat) { if manualOverrideToggle { fatDynamic = fat } }
                .onChange(of: fiber) { if manualOverrideToggle { fiberDynamic = fiber } }
            }
        }
    }
}

#Preview {
    LogFoodSheetView(title: "Log Food")
}
