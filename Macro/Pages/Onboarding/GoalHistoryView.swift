//
//  GoalHistoryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftData
import SwiftUI

struct GoalHistoryView: View {
    let user: User

    private var sortedHistory: [UserGoals] {
        (user.goalsHistory ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                if sortedHistory.isEmpty {
                    emptyState
                } else {
                    VStack {
                        ForEach(sortedHistory) { goals in
                            Card {
                                GoalHistoryRow(
                                    goals: goals,
                                    isCurrent: goals.id
                                        == user.currentGoals?.id
                                )
                            }
                            .padding(.bottom)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Goal History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No Goal History Yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Past goals will appear here after you make a change.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }
}

#Preview {
    let container: ModelContainer
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: User.self,
            UserGoals.self,
            configurations: config
        )
    } catch {
        fatalError(
            "Failed to create preview container: \(error.localizedDescription)"
        )
    }

    let context = container.mainContext
    let user = User(onboardingComplete: true)
    context.insert(user)

    let olderGoals = UserGoals(
        date: .now.addingTimeInterval(-86400 * 30),
        calories: 2200,
        calorieMode: .ceiling,
        protein: 150,
        proteinMode: .floor,
        carbs: 180,
        carbsMode: .floor,
        fat: 120,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off,
        owner: user
    )
    context.insert(olderGoals)

    let currentGoals = UserGoals(
        calories: 2500,
        calorieMode: .ceiling,
        protein: 180,
        proteinMode: .floor,
        carbs: 200,
        carbsMode: .floor,
        fat: 150,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off,
        owner: user
    )
    context.insert(currentGoals)

    return NavigationStack {
        GoalHistoryView(user: user)
    }
    .modelContainer(container)
}
