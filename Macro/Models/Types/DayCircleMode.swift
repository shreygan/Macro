//
//  DayCircleMode.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import Foundation

enum DayCircleMode: String, CaseIterable, Codable {
    case goalProgress = "Goal Progress"
    case oneGoal = "One Goal"
    case loggedDays = "Logged Days"
    case off = "Off"

    var explanation: String {
        switch self {
        case .goalProgress:
            String(
                localized:
                    "Fills based on how close you got to each goal. Today fills as you approach your limits. A star means you hit every goal, and it's outlined if that day still has drafts."
            )
        case .oneGoal:
            String(
                localized:
                    "Fills based on how close you got to a single goal you choose. A star means you hit it, and it's outlined if that day still has drafts."
            )
        case .loggedDays:
            String(localized: "Fills on days you logged anything. No scoring.")
        case .off:
            String(localized: "Hides the circles. The week strip shows days only.")
        }
    }
}

enum DayCircleGoal: String, CaseIterable, Codable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbohydrates"
    case fat = "Fat"
    case fiber = "Fiber"

    func target(in goals: UserGoals) -> (goal: Double, mode: GoalLimitMode) {
        switch self {
        case .calories: (goals.calories, goals.calorieMode)
        case .protein: (goals.protein, goals.proteinMode)
        case .carbs: (goals.carbs, goals.carbsMode)
        case .fat: (goals.fat, goals.fatMode)
        case .fiber: (goals.fiber, goals.fiberMode)
        }
    }

    func total(in progress: DailyProgress) -> Double {
        switch self {
        case .calories: progress.calories
        case .protein: progress.protein
        case .carbs: progress.carbs
        case .fat: progress.fat
        case .fiber: progress.fiber
        }
    }
}
