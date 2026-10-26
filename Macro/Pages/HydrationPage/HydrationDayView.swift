//
//  HydrationDayView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftData
import SwiftUI

struct HydrationDayRequest: Identifiable {
    let day: Date
    var drink: FoodItem? = nil
    var id: Date { day }
}

extension View {
    func hydrationDaySheet(item: Binding<HydrationDayRequest?>, dayStartMinutes: Int) -> some View {
        sheet(item: item) { request in
            HydrationDayView(day: request.day, dayStartMinutes: dayStartMinutes)
            .environment(\.tabBarHeight, 0)
        }
    }
}

struct HydrationDayView: View {
    let day: Date
    let dayStartMinutes: Int

    var body: some View {
        NavigationStack {
            HydrationDayScreen(day: day, dayStartMinutes: dayStartMinutes)
        }
    }
}

private enum HydrationEntryAction {
    case open
    case addDetails
    case edit
    case logAgain
    case viewFood
    case delete
}

private struct HydrationDayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.scenePhase) private var scenePhase

    @Query private var users: [User]

    let dayStartMinutes: Int

    @State private var now = Date()
    @State private var pager: DayPagerState
    @State private var logToEdit: LoggedEntry?
    @State private var entryForDetails: LoggedEntry?
    @State private var entryToView: LoggedEntry?
    @State private var entryToEdit: LoggedEntry?
    @State private var entryToLogAgain: LoggedEntry?
    @State private var foodToView: FoodItem?
    @State private var showLogDrink = false
    @State private var showDatePicker = false

    init(day: Date, dayStartMinutes: Int) {
        self.dayStartMinutes = dayStartMinutes
        let today = Calendar.current.logicalDay(for: .now, dayStartMinutes: dayStartMinutes)
        _pager = State(initialValue: DayPagerState(day: day, lastDay: today))
    }

    private var logicalToday: Date {
        Calendar.current.logicalDay(for: now, dayStartMinutes: dayStartMinutes)
    }

    private var nextDayStart: Date {
        Calendar.current.logicalDayRange(for: logicalToday, dayStartMinutes: dayStartMinutes).upperBound
    }

    private var unit: VolumeUnit {
        users.first?.volumeUnit ?? .localeDefault
    }

    private func goalML(for day: Date) -> Double? {
        users.first?.goalTimeline.goals(for: day)?.waterGoalML
    }

    var body: some View {
        let unit = unit
        let logicalToday = logicalToday

        DayPager(state: pager, bottomMargin: 24) { day in
            HydrationDayPage(
                day: day,
                dayStartMinutes: dayStartMinutes,
                logicalToday: logicalToday,
                unit: unit,
                goalML: goalML(for: day),
                onAction: perform
            )
        } week: { weekDates in
            HydrationWeekTotals(
                weekStart: weekDates.first ?? pager.currentWeekStart,
                dayStartMinutes: dayStartMinutes
            ) { totals in
                HydrationWeekStrip(
                    days: weekDates,
                    totals: totals,
                    goalML: goalML(for:),
                    selectedDay: pager.displayDate,
                    logicalToday: logicalToday,
                    unit: unit,
                    onSelect: pager.navigate(to:)
                )
            }
        }
        .background(Color.background)
        .navigationTitle("Hydration")
        .navigationSubtitle(pager.displayDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: nextDayStart) {
            let delay = nextDayStart.timeIntervalSinceNow + 1
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            now = Date()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                now = Date()
            }
        }
        .onChange(of: logicalToday) { _, newToday in
            pager.setLastDay(newToday)
        }
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

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .background(
                            Color.clear
                                .popover(isPresented: $showDatePicker) {
                                    datePicker
                                }
                        )
                }
                .accessibilityLabel("Choose Date")

                Button {
                    showLogDrink = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log Drink")
            }
        }
        .navigationDestination(item: $entryForDetails) { entry in
            LoggedEntryDetailView(
                entry: entry,
                isPushedView: true,
                startsEditing: true
            )
        }
        .navigationDestination(item: $entryToView) { entry in
            LoggedEntryDetailView(entry: entry, isPushedView: true)
        }
        .navigationDestination(item: $entryToEdit) { entry in
            LoggedEntryDetailView(entry: entry, isPushedView: true, startsEditing: true)
        }
        .navigationDestination(item: $foodToView) { food in
            FoodDetailView(food: food)
        }
        .sheet(item: $logToEdit) { entry in
            LogDrinkSheet(editing: entry)
        }
        .sheet(item: $entryToLogAgain) { previousEntry in
            if let food = previousEntry.originalFoodItem {
                if food.type == .recipe {
                    LogRecipeView(recipe: food, previousEntry: previousEntry)
                } else {
                    LogEntryView(food: food, previousEntry: previousEntry)
                }
            }
        }
        .sheet(isPresented: $showLogDrink) {
            LogDrinkSheet(day: pager.displayDate, dayStartMinutes: dayStartMinutes, logicalToday: logicalToday)
        }
    }

    private var datePicker: some View {
        VStack(spacing: 0) {
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { pager.selectedDate },
                    set: { newDate in
                        showDatePicker = false
                        pager.navigate(to: newDate)
                    }
                ),
                in: ...logicalToday,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)

            Button("Today") {
                showDatePicker = false
                pager.navigate(to: logicalToday)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .frame(width: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func perform(_ action: HydrationEntryAction, on entry: LoggedEntry) {
        switch action {
        case .open:
            if entry.isHydrationLog {
                logToEdit = entry
            } else {
                entryToView = entry
            }
        case .addDetails:
            entryForDetails = entry
        case .edit:
            if entry.isHydrationLog {
                logToEdit = entry
            } else {
                entryToEdit = entry
            }
        case .logAgain:
            guard entry.isHydrationLog else {
                entryToLogAgain = entry
                return
            }
            EntryActions.logHydrationAgain(
                entry,
                dayStartMinutes: dayStartMinutes,
                unit: unit,
                in: modelContext,
                toastCenter: toastCenter
            )
        case .viewFood:
            foodToView = entry.originalFoodItem
        case .delete:
            EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter, fromMenu: true)
        }
    }
}

