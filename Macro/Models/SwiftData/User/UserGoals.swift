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
    var calories: Double
    var calorieMode: GoalLimitMode

    var protein: Double
    var proteinMode: GoalLimitMode

    var carbs: Double
    var carbsMode: GoalLimitMode

    var fat: Double
    var fatMode: GoalLimitMode

    var fiber: Double
    var fiberMode: GoalLimitMode

    var owner: User?

    init(
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
}
