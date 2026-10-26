//
//  HydrationSettingsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/21/26.
//

import SwiftData
import SwiftUI

struct HydrationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    let user: User

    @State private var draft = WaterGoalDraft(goals: nil, unsetMode: .off)
    @State private var savedDraft: WaterGoalDraft?

    private var tracksHydration: Binding<Bool> {
        Binding(
            get: { user.tracksHydration },
            set: { isOn in
                withAnimation(.snappy) {
                    user.tracksHydration = isOn
                }
                save()
            }
        )
    }

    private var unitSelection: Binding<String> {
        Binding(
            get: { user.volumeUnit.rawValue },
            set: { rawValue in
                guard let unit = VolumeUnit(rawValue: rawValue) else { return }
                user.volumeUnit = unit
                save()
            }
        )
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Hydration Settings")))
        }
    }

    private func loadGoal() {
        draft = WaterGoalDraft(goals: user.currentGoals, unsetMode: .off)
        savedDraft = draft
    }

    private func saveGoal() {
        guard let goals = user.currentGoals, let savedDraft, draft != savedDraft else { return }
        self.savedDraft = draft
        if draft.mode == .off {
            user.skipsWaterGoalPrompt = true
        }
        let targets = draft.targets(from: goals, unit: user.volumeUnit)
        guard targets != goals.targets else {
            save()
            return
        }
        do {
            _ = try GoalHistoryStore.setCurrent(targets, for: user, in: modelContext)
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Goal")))
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card {
                        ToggleRow(
                            icon: .customSymbol("drop"),
                            title: "Track Hydration",
                            subtitle: String(localized: "Shows the Hydration card on Home"),
                            isOn: tracksHydration
                        )
                    }
                    .padding(.horizontal)

                    if user.tracksHydration, user.currentGoals != nil {
                        Card {
                            RowGroup(.divider) {
                                WaterGoalSlider(draft: $draft, unit: user.volumeUnit)

                                NavigationLink {
                                    GoalHistoryView(user: user)
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("clock.arrow.circlepath"),
                                        title: "Goal History"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding([.top, .horizontal])
                        .transition(.opacity)
                    }

                    Card {
                        RowGroup(.divider) {
                            BaseRowLayout(
                                icon: .customSymbol("ruler"),
                                title: "Units"
                            ) {
                                DropdownPill(
                                    options: VolumeUnit.allCases.map(\.rawValue),
                                    displayCustomOption: false,
                                    selection: unitSelection
                                )
                            }

                            if user.tracksHydration {
                                NavigationLink {
                                    DrinkListView(mode: .manage, isPushed: true)
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("slider.horizontal.3"),
                                        title: "Manage Drinks"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding([.top, .horizontal])
                }
                .padding(.bottom)
            }
        }
        .withCustomKeyboardToolbar()
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadGoal)
        .onChange(of: user.currentGoals?.targets) {
            if draft == savedDraft {
                loadGoal()
            }
        }
        .task(id: draft) {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            saveGoal()
        }
        .onDisappear(perform: saveGoal)
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
        fiber: 30, fiberMode: .floor
    ), owner: user))

    return NavigationStack {
        HydrationSettingsView(user: user)
    }
    .modelContainer(container)
}