private struct HydrationDayPage: View {
    @Query private var weekEntries: [LoggedEntry]

    let day: Date
    let dayStartMinutes: Int
    let logicalToday: Date
    let unit: VolumeUnit
    let goalML: Double?
    var onAction: (HydrationEntryAction, LoggedEntry) -> Void

    init(
        day: Date,
        dayStartMinutes: Int,
        logicalToday: Date,
        unit: VolumeUnit,
        goalML: Double?,
        onAction: @escaping (HydrationEntryAction, LoggedEntry) -> Void
    ) {
        self.day = day
        self.dayStartMinutes = dayStartMinutes
        self.logicalToday = logicalToday
        self.unit = unit
        self.goalML = goalML
        self.onAction = onAction
        _weekEntries = Query(
            .hydrationLogs(from: DayPagerState.weekStart(of: day), days: 7, dayStartMinutes: dayStartMinutes)
        )
    }

    private var weekStart: Date {
        DayPagerState.weekStart(of: day)
    }

    private func weekAverageML(totals: [Date: Double]) -> Double? {
        let finished = DayPagerState.days(of: weekStart).filter { $0 < logicalToday }
        guard !finished.isEmpty else { return nil }
        return finished.reduce(0) { $0 + (totals[$1] ?? 0) } / Double(finished.count)
    }

    var body: some View {
        let calendar = Calendar.current
        let entries = weekEntries.filter {
            calendar.logicalDay(for: $0.timestamp, dayStartMinutes: dayStartMinutes) == day
        }
        let totals = hydrationTotalsByDay(weekEntries, dayStartMinutes: dayStartMinutes)

        VStack {
            summaryCard(entries: entries, weekAverage: weekAverageML(totals: totals))
                .padding(.horizontal)
            .padding(.top, 5)

            Card("Drinks") {
                TimelineList(
                    entries: entries,
                    emptyText: "No drinks logged.",
                    onSelectEntry: { onAction(.open, $0) }
                ) { entry in
                    menuItems(for: entry)
                }
            }
            .padding([.top, .horizontal])
        }
        .animation(.snappy, value: entries.map(\.id))
    }

