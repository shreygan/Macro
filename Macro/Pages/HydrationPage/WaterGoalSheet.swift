//
//  WaterGoalSheet.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/21/26.
//

import SwiftData
import SwiftUI

struct WaterGoalDraft: Equatable {
    static let defaultGoalML = 2000.0

    var milliliters: Double
    var mode: GoalLimitMode

    init(goals: UserGoals?, unsetMode: GoalLimitMode) {
        if let goals, goals.water > 0 {
            milliliters = goals.water
            mode = goals.waterMode == .off ? .off : .floor
        } else {
            milliliters = Self.defaultGoalML
            mode = unsetMode
        }
    }

    func targets(from goals: UserGoals, unit: VolumeUnit) -> GoalTargets {
        var targets = goals.targets
        targets.waterMode = mode
        if mode != .off, milliliters != goals.water {
            targets.water = unit.milliliters(from: unit.value(fromML: milliliters).rounded())
        }
        return targets
    }
}

struct WaterGoalSlider: View {
    @Binding var draft: WaterGoalDraft
    let unit: VolumeUnit

    private var range: ClosedRange<Double> {
        unit.value(fromML: 1000).rounded()...unit.value(fromML: 5000).rounded()
    }

    private var value: Binding<Double> {
        Binding(
            get: { unit.value(fromML: draft.milliliters) },
            set: { draft.milliliters = unit.milliliters(from: $0) }
        )
    }

    var body: some View {
        GoalSlider(
            "Water",
            titleIcon: .customSymbol("drop.fill", tint: DrinkTint.blue.color),
            unit: unit.rawValue,
            fillColor: DrinkTint.blue.color,
            value: value,
            limitMode: $draft.mode,
            in: range,
            modes: [.floor, .off]
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct WaterGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    @Query private var users: [User]

    var editing: UserGoals? = nil

    @State private var draft = WaterGoalDraft(goals: nil, unsetMode: .floor)
    @State private var hasLoaded = false
    @State private var contentHeight: CGFloat?
    @State private var chromeHeight: CGFloat = 0

    private var unit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private var currentGoals: UserGoals? {
        users.first?.currentGoals
    }

    private var goals: UserGoals? {
        guard let editing else { return currentGoals }
        return editing.isLive ? editing : nil
    }

    private var periodTitle: String? {
        guard let editing else { return nil }
        return users.first?.goalTimeline.periods.first { $0.id == editing.id }?.title
    }

    var body: some View {
        NavigationStack {
            Group {
                if let periodTitle {
                    content
                        .navigationSubtitle(periodTitle)
                } else {
                    content
                }
            }
            .withCustomKeyboardToolbar()
            .navigationTitle("Water Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save Goal")
                    .disabled(goals == nil)
                    .tint(Color.accentColor)
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .fittedSheetHeight(contentHeight.map { $0 + chromeHeight })
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            draft = WaterGoalDraft(goals: goals, unsetMode: .floor)
        }
    }

    private var content: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        WaterGoalSlider(draft: $draft, unit: unit)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(.container, edges: .bottom)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.top
            } action: { inset in
                chromeHeight = inset
            }
        }
    }

    private func save() {
        guard let user = users.first, let goals else { return }
        let targets = draft.targets(from: goals, unit: unit)
        let periodTitle = periodTitle
        if editing == nil, draft.mode == .off {
            user.skipsWaterGoalPrompt = true
        }

        guard targets != goals.targets else {
            if modelContext.hasChanges {
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    toastCenter?.show(.failure(String(localized: "Couldn't Save Goal")))
                    return
                }
            }
            dismiss()
            return
        }

        let snapshot: GoalHistoryStore.Snapshot
        do {
            snapshot = try withAnimation {
                editing == nil
                    ? try GoalHistoryStore.setCurrent(targets, for: user, in: modelContext)
                    : try GoalHistoryStore.update(goals, to: targets, for: user, in: modelContext)
            }
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Goal")))
            return
        }

        toastCenter?.show(
            .goalsChanged(
                String(localized: "Water Goal Updated"),
                symbol: "checkmark",
                message: periodTitle,
                undo: snapshot,
                for: user,
                in: modelContext,
                presenter: toastCenter
            )
        )
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: User.self, UserGoals.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let user = User(onboardingComplete: true)
    container.mainContext.insert(user)
    container.mainContext.insert(UserGoals(GoalTargets(
        calories: 2500, calorieMode: .ceiling,
        protein: 150, proteinMode: .floor,
        carbs: 200, carbsMode: .ceiling,
        fat: 80, fatMode: .ceiling,
        fiber: 30, fiberMode: .floor,
        water: 2500, waterMode: .floor
    ), owner: user))

    return WaterGoalSheet()
        .modelContainer(container)
}
