//
//  UserGoals.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import Foundation
import SwiftData

@Model
class UserGoals {
    var id: UUID = UUID()

    var date: Date = Date.now

    var calories: Double = 0
    var calorieMode: GoalLimitMode = GoalLimitMode.off

    var protein: Double = 0
    var proteinMode: GoalLimitMode = GoalLimitMode.off

    var carbs: Double = 0
    var carbsMode: GoalLimitMode = GoalLimitMode.off

    var fat: Double = 0
    var fatMode: GoalLimitMode = GoalLimitMode.off

    var fiber: Double = 0
    var fiberMode: GoalLimitMode = GoalLimitMode.off

    var owner: User?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        calories: Double,
        calorieMode: GoalLimitMode,
        protein: Double,
        proteinMode: GoalLimitMode,
        carbs: Double,
        carbsMode: GoalLimitMode,
        fat: Double,
        fatMode: GoalLimitMode,
        fiber: Double,
        fiberMode: GoalLimitMode,
        owner: User? = nil
    ) {
        self.id = id
        self.date = date
        self.calories = calories
        self.calorieMode = calorieMode
        self.protein = protein
        self.proteinMode = proteinMode
        self.carbs = carbs
        self.carbsMode = carbsMode
        self.fat = fat
        self.fatMode = fatMode
        self.fiber = fiber
        self.fiberMode = fiberMode
        self.owner = owner
    }

    func hasSameTargets(as other: UserGoals) -> Bool {
        targets == other.targets
    }
}
