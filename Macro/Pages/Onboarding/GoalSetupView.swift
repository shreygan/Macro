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
    @State private var showHistorySheet = false

    /// The goal setup screen is shown both during onboarding (before a user
    /// exists) and later for editing via HomeView. Only the latter should
    /// expose the history button, since onboarding has no history yet.
    private var isEditingExistingUser: Bool {
        users.first?.onboardingComplete ?? false
    }

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

                if isEditingExistingUser {
                    Button {
                        showHistorySheet = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 30)

            Spacer()

            GoalSlider(
                "Calories",
                titleIcon: .calorie,
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
                titleIcon: .protein,
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
                titleIcon: .carbs,
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
                titleIcon: .fat,
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
                titleIcon: .fiber,
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
                if let existingUser = users.first {
                    existingUser.onboardingComplete = true

                    let goalsChanged: Bool
                    if let existingGoals = existingUser.currentGoals {
                        goalsChanged =
                            existingGoals.calories != calorieValue
                            || existingGoals.calorieMode != calorieMode
                            || existingGoals.protein != proteinValue
                            || existingGoals.proteinMode != proteinMode
                            || existingGoals.carbs != carbsValue
                            || existingGoals.carbsMode != carbsMode
                            || existingGoals.fat != fatValue
                            || existingGoals.fatMode != fatMode
                            || existingGoals.fiber != fiberValue
                            || existingGoals.fiberMode != fiberMode
                    } else {
                        goalsChanged = true
                    }

                    if goalsChanged {
                        let newGoals = UserGoals(
                            calories: calorieValue,
                            calorieMode: calorieMode,
                            protein: proteinValue,
                            proteinMode: proteinMode,
                            carbs: carbsValue,
                            carbsMode: carbsMode,
                            fat: fatValue,
                            fatMode: fatMode,
                            fiber: fiberValue,
                            fiberMode: fiberMode,
                            owner: existingUser
                        )
                        context.insert(newGoals)
                    }
                } else {
                    let newUser = User(onboardingComplete: true)
                    context.insert(newUser)

                    let newGoals = UserGoals(
                        calories: calorieValue,
                        calorieMode: calorieMode,
                        protein: proteinValue,
                        proteinMode: proteinMode,
                        carbs: carbsValue,
                        carbsMode: carbsMode,
                        fat: fatValue,
                        fatMode: fatMode,
                        fiber: fiberValue,
                        fiberMode: fiberMode,
                        owner: newUser
                    )
                    context.insert(newGoals)
                }

                try? context.save()

                dismiss()

            } label: {
                Text(isEditingExistingUser ? "Save" : "Start")
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
        .sheet(isPresented: $showHistorySheet) {
            if let user = users.first {
                NavigationStack {
                    GoalHistoryView(user: user)
                }
            }
        }
        .onAppear {
            if let savedGoals = users.first?.currentGoals {
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

#Preview {
    GoalSetupView(
        isCalorieActive: .constant(false),
        isProteinActive: .constant(false),
        isCarbsActive: .constant(false),
        isFatActive: .constant(false),
        isFiberActive: .constant(false),
    )
}
