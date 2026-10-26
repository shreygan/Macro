//
//  WaterGoalFeedback.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/24/26.
//

import SwiftData
import UIKit

struct WaterGoalFeedback {
    private let context: ModelContext
    private let day: Date
    private let dayStartMinutes: Int
    private let goalML: Double?
    private let startML: Double

    init(at timestamp: Date, in context: ModelContext) {
        let user = try? context.fetch(FetchDescriptor<User>()).first
        let dayStartMinutes = user?.dayStartMinutes ?? 0
        let day = Calendar.current.logicalDay(for: timestamp, dayStartMinutes: dayStartMinutes)
        self.context = context
        self.day = day
        self.dayStartMinutes = dayStartMinutes
        goalML = user?.tracksHydration == false ? nil : user?.goalTimeline.goals(for: day)?.waterGoalML
        startML = goalML == nil ? 0 : Self.totalML(on: day, dayStartMinutes: dayStartMinutes, in: context)
    }

    func playIfReached() {
        guard let goalML, goalML > 0, startML < goalML else { return }
        let endML = Self.totalML(on: day, dayStartMinutes: dayStartMinutes, in: context)
        guard endML >= goalML else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func totalML(on day: Date, dayStartMinutes: Int, in context: ModelContext) -> Double {
        let entries = (try? context.fetch(.hydrationLogs(from: day, days: 1, dayStartMinutes: dayStartMinutes))) ?? []
        return entries.reduce(0) { $0 + $1.hydrationML }
    }
}