    private func summaryCard(entries: [LoggedEntry], weekAverage: Double?) -> some View {
        let totalML = entries.reduce(0) { $0 + $1.hydrationML }
        let caffeineMg = entries.reduce(0) { $0 + $1.caffeineMg }
        let standardDrinks = DrinkAmounts.standardDrinks(alcoholGrams: entries.reduce(0) { $0 + $1.alcoholGrams })
        let drinkCalories = entries.filter { $0.entryType == .drink }.reduce(0) { $0 + $1.calories }
        let hasRows = caffeineMg > 0 || standardDrinks > 0 || drinkCalories > 0 || weekAverage != nil

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(unit.formattedTotalValue(totalML))
                        .font(.pageTitle)
                        .contentTransition(.numericText(value: totalML))

                    Text(unit.totalUnitLabel)
                        .font(.rowValue)
                        .foregroundStyle(.secondary)

                    if let goalML {
                        Text("/ \(unit.formattedTotal(goalML))")
                            .font(.rowValue)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)

                        WaterGoalStar(isReached: totalML >= goalML)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(unit.spokenProgress(totalML, goal: goalML))

                if let goalML {
                    HydrationBar(segments: HydrationSegment.timeline(from: entries), goalML: goalML, scrubUnit: unit)
                        .transition(.leadingReveal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, hasRows ? 4 : 16)
            .animation(.snappy, value: totalML)
            .animation(.snappy, value: goalML)

            RowGroup(.divider) {
                if drinkCalories > 0 {
                    statRow(.calorie, "Calories", value: "\(EntryHelper.formatMacro(drinkCalories)) kcal")
                }
                if caffeineMg > 0 {
                    statRow(.caffeine, "Caffeine", value: "\(caffeineMg.formatted(.number.precision(.fractionLength(0)))) mg")
                }
                if standardDrinks > 0 {
                    statRow(
                        .alcohol,
                        "Alcohol",
                        value: DrinkAmounts.standardDrinksText(standardDrinks)
                    )
                }
                if let weekAverage {
                    BaseRowLayout(
                        icon: .customSymbol("calendar.circle.fill", tint: DrinkTint.blue.color),
                        title: String(localized: "Week Average"),
                        info: String(localized: "Average per day for the week shown. Today counts once it ends.")
                    ) {
                        Spacer(minLength: 0)
                        Text(unit.formattedTotal(weekAverage))
                            .font(.rowValue)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: weekAverage))
                    }
                }
            }
            .animation(.snappy, value: weekAverage)
        }
    }

    private func statRow(_ icon: RowIcon, _ title: String, value: String) -> some View {
        BaseRowLayout(icon: icon, title: title) {
            Text(value)
                .font(.rowValue)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func menuItems(for entry: LoggedEntry) -> some View {
        if entry.isHydrationLog {
            Button {
                onAction(.addDetails, entry)
            } label: {
                Label("Add Details", systemImage: "square.and.pencil")
            }

            Divider()
        }

        if EntryActions.canLogAgain(entry) {
            Button {
                onAction(.logAgain, entry)
            } label: {
                Label("Log Again", systemImage: "plus.square.on.square")
            }
        }

        Button {
            onAction(.edit, entry)
        } label: {
            Label(entry.isHydrationLog ? "Edit Drink" : "Edit Entry", systemImage: "pencil")
        }

        if let food = entry.originalFoodItem {
            Button {
                onAction(.viewFood, entry)
            } label: {
                Label(food.viewActionTitle, systemImage: "book.pages")
            }
        }

        Divider()

        Button(role: .destructive) {
            onAction(.delete, entry)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

extension FetchDescriptor where T == LoggedEntry {
    static func hydrationLogs(from day: Date, days: Int, dayStartMinutes: Int) -> FetchDescriptor<LoggedEntry> {
        let calendar = Calendar.current
        let lastDay = calendar.date(byAdding: .day, value: days - 1, to: day) ?? day
        let start = calendar.logicalDayRange(for: day, dayStartMinutes: dayStartMinutes).lowerBound
        let end = calendar.logicalDayRange(for: lastDay, dayStartMinutes: dayStartMinutes).upperBound
        let drinkType = EntryType.drink.rawValue
        return FetchDescriptor(
            predicate: #Predicate<LoggedEntry> { entry in
                entry.timestamp >= start && entry.timestamp < end
                    && entry.parentEntry == nil
                    && (entry.isHydrationLog || entry.typeRawValue == drinkType || entry.volumeML > 0)
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
    }
}

private func hydrationTotalsByDay(_ entries: [LoggedEntry], dayStartMinutes: Int) -> [Date: Double] {
    entries.reduce(into: [:]) { totals, entry in
        let day = Calendar.current.logicalDay(for: entry.timestamp, dayStartMinutes: dayStartMinutes)
        totals[day, default: 0] += entry.hydrationML
    }
}

private struct HydrationWeekTotals<Content: View>: View {
    @Query private var entries: [LoggedEntry]

    let dayStartMinutes: Int
    let content: ([Date: Double]) -> Content

    init(weekStart: Date, dayStartMinutes: Int, @ViewBuilder content: @escaping ([Date: Double]) -> Content) {
        self.dayStartMinutes = dayStartMinutes
        self.content = content
        _entries = Query(.hydrationLogs(from: weekStart, days: 7, dayStartMinutes: dayStartMinutes))
    }

    var body: some View {
        content(hydrationTotalsByDay(entries, dayStartMinutes: dayStartMinutes))
    }
}

private struct HydrationWeekStrip: View {
    let days: [Date]
    let totals: [Date: Double]
    let goalML: (Date) -> Double?
    let selectedDay: Date
    let logicalToday: Date
    let unit: VolumeUnit
    var onSelect: (Date) -> Void

    private func score(for day: Date) -> DayGoalScore? {
        guard day <= logicalToday, let total = totals[day] else { return nil }
        guard let goal = goalML(day), goal > 0 else { return .unscored }
        return DayGoalScore(
            fraction: min(total / goal, 1),
            allHit: total >= goal
        )
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { day in
                dayColumn(day)

                if day != days.last {
                    Spacer()
                }
            }
        }
    }

    private func dayColumn(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isFuture = day > logicalToday
        let isToday = calendar.isDate(day, inSameDayAs: logicalToday)
        let score = score(for: day)

        return VStack(spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.sectionTitle)
                .foregroundColor(
                    isSelected
                        ? .white
                        : isToday ? .accentColor : isFuture ? .tertiaryText : .primary
                )
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(isSelected ? Color.accentColor : Color.clear)
                )

            DayProgressCircle(score: score, fill: DrinkTint.blue.color)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture else { return }
            onSelect(day)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(accessibilityValue(for: day, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            guard !isFuture else { return }
            onSelect(day)
        }
    }

    private func accessibilityValue(for day: Date, isToday: Bool) -> String {
        var parts: [String] = []
        if isToday {
            parts.append(String(localized: "Today"))
        }
        if day <= logicalToday {
            parts.append(unit.spokenProgress(totals[day] ?? 0, goal: goalML(day)))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = container.mainContext
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: context)
    let drinks = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
    if let water = drinks.first(where: { $0.seedKey == "water" }),
        let coffee = drinks.first(where: { $0.seedKey == "coffee" })
    {
        _ = try? HydrationLogger.log(coffee, volumeML: 350, sizeName: "Mug", at: .now, in: context)
        _ = try? HydrationLogger.log(water, volumeML: 500, sizeName: "Bottle", at: .now, in: context)
        for offset in 1...10 {
            if let day = Calendar.current.date(byAdding: .day, value: -offset, to: .now) {
                _ = try? HydrationLogger.log(water, volumeML: Double(offset % 5 + 1) * 400, sizeName: nil, at: day, in: context)
            }
        }
    }

    return HydrationDayView(day: .now, dayStartMinutes: 0)
    .modelContainer(container)
}
