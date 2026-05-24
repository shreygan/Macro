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

    @Relationship(deleteRule: .cascade)
    var goals: UserGoals?

    init(name: String? = nil, onboardingComplete: Bool = false) {
        self.name = name
        self.onboardingComplete = onboardingComplete
    }
}
