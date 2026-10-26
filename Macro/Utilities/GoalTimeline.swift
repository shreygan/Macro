//
//  GoalTimeline.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftData
import SwiftUI

struct GoalTargets: Equatable {
    var calories: Double
    var calorieMode: GoalLimitMode
    var protein: Double
    var proteinMode: GoalLimitMode
    var carbs: Double
    var carbsMode: GoalLimitMode
    var fat: Double
    var fatMode: GoalLimitMode
    var fiber: Double
    var fiberMode: GoalLimitMode
    var water: Double = 0
    var waterMode: GoalLimitMode = .off
}

extension MacroBackup.GoalRecord {
    var targets: GoalTargets {
        GoalTargets(
            calories: calories,
            calorieMode: GoalLimitMode(rawValue: calorieMode) ?? .off,
            protein: protein,
            proteinMode: GoalLimitMode(rawValue: proteinMode) ?? .off,
            carbs: carbs,
            carbsMode: GoalLimitMode(rawValue: carbsMode) ?? .off,
            fat: fat,
            fatMode: GoalLimitMode(rawValue: fatMode) ?? .off,
            fiber: fiber,
            fiberMode: GoalLimitMode(rawValue: fiberMode) ?? .off,
            water: water ?? 0,
            waterMode: waterMode.flatMap(GoalLimitMode.init(rawValue:)) ?? .off
        )
    }
}

extension UserGoals {
    var waterGoalML: Double? {
        waterMode != .off && water > 0 ? water : nil
    }

    var targets: GoalTargets {
        GoalTargets(
            calories: calories,
            calorieMode: calorieMode,
            protein: protein,
            proteinMode: proteinMode,
            carbs: carbs,
            carbsMode: carbsMode,
            fat: fat,
            fatMode: fatMode,
            fiber: fiber,
            fiberMode: fiberMode,
            water: water,
            waterMode: waterMode
        )
    }

    convenience init(
        _ targets: GoalTargets,
        id: UUID = UUID(),
        date: Date = .now,
        owner: User?
    ) {
        self.init(
            id: id,
            date: date,
            calories: targets.calories,
            calorieMode: targets.calorieMode,
            protein: targets.protein,
            proteinMode: targets.proteinMode,
            carbs: targets.carbs,
            carbsMode: targets.carbsMode,
            fat: targets.fat,
            fatMode: targets.fatMode,
            fiber: targets.fiber,
            fiberMode: targets.fiberMode,
            water: targets.water,
            waterMode: targets.waterMode,
            owner: owner
        )
    }

    var isLive: Bool {
        !isDeleted && modelContext != nil
    }

    func apply(_ targets: GoalTargets) {
        calories = targets.calories
        calorieMode = targets.calorieMode
        protein = targets.protein
        proteinMode = targets.proteinMode
        carbs = targets.carbs
        carbsMode = targets.carbsMode
        fat = targets.fat
        fatMode = targets.fatMode
        fiber = targets.fiber
        fiberMode = targets.fiberMode
        water = targets.water
        waterMode = targets.waterMode
    }
}

struct GoalPeriod: Identifiable {
    let goals: UserGoals
    let startDay: Date
    let endDay: Date?
    let isFirst: Bool

    var id: UUID { goals.id }
    var isCurrent: Bool { endDay == nil }

    var title: String {
        switch (isFirst, endDay) {
        case (true, nil):
            String(localized: "All Days")
        case (true, let end?):
            String(localized: "Until \(Self.format(end))")
        case (false, nil):
            String(localized: "Since \(Self.format(startDay))")
        case (false, let end?):
            Calendar.current.isDate(startDay, inSameDayAs: end)
                ? Self.format(startDay)
                : "\(Self.format(startDay)) – \(Self.format(end))"
        }
    }

