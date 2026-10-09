//
//  GoalHistoryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftData
import SwiftUI

struct GoalHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    let user: User
    var onSelect: ((UserGoals) -> Void)?
    var isActive: ((UserGoals) -> Bool)?

    @State private var history: [UserGoals]
    @State private var activeGoals: UserGoals?

    init(
        user: User,
        onSelect: ((UserGoals) -> Void)? = nil,
        isActive: ((UserGoals) -> Bool)? = nil
    ) {
        self.user = user
        self.onSelect = onSelect
        self.isActive = isActive
        let sortedHistory = (user.goalsHistory ?? []).sorted {
            $0.date > $1.date
        }
        _history = State(initialValue: sortedHistory)
        _activeGoals = State(initialValue: sortedHistory.first)
    }

    private func isAlreadyActive(_ goals: UserGoals) -> Bool {
        if let isActive {
            return isActive(goals)
        }
        return activeGoals?.hasSameTargets(as: goals) ?? false
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    if history.isEmpty {
                        emptyState
                    } else {
                        VStack {
                            ForEach(history) { goals in
                                let isActive = isAlreadyActive(goals)

                                Card {
                                    GoalHistoryRow(
                                        goals: goals,
                                        isCurrent: goals.id
                                            == history.first?.id
                                    )
                                } menuItems: {
                                    Button {
                                        select(goals, proxy: proxy)
                                    } label: {
                                        Label(
                                            isActive
                                                ? "Already Active"
                                                : "Set as Active",
                                            systemImage: "checkmark.circle"
                                        )
                                    }
                                    .disabled(isActive)
                                }
                                .padding(.bottom)
                                .id(goals.id)
                                .transition(
                                    .scale(scale: 0.9, anchor: .top)
                                        .combined(with: .opacity)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Goal History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSelect != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func select(_ goals: UserGoals, proxy: ScrollViewProxy) {
        guard !isAlreadyActive(goals) else { return }

        if let onSelect {
            onSelect(goals)
            dismiss()
            return
        }

        let activatedGoals = UserGoals(
            calories: goals.calories,
            calorieMode: goals.calorieMode,
            protein: goals.protein,
            proteinMode: goals.proteinMode,
            carbs: goals.carbs,
            carbsMode: goals.carbsMode,
            fat: goals.fat,
            fatMode: goals.fatMode,
            fiber: goals.fiber,
            fiberMode: goals.fiberMode,
            owner: user
        )
        modelContext.insert(activatedGoals)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Activate Goals")))
            return
        }
        activeGoals = activatedGoals

        let topID = history.first?.id

        Task {
            try? await Task.sleep(for: .milliseconds(350))

            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(topID, anchor: .top)
            } completion: {
                withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                    history.insert(activatedGoals, at: 0)
                }
            }
        }
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
