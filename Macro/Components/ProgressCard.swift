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
}

struct ProgressCard: View {
    var goals: UserGoals
    @Query private var entries: [LoggedEntry]

    private var progress: DailyProgress {
        let totalCalories = entries.reduce(0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0) { $0 + $1.protein }
        let totalCarbs = entries.reduce(0) { $0 + $1.carbs }
        let totalFat = entries.reduce(0) { $0 + $1.fat }
        let totalFiber = entries.reduce(0) { $0 + $1.fiber }

        return DailyProgress(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber
        )
    }

    init(goals: UserGoals, date: Date) {
        self.goals = goals

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<LoggedEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
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
                tintColor: .red,
                current: progress.calories,
                goal: goals.calories,
                mode: goals.calorieMode,
                unit: "kcal"
            ),
            MacroConfig(
                title: "Protein",
                iconSymbol: .protein,
                tintColor: .blue,
                current: progress.protein,
                goal: goals.protein,
                mode: goals.proteinMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Carbohydrates",
                iconSymbol: .carbs,
                tintColor: .green,
                current: progress.carbs,
                goal: goals.carbs,
                mode: goals.carbsMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fat",
                iconSymbol: .fatfiber,
                tintColor: .purple,
                current: progress.fat,
                goal: goals.fat,
                mode: goals.fatMode,
                unit: "g"
            ),
            MacroConfig(
                title: "Fiber",
                iconSymbol: .fatfiber,
                tintColor: .yellow,
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
        }
    }
}

#Preview {
    let today = Date()

    let container: ModelContainer
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: LoggedEntry.self,
            FoodItem.self,
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
