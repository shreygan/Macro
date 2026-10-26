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
    var volumeUnitRawValue: String = VolumeUnit.localeDefault.rawValue
    var tracksHydration: Bool = true
    var dayCirclesIncludeWater: Bool = true
    var skipsWaterGoalPrompt: Bool = false
    var seededDrinkKeysRawValue: String = ""

    var seededDrinkKeys: Set<String> {
        get { Set(seededDrinkKeysRawValue.split(separator: ",").map(String.init)) }
        set { seededDrinkKeysRawValue = newValue.sorted().joined(separator: ",") }
    }

    var volumeUnit: VolumeUnit {
        get { VolumeUnit(rawValue: volumeUnitRawValue) ?? .milliliters }
        set { volumeUnitRawValue = newValue.rawValue }
    }

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
        return DayCircleGoal.allCases.filter {
            ($0 != .water || tracksHydration) && $0.target(in: goals).mode != .off
        }
    }

    var resolvedDayCircleGoal: DayCircleGoal {
        let active = activeDayCircleGoals
        return active.contains(dayCircleGoal) ? dayCircleGoal : active.first ?? dayCircleGoal
    }

    var offersDayCirclesWaterToggle: Bool {
        let active = activeDayCircleGoals
        return active.contains(.water) && active.contains { $0 != .water }
    }

    var scoredDayCircleGoals: [DayCircleGoal] {
        switch dayCircleMode {
        case .oneGoal:
            let goal = resolvedDayCircleGoal
            return activeDayCircleGoals.contains(goal) ? [goal] : []
        case .goalProgress, .loggedDays, .off:
            let includesWater =
                tracksHydration && (dayCirclesIncludeWater || !offersDayCirclesWaterToggle)
            return DayCircleGoal.allCases.filter { $0 != .water || includesWater }
        }
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
