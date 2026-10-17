//
//  User.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import Foundation
import SwiftData

@Model
class User {
    var id: UUID = UUID()
    var name: String?
    var onboardingComplete: Bool = false
    var dayStartMinutes: Int = 0
    var dayCircleModeRawValue: String = DayCircleMode.goalProgress.rawValue
    var dayCircleGoalRawValue: String = DayCircleGoal.calories.rawValue

    var dayCircleMode: DayCircleMode {
        get { DayCircleMode(rawValue: dayCircleModeRawValue) ?? .goalProgress }
        set { dayCircleModeRawValue = newValue.rawValue }
    }

    var dayCircleGoal: DayCircleGoal {
        get { DayCircleGoal(rawValue: dayCircleGoalRawValue) ?? .calories }
        set { dayCircleGoalRawValue = newValue.rawValue }
    }

    var activeDayCircleGoals: [DayCircleGoal] {
        guard let goals = currentGoals else { return [] }
        return DayCircleGoal.allCases.filter { $0.target(in: goals).mode != .off }
    }

    var resolvedDayCircleGoal: DayCircleGoal {
        let active = activeDayCircleGoals
        return active.contains(dayCircleGoal) ? dayCircleGoal : active.first ?? dayCircleGoal
    }

    @Relationship(deleteRule: .cascade, inverse: \UserGoals.owner)
    var goalsHistory: [UserGoals]? = []

    var currentGoals: UserGoals? {
        goalsHistory?.max(by: { $0.date < $1.date })
    }

    init(name: String? = nil, onboardingComplete: Bool = false) {
        self.name = name
        self.onboardingComplete = onboardingComplete
    }
}
