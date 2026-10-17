//
//  GoalSetupView.swift
//  Macro
//
//  Created by Shrey Gangwar on 4/27/26.
//

import SwiftData
import SwiftUI

struct GoalSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    @Query private var users: [User]

    @Binding var isCalorieActive: Bool
    @Binding var isProteinActive: Bool
    @Binding var isCarbsActive: Bool
    @Binding var isFatActive: Bool
    @Binding var isFiberActive: Bool

    var editingGoals: UserGoals? = nil
    var isAddingPeriod = false

    @State private var calorieValue = 3000.0
    @State private var proteinValue = 150.0
    @State private var carbsValue = 150.0
    @State private var fatValue = 100.0
    @State private var fiberValue = 30.0

    @State private var calorieMode: GoalLimitMode = .ceiling
    @State private var proteinMode: GoalLimitMode = .ceiling
    @State private var carbsMode: GoalLimitMode = .ceiling
    @State private var fatMode: GoalLimitMode = .ceiling
    @State private var fiberMode: GoalLimitMode = .ceiling

    @State private var showInfoSheet = false
    @State private var showHistorySheet = false

    @State private var addStart = Date()
    @State private var addEnd = Date()
    @State private var hasEnd = false
    @State private var hasSetUpDates = false
    @State private var prefilledTargets: GoalTargets?
    /// The goal setup screen is shown both during onboarding (before a user
    /// exists) and later for editing via HomeView. Only the latter should
    /// expose the history button, since onboarding has no history yet.
    private var isEditingExistingUser: Bool {
        users.first?.onboardingComplete ?? false
    }

    private var logicalToday: Date {
        Calendar.current.logicalDay(
            for: .now,
            dayStartMinutes: users.first?.dayStartMinutes ?? 0
        )
    }

    private var logicalYesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: logicalToday) ?? logicalToday
    }

    private var addingRange: GoalDateRange? {
        guard isAddingPeriod else { return nil }
        let calendar = Calendar.current
        return GoalDateRange(
            start: calendar.startOfDay(for: addStart),
            end: hasEnd ? calendar.startOfDay(for: addEnd) : nil
        )
    }

    private var targets: GoalTargets {
        GoalTargets(
            calories: calorieValue,
            calorieMode: calorieMode,
            protein: proteinValue,
            proteinMode: proteinMode,
            carbs: carbsValue,
            carbsMode: carbsMode,
            fat: fatValue,
            fatMode: fatMode,
            fiber: fiberValue,
            fiberMode: fiberMode
        )
    }

    var body: some View {
        VStack {
            if !isEditingExistingUser {
                HStack(spacing: 8) {
                    Text("Set Your Macro Goals")
                        .font(.pageTitle)

                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.smallIcon)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 30)
            }

            if isAddingPeriod {
                dateRange
                    .padding(.top, 8)
            }

            Spacer(minLength: 16)

            GoalSlider(
                "Calories",
                titleIcon: .calorie,
                unit: "kcal",
                fillColor: Color.calorie,
                value: $calorieValue,
                limitMode: $calorieMode,
                in: 0...5000,
                onEditingChanged: { isDragging in
                    isCalorieActive = isDragging
                }
            )

            Spacer(minLength: 16)

            GoalSlider(
                "Protein",
                titleIcon: .protein,
                unit: "g",
                fillColor: Color.protein,
                value: $proteinValue,
                limitMode: $proteinMode,
                in: 0...300,
                onEditingChanged: { isDragging in
                    isProteinActive = isDragging
                }
            )

            Spacer(minLength: 16)

            GoalSlider(
                "Carbonhydrates",
                titleIcon: .carbs,
                unit: "g",
                fillColor: Color.carbs,
                value: $carbsValue,
                limitMode: $carbsMode,
                in: 0...300,
                onEditingChanged: { isDragging in
                    isCarbsActive = isDragging
                }
            )

            Spacer(minLength: 16)

            GoalSlider(
                "Fat",
                titleIcon: .fat,
                unit: "g",
                fillColor: Color.fat,
                value: $fatValue,
                limitMode: $fatMode,
                in: 0...200,
                onEditingChanged: { isDragging in
                    isFatActive = isDragging
                }
            )

            Spacer(minLength: 16)

            GoalSlider(
                "Fiber",
                titleIcon: .fiber,
                unit: "g",
                fillColor: Color.fiber,
                value: $fiberValue,
                limitMode: $fiberMode,
                in: 0...100,
                onEditingChanged: { isDragging in
                    isFiberActive = isDragging
                }
            )

            Spacer(minLength: 16)

            Button {
                save()
            } label: {
                Text(isEditingExistingUser ? "Save" : "Start")
                    .font(.prominentButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .keyboardAvoidingScrollView(alwaysScrollable: isEditingExistingUser)
        .withCustomKeyboardToolbar(insetsContent: false)
        .navigationTitle(
            editingGoals != nil
                ? "Edit Goals"
                : isAddingPeriod ? "Add Goals" : isEditingExistingUser ? "Set Goals" : ""
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditingExistingUser {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }

                    if editingGoals == nil, !isAddingPeriod {
                        Button {
                            showHistorySheet = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("About Goals")
                    .font(.sectionTitle)

                Text(
                    "**Ceiling**: Your daily maximum. You’ll aim to stay under or reach this amount."
                )
                .font(.subtitle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    "**Floor**: Your daily minimum. You’ll aim to reach or exceed this amount."
                )
                .font(.subtitle)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Text("**Off**: Just track the macro with no set targets.")
                    .font(.subtitle)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(24)
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistorySheet) {
            if let user = users.first {
                NavigationStack {
                    GoalHistoryView(
                        user: user,
                        onSelect: { goals in
                            loadGoals(from: goals)
                        },
                        isActive: matchesSliders
                    )
                }
            }
        }
        .onAppear {
            if isAddingPeriod, !hasSetUpDates {
                hasSetUpDates = true
                addStart = logicalYesterday
                addEnd = logicalYesterday
            }
            loadGoals()
        }
        .onChange(of: users.first?.currentGoals?.id) {
            guard editingGoals == nil, !isAddingPeriod else { return }
            loadGoals()
        }
        .onChange(of: addStart) {
            if addEnd < addStart {
                addEnd = addStart
            }
            if addStart >= logicalToday {
                hasEnd = false
            }
            if targets == prefilledTargets {
                loadGoals()
            }
        }
    }

    private var dateRange: some View {
        HStack(spacing: 10) {
            DateTimePill(
                selection: $addStart,
                components: .date,
                range: Date.distantPast...logicalToday
            )

            Image(systemName: "arrow.right")
                .font(.smallIcon)
                .foregroundStyle(.secondary)

            if hasEnd {
                HStack(spacing: 4) {
                    DateTimePill(
                        selection: $addEnd,
                        components: .date,
                        range: addStart...max(addStart, logicalYesterday)
                    )

                    Button {
                        withAnimation(.snappy) {
                            hasEnd = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.smallIcon)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove End Date")
                }
                .transition(.opacity)
            } else {
                Button {
                    addEnd = max(addEnd, addStart)
                    withAnimation(.snappy) {
                        hasEnd = true
                    }
                } label: {
                    Text("Ongoing")
                        .foregroundStyle(addStart < logicalToday ? .primary : .secondary)
                        .pillBackground()
                }
                .buttonStyle(.plain)
                .disabled(addStart >= logicalToday)
                .accessibilityLabel("Add End Date")
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard let user = users.first else {
            let newUser = User(onboardingComplete: true)
            context.insert(newUser)
            context.insert(UserGoals(targets, owner: newUser))
            do {
                try context.save()
            } catch {
                context.rollback()
                toastCenter?.show(.failure(String(localized: "Couldn't Save Goals")))
                return
            }
            SyncDeduplicator.noteLocallyCreated(newUser)
            dismiss()
            return
        }

        let wasOnboarded = user.onboardingComplete
        user.onboardingComplete = true

        let snapshot: GoalHistoryStore.Snapshot?
        do {
            if let editingGoals {
                guard editingGoals.isLive else {
                    dismiss()
                    return
                }
                snapshot =
                    editingGoals.targets == targets
                    ? nil
                    : try GoalHistoryStore.update(
                        editingGoals,
                        to: targets,
                        for: user,
                        in: context
                    )
            } else if let addingRange {
                snapshot = try GoalHistoryStore.add(
                    targets,
                    from: addingRange.start,
                    through: addingRange.end,
                    for: user,
                    in: context
                )
            } else if user.currentGoals?.targets != targets {
                snapshot = try GoalHistoryStore.setCurrent(targets, for: user, in: context)
            } else {
                snapshot = nil
                try context.save()
            }
        } catch {
            context.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Goals")))
            return
        }

        if wasOnboarded, let snapshot {
            let timeline = user.goalTimeline
            toastCenter?.show(
                .goalsChanged(
                    addingRange != nil
                        ? String(localized: "Goals Added")
                        : String(localized: "Goals Updated"),
                    symbol: "checkmark",
                    message: addingRange.map { $0.title }
                        ?? editingGoals.flatMap { goals in
                            timeline.periods.first { $0.id == goals.id }?.title
                        },
                    undo: snapshot,
                    for: user,
                    in: context,
                    presenter: toastCenter
                )
            )
        }

        dismiss()
    }

    private func matchesSliders(_ goals: UserGoals) -> Bool {
        goals.targets == targets
    }

    private func loadGoals(from savedGoals: UserGoals? = nil) {
        let editingGoals = editingGoals?.isLive == true ? editingGoals : nil
        let rangeGoals = addingRange.flatMap { users.first?.goalTimeline.goals(for: $0.start) }
        defer { prefilledTargets = targets }
        if let savedGoals = savedGoals ?? editingGoals ?? rangeGoals ?? users.first?.currentGoals {
            calorieValue = savedGoals.calories
            calorieMode = savedGoals.calorieMode
            proteinValue = savedGoals.protein
            proteinMode = savedGoals.proteinMode
            carbsValue = savedGoals.carbs
            carbsMode = savedGoals.carbsMode
            fatValue = savedGoals.fat
            fatMode = savedGoals.fatMode
            fiberValue = savedGoals.fiber
            fiberMode = savedGoals.fiberMode
        } else {
            calorieValue = 3000
            calorieMode = .ceiling
            proteinValue = 150
            proteinMode = .ceiling
            carbsValue = 150
            carbsMode = .ceiling
            fatValue = 100
            fatMode = .ceiling
            fiberValue = 30
            fiberMode = .ceiling
        }
    }
}

#Preview {
    GoalSetupView(
        isCalorieActive: .constant(false),
        isProteinActive: .constant(false),
        isCarbsActive: .constant(false),
        isFatActive: .constant(false),
        isFiberActive: .constant(false),
    )
}