    static func format(_ day: Date) -> String {
        let calendar = Calendar.current
        let sameYear = calendar.isDate(day, equalTo: .now, toGranularity: .year)
        return sameYear
            ? day.formatted(.dateTime.month(.abbreviated).day())
            : day.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

struct GoalDateRange: Hashable, Identifiable {
    let start: Date
    let end: Date?

    var id: Self { self }

    var title: String {
        guard let end, !Calendar.current.isDate(start, inSameDayAs: end) else {
            return end == nil
                ? String(localized: "From \(GoalPeriod.format(start))")
                : GoalPeriod.format(start)
        }
        return "\(GoalPeriod.format(start)) – \(GoalPeriod.format(end))"
    }
}

struct GoalTimeline {
    let periods: [GoalPeriod]

    init(_ history: [UserGoals], dayStartMinutes: Int) {
        let calendar = Calendar.current
        var effective: [(day: Date, goals: UserGoals)] = []
        for goals in history.filter({ !$0.isDeleted }).sorted(by: { $0.date < $1.date }) {
            let day = calendar.logicalDay(for: goals.date, dayStartMinutes: dayStartMinutes)
            if effective.last?.day == day {
                effective[effective.count - 1] = (day, goals)
            } else {
                effective.append((day, goals))
            }
        }

        periods = effective.indices.map { index in
            let nextStart = index + 1 < effective.count ? effective[index + 1].day : nil
            return GoalPeriod(
                goals: effective[index].goals,
                startDay: effective[index].day,
                endDay: nextStart.flatMap {
                    calendar.date(byAdding: .day, value: -1, to: $0)
                },
                isFirst: index == 0
            )
        }
    }

    var current: GoalPeriod? { periods.last }

    func period(for day: Date) -> GoalPeriod? {
        let day = Calendar.current.startOfDay(for: day)
        return periods.last { $0.startDay <= day } ?? periods.first
    }

    func goals(for day: Date) -> UserGoals? {
        period(for: day)?.goals
    }

    func startDayBounds(
        for period: GoalPeriod,
        today: Date
    ) -> (lower: Date?, upper: Date)? {
        guard !period.isFirst,
            let index = periods.firstIndex(where: { $0.id == period.id })
        else { return nil }

        let calendar = Calendar.current
        let upper = period.endDay ?? calendar.startOfDay(for: today)
        let previous = periods[index - 1]
        guard !previous.isFirst else { return (nil, upper) }

        guard
            let lower = calendar.date(byAdding: .day, value: 1, to: previous.startDay),
            lower < upper
        else { return nil }
        return (lower, upper)
    }

    func next(after period: GoalPeriod) -> GoalPeriod? {
        guard let index = periods.firstIndex(where: { $0.id == period.id }),
            index + 1 < periods.count
        else { return nil }
        return periods[index + 1]
    }

    func endDayBounds(
        for period: GoalPeriod,
        today: Date
    ) -> (lower: Date?, upper: Date)? {
        let calendar = Calendar.current
        guard let next = next(after: period),
            let bounds = startDayBounds(for: next, today: today),
            let upper = calendar.date(byAdding: .day, value: -1, to: bounds.upper)
        else { return nil }
        let lower = bounds.lower.flatMap {
            calendar.date(byAdding: .day, value: -1, to: $0)
        }
        return (lower, upper)
    }
}

extension User {
    var goalTimeline: GoalTimeline {
        GoalTimeline(goalsHistory ?? [], dayStartMinutes: dayStartMinutes)
    }
}

@MainActor
enum GoalHistoryStore {
    typealias Snapshot = [MacroBackup.GoalRecord]

    static func snapshot(of user: User) -> Snapshot {
        (user.goalsHistory ?? [])
            .filter { !$0.isDeleted }
            .map(MacroBackup.goalRecord)
    }

    static func setCurrent(
        _ targets: GoalTargets,
        for user: User,
        in context: ModelContext
    ) throws -> Snapshot {
        try perform(on: user, in: context) {
            let today = Calendar.current.logicalDay(
                for: .now,
                dayStartMinutes: user.dayStartMinutes
            )
            if let current = user.goalTimeline.current, current.startDay == today {
                current.goals.apply(targets)
            } else {
                context.insert(UserGoals(targets, date: anchor(for: today), owner: user))
            }
        }
    }

    static func add(
        _ targets: GoalTargets,
        from start: Date,
        through end: Date?,
        for user: User,
        in context: ModelContext
    ) throws -> Snapshot {
        try perform(on: user, in: context) {
            let calendar = Calendar.current
            let timeline = user.goalTimeline
            let startDay = calendar.startOfDay(for: start)
            let lastDay = end.map { calendar.startOfDay(for: $0) } ?? startDay
            let first = timeline.periods.first
            let movesFirst = first.map { startDay <= $0.startDay } ?? false

            let resumeDay = end == nil
                ? nil
                : calendar.date(byAdding: .day, value: 1, to: lastDay)
            let resumeTargets = resumeDay.flatMap { timeline.goals(for: $0)?.targets }
            let hasResumeStart = resumeDay.map { day in
                timeline.periods.contains {
                    $0.startDay == day && !(movesFirst && $0.id == first?.id)
                }
            } ?? true

            for period in timeline.periods
            where period.id != first?.id
                && period.startDay >= startDay
                && (end == nil || period.startDay <= lastDay)
            {
                context.delete(period.goals)
            }

            if movesFirst, let first,
                let dayBefore = calendar.date(byAdding: .day, value: -1, to: startDay)
            {
                first.goals.date = anchor(for: dayBefore)
            }

            if !hasResumeStart, let resumeDay, let resumeTargets {
                context.insert(UserGoals(resumeTargets, date: anchor(for: resumeDay), owner: user))
            }

            context.insert(UserGoals(targets, date: anchor(for: startDay), owner: user))
        }
    }

    static func update(
        _ goals: UserGoals,
        to targets: GoalTargets,
        for user: User,
        in context: ModelContext
    ) throws -> Snapshot {
        try perform(on: user, in: context, editing: goals) {
            goals.apply(targets)
        }
    }

    static func move(
        _ goals: UserGoals,
        toStartDay day: Date,
        for user: User,
        in context: ModelContext
    ) throws -> Snapshot {
        try perform(on: user, in: context, editing: goals) {
            if let first = user.goalTimeline.periods.first,
                first.id != goals.id,
                day <= first.startDay,
                let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: day)
            {
                first.goals.date = anchor(for: dayBefore)
            }
            goals.date = anchor(for: day)
        }
    }

    static func delete(
        _ goals: UserGoals,
        for user: User,
        in context: ModelContext
    ) throws -> Snapshot {
        try perform(on: user, in: context, editing: goals) {
            context.delete(goals)
        }
    }

    static func restore(
        _ snapshot: Snapshot,
        for user: User,
        in context: ModelContext
    ) throws {
        let existing = (user.goalsHistory ?? []).filter { !$0.isDeleted }
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let keptIDs = Set(snapshot.map(\.id))

        for goals in existing where !keptIDs.contains(goals.id) {
            context.delete(goals)
        }

        for record in snapshot {
            let targets = record.targets
            if let goals = byID[record.id] {
                goals.date = record.date
                goals.apply(targets)
            } else {
                context.insert(
                    UserGoals(targets, id: record.id, date: record.date, owner: user)
                )
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    struct StaleGoalsError: Error {}

    private static func anchor(for day: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    private static func perform(
        on user: User,
        in context: ModelContext,
        editing goals: UserGoals? = nil,
        _ change: () -> Void
    ) throws -> Snapshot {
        guard goals?.isLive ?? true else { throw StaleGoalsError() }
        let snapshot = snapshot(of: user)
        normalize(user, in: context)
        guard goals?.isLive ?? true else {
            context.rollback()
            throw StaleGoalsError()
        }
        change()
        normalize(user, in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return snapshot
    }

    static func normalize(_ user: User, in context: ModelContext) {
        let timeline = user.goalTimeline
        let effectiveIDs = Set(timeline.periods.map(\.id))
        for goals in user.goalsHistory ?? []
        where !goals.isDeleted && !effectiveIDs.contains(goals.id) {
            context.delete(goals)
        }

        var previous: UserGoals?
        for period in timeline.periods {
            if let previous, previous.targets == period.goals.targets {
                context.delete(period.goals)
            } else {
                previous = period.goals
            }
        }
    }
}

extension Toast {
    static let goalsGroup = "goals"

    static func goalsChanged(
        _ title: String,
        kind: Kind = .success,
        symbol: String,
        tint: Color = .accentColor,
        message: String? = nil,
        undo snapshot: GoalHistoryStore.Snapshot,
        for user: User,
        in context: ModelContext,
        presenter: ToastCenter?
    ) -> Toast {
        Toast(
            group: goalsGroup,
            kind: kind,
            symbol: symbol,
            tint: tint,
            title: title,
            message: message,
            action: Toast.Action(title: String(localized: "Undo")) { [weak presenter] in
                do {
                    try withAnimation {
                        try GoalHistoryStore.restore(snapshot, for: user, in: context)
                    }
                } catch {
                    presenter?.show(.failure(String(localized: "Couldn't Undo Goal Change")))
                }
            }
        )
    }
}
