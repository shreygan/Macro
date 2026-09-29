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
    var name: String?
    var onboardingComplete: Bool

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
