//
//  DayProgressCircle.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftData
import SwiftUI

struct DayGoalScore: Equatable {
    static let ceilingFalloff = 0.5
    static let logged = DayGoalScore(fraction: 1, allHit: false, isScored: false)
    static let unscored = DayGoalScore(fraction: 0, allHit: false, isScored: false)

    var fraction: Double
    var allHit: Bool
    var isScored = true

    init(fraction: Double, allHit: Bool, isScored: Bool = true) {
        self.fraction = fraction
        self.allHit = allHit
        self.isScored = isScored
    }

    init?(
        goals: UserGoals?,
        totals: DailyProgress,
        isComplete: Bool,
        including included: [DayCircleGoal] = DayCircleGoal.allCases
    ) {
        guard let goals else { return nil }

        let tracked = included.map { macro in
            let target = macro.target(in: goals)
            return (
                current: macro.total(in: totals),
                goal: target.goal,
                mode: target.mode
            )
        }
        .filter { $0.mode != .off }

        guard !tracked.isEmpty else { return nil }

        let credits = tracked.map {
            Self.credit(
                current: $0.current,
                goal: $0.goal,
                mode: $0.mode,
                isComplete: isComplete
            )
        }
        fraction = credits.reduce(0, +) / Double(credits.count)
        allHit =
            isComplete
            && tracked.allSatisfy {
                $0.mode == .floor ? $0.current >= $0.goal : $0.current <= $0.goal
            }
    }

    private static func credit(
        current: Double,
        goal: Double,
        mode: GoalLimitMode,
        isComplete: Bool
    ) -> Double {
        switch mode {
        case .floor:
            guard goal > 0 else { return 1 }
            return min(1, max(0, current / goal))
        case .ceiling:
            if current <= goal {
                guard !isComplete, goal > 0 else { return 1 }
                return max(0, current / goal)
            }
            guard goal > 0 else { return 0 }
            let overshoot = (current - goal) / goal
            return max(0, 1 - overshoot / ceilingFalloff)
        case .off:
            return 0
        }
    }
}

struct WeekGoalScores<Content: View>: View {
    @Query private var entries: [LoggedEntry]

    private let weekDates: [Date]
    private let goalTimeline: GoalTimeline
    private let mode: DayCircleMode
    private let goal: DayCircleGoal
    private let dayStartMinutes: Int
    private let logicalToday: Date
    private let content: ([Date: DayGoalScore]) -> Content

    init(
        weekDates: [Date],
        goalTimeline: GoalTimeline,
        mode: DayCircleMode,
        goal: DayCircleGoal,
        dayStartMinutes: Int,
        logicalToday: Date,
        @ViewBuilder content: @escaping ([Date: DayGoalScore]) -> Content
    ) {
        self.weekDates = weekDates
        self.goalTimeline = goalTimeline
        self.mode = mode
        self.goal = goal
        self.dayStartMinutes = dayStartMinutes
        self.logicalToday = logicalToday
        self.content = content

        let calendar = Calendar.current
        let first = weekDates.first ?? logicalToday
        let last = weekDates.last ?? logicalToday
        let start = calendar.logicalDayRange(
            for: first,
            dayStartMinutes: dayStartMinutes
        ).lowerBound
        let end =
            mode == .off
            ? start
            : calendar.logicalDayRange(
                for: last,
                dayStartMinutes: dayStartMinutes
            ).upperBound

        _entries = Query(
            filter: #Predicate<LoggedEntry> { entry in
                entry.timestamp >= start && entry.timestamp < end
                    && entry.parentEntry == nil
            }
        )
    }

    var body: some View {
        content(scores)
    }

    private var scores: [Date: DayGoalScore] {
        guard mode != .off else { return [:] }

        let calendar = Calendar.current
        let dayStartMinutes = dayStartMinutes
        let entriesByDay = Dictionary(grouping: entries) {
            calendar.logicalDay(for: $0.timestamp, dayStartMinutes: dayStartMinutes)
        }

        var result: [Date: DayGoalScore] = [:]
        for day in weekDates where day <= logicalToday {
            guard let dayEntries = entriesByDay[day], !dayEntries.isEmpty
            else { continue }

            guard mode != .loggedDays else {
                result[day] = .logged
                continue
            }

            let goals = goalTimeline.goals(for: day)

            result[day] =
                DayGoalScore(
                    goals: goals,
                    totals: DailyProgress(entries: dayEntries),
                    isComplete: day < logicalToday,
                    including: mode == .oneGoal ? [goal] : DayCircleGoal.allCases
                ) ?? .unscored
        }
        return result
    }
}

struct DayProgressCircle: View {
    var score: DayGoalScore?
    var hasDrafts = false

    private let size: CGFloat = 40

    private var fraction: Double {
        guard let score else { return 0 }
        return score.allHit ? 1 : score.fraction
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if score != nil {
                Color.trackFill
                    .transition(.opacity)
            }

            Rectangle()
                .fill(Color.progressFill)
                .frame(height: size * fraction)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if score == nil {
                Circle()
                    .strokeBorder(Color.trackFill, lineWidth: 1.5)
                    .transition(.opacity)
            }
        }
        .overlay {
            if score?.allHit == true {
                Image(systemName: hasDrafts ? "star" : "star.fill")
                    .font(.smallIcon)
                    .foregroundStyle(.background)
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            DraftDot(isVisible: hasDrafts)
        }
        .animation(.easeInOut(duration: 0.3), value: score)
        .animation(.easeInOut(duration: 0.25), value: hasDrafts)
    }
}

struct DraftDot: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            if isVisible {
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().strokeBorder(
                            Color.gray,
                            lineWidth: 1.5
                        )
                    )
                    .frame(width: 8, height: 8)
                    .offset(y: 4)
                    .transition(.opacity)
            }
        }
    }
}
