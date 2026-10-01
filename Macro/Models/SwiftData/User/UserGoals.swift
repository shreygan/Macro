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
    @Attribute(.unique) var id: UUID

    var date: Date

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
        calories == other.calories
            && calorieMode == other.calorieMode
            && protein == other.protein
            && proteinMode == other.proteinMode
            && carbs == other.carbs
            && carbsMode == other.carbsMode
            && fat == other.fat
            && fatMode == other.fatMode
            && fiber == other.fiber
            && fiberMode == other.fiberMode
    }
}
