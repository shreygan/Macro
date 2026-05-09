//
//  GoalSetupView.swift
//  Macro
//
//  Created by Shrey Gangwar on 4/27/26.
//

import SwiftData
import SwiftUI

struct GoalSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var users: [User]

    @Binding var isCalorieActive: Bool
    @Binding var isProteinActive: Bool
    @Binding var isCarbsActive: Bool
    @Binding var isFatActive: Bool
    @Binding var isFiberActive: Bool

    @State private var calorieValue = 3000.0
    @State private var proteinValue = 150.0
    @State private var carbsValue = 150.0
    @State private var fatValue = 100.0
    @State private var fiberValue = 30.0

    @State private var calorieMode: GoalLimitMode = .ceiling
    @State private var proteinMode: GoalLimitMode = .ceiling
    @State private var carbsMode: GoalLimitMode = .ceiling
    @State private var fatMode: GoalLimitMode = .ceiling
    @State private var fiberMode: GoalLimitMode = .ceiling

    @State private var showInfoSheet = false

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Text("Set Your Macro Goals")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(.footnote))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 30)

            Spacer()

            GoalSlider(
                "Calories",
                titleIcon: Image("Calorie"),
                unit: "kcal",
                fillColor: Color.calorie,
                value: $calorieValue,
                limitMode: $calorieMode,
                in: 0...5000,
                onEditingChanged: { isDragging in
                    isCalorieActive = isDragging
                }
            )

            Spacer()

            GoalSlider(
                "Protein",
                titleIcon: Image("Protein"),
                unit: "g",
                fillColor: Color.protein,
                value: $proteinValue,
                limitMode: $proteinMode,
                in: 0...300,
                onEditingChanged: { isDragging in
                    isProteinActive = isDragging
                }
            )

            Spacer()

            GoalSlider(
                "Carbonhydrates",
                titleIcon: Image("Carbs"),
                unit: "g",
                fillColor: Color.carbs,
                value: $carbsValue,
                limitMode: $carbsMode,
                in: 0...300,
                onEditingChanged: { isDragging in
                    isCarbsActive = isDragging
                }
            )

            Spacer()

            GoalSlider(
                "Fat",
                titleIcon: Image("Fat"),
                unit: "g",
                fillColor: Color.fat,
                value: $fatValue,
                limitMode: $fatMode,
                in: 0...200,
                onEditingChanged: { isDragging in
                    isFatActive = isDragging
                }
            )

            Spacer()

            GoalSlider(
                "Fiber",
                titleIcon: Image("Fiber"),
                unit: "g",
                fillColor: Color.fiber,
                value: $fiberValue,
                limitMode: $fiberMode,
                in: 0...100,
                onEditingChanged: { isDragging in
                    isFiberActive = isDragging
                }
            )

            Spacer()

            Button {
                let goals = UserGoals(
                    calories: calorieValue,
                    calorieMode: calorieMode,
                    protein: proteinValue,
                    proteinMode: proteinMode,
                    carbs: carbsValue,
                    carbsMode: carbsMode,
                    fat: fatValue,
                    fatMode: fatMode,
                    fiber: fiberValue,
                    fiberMode: fiberMode
                )

                if let existingUser = users.first {
                    existingUser.onboardingComplete = true

                    if let existingGoals = existingUser.goals {
                        existingGoals.calories = calorieValue
                        existingGoals.calorieMode = calorieMode
                        existingGoals.protein = proteinValue
                        existingGoals.proteinMode = proteinMode
                        existingGoals.carbs = carbsValue
                        existingGoals.carbsMode = carbsMode
                        existingGoals.fat = fatValue
                        existingGoals.fatMode = fatMode
                        existingGoals.fiber = fiberValue
                        existingGoals.fiberMode = fiberMode
                    } else {
                        existingUser.goals = goals
                    }
                } else {
                    let newUser = User(onboardingComplete: true)
                    newUser.goals = goals

                    context.insert(newUser)
                }

                try? context.save()

            } label: {
                Text("Start")
                    .font(.system(.caption, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(
                        Capsule()
                    )
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showInfoSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("About Goals")
                    .font(.headline)

                Text(
                    "**Ceiling**: Your daily maximum. You’ll aim to stay under or reach this amount."
                )
                .font(.system(.footnote, design: .rounded))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    "**Floor**: Your daily minimum. You’ll aim to reach or exceed this amount."
                )
                .font(.system(.footnote, design: .rounded))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Text("**Off**: Just track the macro with no set targets.")
                    .font(.system(.footnote, design: .rounded))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(24)
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let currentUser = users.first,
                let savedGoals = currentUser.goals
            {
                calorieValue = savedGoals.calories
                calorieMode = savedGoals.calorieMode
                proteinValue = savedGoals.protein
                proteinMode = savedGoals.proteinMode
                carbsValue = savedGoals.carbs
                carbsMode = savedGoals.carbsMode
                fatValue = savedGoals.fat
                fatMode = savedGoals.fatMode
                fiberValue = savedGoals.fiber
                fiberMode = savedGoals.fiberMode
            }
        }
    }
}

//#Preview {
//    GoalSetupView(
//        isCalorieActive: .constant(false),
//        isProteinActive: .constant(false),
//        isCarbsActive: .constant(false)
//    )
//}
