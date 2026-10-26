//
//  ProgressCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/29/26.
//

import SwiftData
import SwiftUI

struct DailyProgress {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var water: Double = 0
}

extension DailyProgress {
    init(entries: [LoggedEntry]) {
        self.init(
            calories: entries.reduce(0) { $0 + $1.calories },
            protein: entries.reduce(0) { $0 + $1.protein },
            carbs: entries.reduce(0) { $0 + $1.carbs },
            fat: entries.reduce(0) { $0 + $1.fat },
            fiber: entries.reduce(0) { $0 + $1.fiber },
            water: entries.reduce(0) { $0 + $1.hydrationML }
        )
    }
}

struct ProgressCard: View {
    var goals: UserGoals
    var isPastGoals: Bool
    @Query private var entries: [LoggedEntry]

    private var progress: DailyProgress {
        DailyProgress(entries: entries)
    }

    init(
        goals: UserGoals,
        date: Date,
        dayStartMinutes: Int = 0,
        isPastGoals: Bool = false
    ) {
        self.goals = goals
        self.isPastGoals = isPastGoals

        let dayRange = Calendar.current.logicalDayRange(
            for: date,
            dayStartMinutes: dayStartMinutes
        )
        let startOfDay = dayRange.lowerBound
        let endOfDay = dayRange.upperBound

        let predicate = #Predicate<LoggedEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
                && entry.parentEntry == nil
        }

        _entries = Query(filter: predicate)
    }

    struct MacroConfig: Identifiable {
        var id: String { title }
        var title: String
        var iconSymbol: AppSymbols
        var tintColor: Color
        var current: Double
        var goal: Double
        var mode: GoalLimitMode
        var unit: String
    }

    private var sortedMacros: [MacroConfig] {
        let allMacros = [
            MacroConfig(
                title: "Calories",
                iconSymbol: .calorie,
                tintColor: .calorie,
                current: progress.calories,
                goal: goals.calories,
                mode: goals.calorieMode,
                unit: "kcal"
            ),
            MacroConfig(
                title: "Protein",
                iconSymbol: .protein,
                tintColor: .protein,
                current: progress.protein,
                goal: goals.protein,
                mode: goals.proteinMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Carbohydrates",
                iconSymbol: .carbs,
                tintColor: .carbs,
                current: progress.carbs,
                goal: goals.carbs,
                mode: goals.carbsMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fat",
                iconSymbol: .fatfiber,
                tintColor: .fat,
                current: progress.fat,
                goal: goals.fat,
                mode: goals.fatMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fiber",
                iconSymbol: .fatfiber,
                tintColor: .fiber,
                current: progress.fiber,
                goal: goals.fiber,
                mode: goals.fiberMode,
                unit: "g"
            ),
        ]

        let tracked = allMacros.filter { $0.mode != .off }
        let untracked = allMacros.filter { $0.mode == .off }

        return tracked + untracked
    }

    var body: some View {
        if goals.isLive {
            card
        }
    }

    private var card: some View {
        Card("Progress") {
            VStack(spacing: 20) {
                ForEach(sortedMacros) { config in
                    MacroProgressRow(
                        title: config.title,
                        iconSymbol: config.iconSymbol,
                        tintColor: config.tintColor,
                        current: config.current,
                        goal: config.goal,
                        mode: config.mode,
                        unit: config.unit
                    )
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        } headerAccessory: {
            if isPastGoals {
                Text("Past Goals")
                    .tagStyle()
            }
        }
    }
}

#Preview {
    let today = Date()

    let container: ModelContainer
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: LoggedEntry.self,
            FoodItem.self,
            UserGoals.self,
            configurations: config
        )
    } catch {
        fatalError(
            "Failed to create preview container: \(error.localizedDescription)"
        )
    }

    let context = container.mainContext

    let mockGoals = UserGoals(
        calories: 2500,
        calorieMode: .ceiling,
        protein: 180,
        proteinMode: .floor,
        carbs: 200,
        carbsMode: .floor,
        fat: 150,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off
    )
    context.insert(mockGoals)

    let mockEntry = LoggedEntry(
        name: "Mock Daily Totals",
        typeRawValue: "meal",
        timestamp: today,
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 3254,
        protein: 125,
        carbs: 220,
        fat: 100,
        fiber: 25
    )
    context.insert(mockEntry)

    return ScrollView {
        ProgressCard(goals: mockGoals, date: today)
            .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .modelContainer(container)
}
