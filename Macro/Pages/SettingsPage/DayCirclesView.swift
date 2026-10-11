//
//  DayCirclesView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftData
import SwiftUI

struct DayCirclesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    let user: User

    private var sampleScores: [DayGoalScore?] {
        switch user.dayCircleMode {
        case .goalProgress:
            [
                DayGoalScore(fraction: 0.7, allHit: false),
                DayGoalScore(fraction: 1, allHit: true),
                DayGoalScore(fraction: 0.45, allHit: false),
                nil,
                DayGoalScore(fraction: 1, allHit: true),
                DayGoalScore(fraction: 0.85, allHit: false),
                DayGoalScore(fraction: 0.3, allHit: false),
            ]
        case .oneGoal:
            oneGoalSampleScores
        case .loggedDays:
            [.logged, .logged, nil, .logged, .logged, .logged, nil]
        case .off:
            []
        }
    }

    private var oneGoalSampleScores: [DayGoalScore?] {
        let fractions: [Double?] =
            switch user.resolvedDayCircleGoal {
            case .calories: [1, 0.6, 1, nil, 0.9, 1, 0.4]
            case .protein: [0.8, 1, 0.55, nil, 1, 0.7, 1]
            case .carbs: [1, 1, 0.65, nil, 0.35, 1, 0.85]
            case .fat: [0.5, 1, 1, nil, 0.75, 0.9, 1]
            case .fiber: [0.45, 0.7, 1, nil, 0.6, 1, 0.3]
            }
        return fractions.map { fraction in
            fraction.map { DayGoalScore(fraction: $0, allHit: $0 == 1) }
        }
    }

    private func isAvailable(_ mode: DayCircleMode) -> Bool {
        switch mode {
        case .goalProgress, .oneGoal: !user.activeDayCircleGoals.isEmpty
        case .loggedDays, .off: true
        }
    }

    private var goalSelection: Binding<String> {
        Binding(
            get: { user.resolvedDayCircleGoal.rawValue },
            set: { rawValue in
                guard let goal = DayCircleGoal(rawValue: rawValue) else { return }
                user.dayCircleGoal = goal
                save()
            }
        )
    }

    private func select(_ mode: DayCircleMode) {
        guard user.dayCircleMode != mode else { return }
        withAnimation(.snappy(duration: 0.3)) {
            user.dayCircleMode = mode
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Day Circles")))
        }
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card("Preview") {
                        preview
                    }
                    .padding(.horizontal)

                    Card("Style") {
                        RowGroup(.divider) {
                            ForEach(DayCircleMode.allCases, id: \.self) { mode in
                                let isAvailable = isAvailable(mode)

                                Button {
                                    select(mode)
                                } label: {
                                    styleRow(for: mode, isAvailable: isAvailable)
                                }
                                .buttonStyle(.plain)
                                .disabled(!isAvailable)
                                .opacity(isAvailable ? 1 : 0.4)
                            }
                        }
                    }
                    .padding([.top, .horizontal])

                    if showsGoalPicker {
                        Card {
                            goalRow
                                .hidden()
                        }
                        .overlay(alignment: .top) {
                            goalRow
                        }
                        .padding([.top, .horizontal])
                        .transition(.opacity)
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Day Circles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var showsGoalPicker: Bool {
        user.dayCircleMode == .oneGoal && !user.activeDayCircleGoals.isEmpty
    }

    private var goalRow: some View {
        BaseRowLayout(title: "Goal") {
            DropdownPill(
                options: user.activeDayCircleGoals.map(\.rawValue),
                displayCustomOption: false,
                selection: goalSelection
            )
        }
    }

    private func styleRow(for mode: DayCircleMode, isAvailable: Bool) -> some View {
        BaseRowLayout(
            title: mode.rawValue,
            subtitle: isAvailable
                ? mode.explanation
                : String(localized: "Turn on a goal in Macro Goals to use this.")
        ) {
            Image(systemName: "checkmark")
                .font(.menuIcon)
                .foregroundStyle(Color.accentColor)
                .opacity(user.dayCircleMode == mode ? 1 : 0)
        }
        .contentShape(Rectangle())
    }

    private var preview: some View {
        HStack {
            if user.dayCircleMode == .off {
                Text("Day circles are hidden.")
                    .font(.compactTitle)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                ForEach(Array(sampleScores.enumerated()), id: \.offset) { index, score in
                    DayProgressCircle(score: score)

                    if index < sampleScores.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}
