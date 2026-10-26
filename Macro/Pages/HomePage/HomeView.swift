//
//  HomeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.tabBarHeight) private var tabBarHeight
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    @Query private var users: [User]
    @Query(filter: EntryDraft.logDraftsPredicate) private var logDrafts:
        [EntryDraft]

    @State private var showDatePicker = false
    @State private var showSharePopover = false
    @State private var showSettingsSheet = false

    @State private var entryToLogAgain: LoggedEntry? = nil
    @State private var entryToAddToLibrary: LoggedEntry? = nil
    @State private var foodToView: FoodItem? = nil

    @State private var clickedEntry: LoggedEntry? = nil
    @State private var drinkLogToEdit: LoggedEntry? = nil
    @State private var drinkLogForDetails: LoggedEntry? = nil
    @State private var entryToEdit: LoggedEntry? = nil

    @State private var clickedDraft: EntryDraft? = nil

    @State private var drinkLogDay: HydrationDayRequest? = nil
    @State private var hydrationDay: HydrationDayRequest? = nil
    @State private var showManageDrinks = false
    @State private var showWaterGoal = false

    @State private var pager = DayPagerState(day: Date())

    private enum HomeSheet: CaseIterable {
        case settings, logDrink, waterGoal, manageDrinks, hydrationDay, entry, editDrinkLog
        case drinkLogDetails, editEntry, draft, addToLibrary, food, logAgain
    }

    private var shownSheets: Set<HomeSheet> {
        Set(HomeSheet.allCases.filter(isShown))
    }

    private func isShown(_ sheet: HomeSheet) -> Bool {
        switch sheet {
        case .settings: showSettingsSheet
        case .logDrink: drinkLogDay != nil
        case .waterGoal: showWaterGoal
        case .manageDrinks: showManageDrinks
        case .hydrationDay: hydrationDay != nil
        case .entry: clickedEntry != nil
        case .editDrinkLog: drinkLogToEdit != nil
        case .drinkLogDetails: drinkLogForDetails != nil
        case .editEntry: entryToEdit != nil
        case .draft: clickedDraft != nil
        case .addToLibrary: entryToAddToLibrary != nil
        case .food: foodToView != nil
        case .logAgain: entryToLogAgain != nil
        }
    }

    private func clear(_ sheet: HomeSheet) {
        switch sheet {
        case .settings: showSettingsSheet = false
        case .logDrink: drinkLogDay = nil
        case .waterGoal: showWaterGoal = false
        case .manageDrinks: showManageDrinks = false
        case .hydrationDay: hydrationDay = nil
        case .entry: clickedEntry = nil
        case .editDrinkLog: drinkLogToEdit = nil
        case .drinkLogDetails: drinkLogForDetails = nil
        case .editEntry: entryToEdit = nil
        case .draft: clickedDraft = nil
        case .addToLibrary: entryToAddToLibrary = nil
        case .food: foodToView = nil
        case .logAgain: entryToLogAgain = nil
        }
    }
    @State private var hasAlignedToday = false
    @State private var now = Date()

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private let hiddenCirclesInset: CGFloat = 34

    private var dayCircleMode: DayCircleMode {
        users.first?.dayCircleMode ?? .goalProgress
    }

    private var logicalToday: Date {
        Calendar.current.logicalDay(for: now, dayStartMinutes: dayStartMinutes)
    }

    private var nextDayStart: Date {
        Calendar.current.logicalDayRange(
            for: logicalToday,
            dayStartMinutes: dayStartMinutes
        ).upperBound
    }

    private func dayAccessibilityValue(
        score: DayGoalScore?,
        isToday: Bool,
        isDraftDay: Bool
    ) -> String {
        var parts: [String] = []
        if isToday {
            parts.append(String(localized: "Today"))
        }
        if dayCircleMode != .off {
            if let score {
                if score.allHit {
                    let hit: String =
                        switch (dayCircleMode == .oneGoal, isDraftDay) {
                        case (true, true): String(localized: "Goal hit, pending drafts")
                        case (true, false): String(localized: "Goal hit")
                        case (false, true): String(localized: "All goals hit, pending drafts")
                        case (false, false): String(localized: "All goals hit")
                        }
                    parts.append(hit)
                } else if !score.isScored {
                    parts.append(String(localized: "Logged"))
                } else {
                    let percent = score.fraction.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                    parts.append(
                        dayCircleMode == .oneGoal
                            ? String(localized: "\(percent) of goal")
                            : String(localized: "\(percent) of goals")
                    )
                }
            } else {
                parts.append(String(localized: "Nothing logged"))
            }
        }
        let isPendingStar = dayCircleMode != .off && score?.allHit == true
        if isDraftDay && !isPendingStar {
            parts.append(String(localized: "Has drafts"))
        }
        return parts.joined(separator: ", ")
    }

    private func alignToLogicalToday() {
        guard !hasAlignedToday else { return }
        hasAlignedToday = true
        jumpToLogicalToday()
    }

    private func jumpToLogicalToday() {
        pager.jump(to: logicalToday)
    }

    private func isFavorited(_ entry: LoggedEntry) -> Bool {
        entry.originalFoodItem?.favoriteEntry != nil
    }

    private func link(_ entry: LoggedEntry, to food: FoodItem) {
        entry.originalFoodItem = food
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Link to Library"), message: food.name)
            )
        }
    }

    private func toggleFavorite(for entry: LoggedEntry) {
        guard let food = entry.originalFoodItem else { return }
        EntryActions.toggleFavorite(food, in: modelContext, toastCenter: toastCenter)
    }

    private var tracksHydration: Bool {
        users.first?.tracksHydration ?? true
    }

    private func hideHydration() {
        guard let user = users.first else { return }
        withAnimation(.snappy) {
            user.tracksHydration = false
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Hide Hydration")))
            return
        }
        toastCenter?.show(
            Toast(
                group: Toast.goalsGroup,
                symbol: "eye.slash",
                title: String(localized: "Hydration Hidden"),
                message: String(localized: "You can turn it back on in Settings"),
                action: Toast.Action(title: String(localized: "Undo")) { [modelContext] in
                    withAnimation(.snappy) {
                        user.tracksHydration = true
                    }
                    try? modelContext.save()
                }
            )
        )
    }

    private func deleteEntry(_ entry: LoggedEntry) {
        EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter, fromMenu: true)
    }

    private func deleteDraft(_ draft: EntryDraft) {
        EntryActions.delete(draft, in: modelContext, toastCenter: toastCenter, fromMenu: true)
    }

    private func currDate(for date: Date) -> String {
        let format = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        let sameYear = Calendar.current.isDate(
            date,
            equalTo: .now,
            toGranularity: .year
        )
        return date.formatted(sameYear ? format : format.year())
    }

    private var draftDays: Set<Date> {
        let dayStartMinutes = dayStartMinutes
        return Set(
            logDrafts.compactMap { draft in
                draft.timestamp.map {
                    Calendar.current.logicalDay(
                        for: $0,
                        dayStartMinutes: dayStartMinutes
                    )
                }
            }
        )
    }

    var body: some View {
        let draftDays = draftDays
        let logicalToday = logicalToday
        let goalTimeline = users.first?.goalTimeline
        let currentGoals = goalTimeline?.current?.goals

        NavigationStack {
            DayPager(
                state: pager,
                stripHeight: dayCircleMode == .off ? 90 - hiddenCirclesInset : 90,
                bottomMargin: tabBarHeight + 28,
                indicatorBottomMargin: tabBarHeight
            ) { effectiveDate in
                VStack {
                    if syncMonitor.isInitialRestoreInProgress {
                        ICloudRestoreCard()
                            .padding([.horizontal, .bottom])
                            .padding(.top, 5)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    if let currentGoals,
                        let dayGoals = goalTimeline?.goals(for: effectiveDate)
                    {
                        ProgressCard(
                            goals: dayGoals,
                            date: effectiveDate,
                            dayStartMinutes: dayStartMinutes,
                            isPastGoals: !dayGoals.hasSameMacroTargets(as: currentGoals)
                        )
                        .padding([.horizontal, .bottom])
                        .padding(.top, syncMonitor.isInitialRestoreInProgress ? 0 : 5)
                    }

                    if users.first?.tracksHydration ?? true {
                        HydrationCard(
                            date: effectiveDate,
                            dayStartMinutes: dayStartMinutes,
                            logicalToday: logicalToday,
                            goalML: goalTimeline?.goals(for: effectiveDate)?.waterGoalML,
                            unit: users.first?.volumeUnit ?? .localeDefault,
                            onLogDrink: { drink in
                                drinkLogDay = HydrationDayRequest(day: effectiveDate, drink: drink)
                            },
                            onViewHydration: {
                                hydrationDay = HydrationDayRequest(day: effectiveDate)
                            },
                            onManageDrinks: {
                                showManageDrinks = true
                            },
                            onEditGoal: currentGoals == nil
                                ? nil : { showWaterGoal = true },
                            promptsForGoal: currentGoals != nil && currentGoals?.waterGoalML == nil
                                && !(users.first?.skipsWaterGoalPrompt ?? false),
                            hasWaterGoal: currentGoals?.waterGoalML != nil,
                            onHide: hideHydration
                        )
                        .padding([.horizontal, .bottom])
                        .padding(
                            .top,
                            currentGoals == nil && !syncMonitor.isInitialRestoreInProgress ? 5 : 0
                        )
                        .transition(.opacity)
                    }

                    TimelineCard(
                        date: effectiveDate,
                        dayStartMinutes: dayStartMinutes,
                        showsAllDrinks: !tracksHydration,
                        clickedEntry: Binding(
                            get: { clickedEntry },
                            set: { entry in
                                if let entry,
                                    EntryActions.opensAsHydrationLog(entry, tracksHydration: tracksHydration)
                                {
                                    drinkLogToEdit = entry
                                } else {
                                    clickedEntry = entry
                                }
                            }
                        ),
                        clickedDraft: $clickedDraft,
                        onDeleteDraft: { draft in
                            deleteDraft(draft)
                        }
                    ) { entry in
                        let opensAsHydrationLog = EntryActions.opensAsHydrationLog(
                            entry,
                            tracksHydration: tracksHydration
                        )
                        if opensAsHydrationLog {
                            Button {
                                drinkLogForDetails = entry
                            } label: {
                                Label("Add Details", systemImage: "square.and.pencil")
                            }

                            Divider()
                        }

                        if EntryActions.canLogAgain(entry, tracksHydration: tracksHydration) {
                            Button {
                                if opensAsHydrationLog {
                                    EntryActions.logHydrationAgain(
                                        entry,
                                        dayStartMinutes: dayStartMinutes,
                                        unit: users.first?.volumeUnit ?? .localeDefault,
                                        in: modelContext,
                                        toastCenter: toastCenter
                                    )
                                } else {
                                    entryToLogAgain = entry
                                }
                            } label: {
                                Label(
                                    "Log Again",
                                    systemImage: "plus.square.on.square"
                                )
                            }
                        } else if entry.originalFoodItem == nil {
                            Button {
                                entryToAddToLibrary = entry
                            } label: {
                                Label(
                                    "Add to Library",
                                    systemImage: "plus.square.dashed"
                                )
                            }
                        }

                        Button {
                            if opensAsHydrationLog {
                                drinkLogToEdit = entry
                            } else {
                                entryToEdit = entry
                            }
                        } label: {
                            Label(
                                opensAsHydrationLog ? "Edit Drink" : "Edit Entry",
                                systemImage: "pencil"
                            )
                        }

                        if let food = entry.originalFoodItem {
                            Button {
                                foodToView = food
                            } label: {
                                Label(food.viewActionTitle, systemImage: "book.pages")
                            }

                            Button {
                                toggleFavorite(for: entry)
                            } label: {
                                Label(
                                    isFavorited(entry)
                                        ? "Unfavorite Entry"
                                        : "Favorite Entry",
                                    systemImage: isFavorited(entry)
                                        ? "star.slash" : "star"
                                )
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .padding(.horizontal)
                    .padding(
                        .top,
                        currentGoals == nil && !(users.first?.tracksHydration ?? true)
                            && !syncMonitor.isInitialRestoreInProgress ? 5 : 0
                    )
                }
                .animation(.snappy, value: syncMonitor.isInitialRestoreInProgress)
            } week: { weekDates in
                WeekGoalScores(
                    weekDates: weekDates,
                    goalTimeline: goalTimeline
                        ?? GoalTimeline([], dayStartMinutes: dayStartMinutes),
                    mode: dayCircleMode,
                    goals: users.first?.scoredDayCircleGoals ?? [],
                    showsAllDrinks: !tracksHydration,
                    countsDrinkOnlyDays: users.first?.dayCirclesIncludeWater ?? true,
                    dayStartMinutes: dayStartMinutes,
                    logicalToday: logicalToday
                ) { scores in
                    HStack {
                        ForEach(weekDates, id: \.self) { date in
                            let isSelected = Calendar.current.isDate(
                                date,
                                inSameDayAs: pager.displayDate
                            )
                            let isToday = Calendar.current.isDate(
                                date,
                                inSameDayAs: logicalToday
                            )

                            let isDraftDay = draftDays.contains(
                                Calendar.current.startOfDay(for: date)
                            )

                            Group {
                                if dayCircleMode == .off {
                                    VStack(spacing: 4) {
                                        Text(
                                            date.formatted(
                                                .dateTime.weekday(.narrow)
                                            )
                                        )
                                        .font(.detailEmphasis)
                                        .foregroundStyle(
                                            isToday ? Color.accentColor : .secondary
                                        )

                                        Text(
                                            date.formatted(.dateTime.day())
                                        )
                                        .font(.sectionTitle)
                                        .foregroundColor(
                                            isSelected
                                                ? .white
                                                : (isToday ? .accentColor : .primary)
                                        )
                                        .frame(width: 30, height: 30)
                                        .background(
                                            Circle().fill(
                                                isSelected
                                                    ? Color.accentColor : Color.clear
                                            )
                                        )
                                        .overlay(alignment: .bottom) {
                                            DraftDot(isVisible: isDraftDay)
                                        }
                                    }
                                    .frame(minWidth: 44)
                                    .contentShape(Rectangle())
                                } else {
                                    VStack(spacing: 12) {
                                        Text(
                                            date.formatted(
                                                .dateTime.weekday(.narrow)
                                            )
                                        )
                                        .font(.sectionTitle)
                                        .foregroundColor(
                                            isSelected
                                                ? .white
                                                : (isToday ? .accentColor : .primary)
                                        )
                                        .frame(width: 30, height: 30)
                                        .background(
                                            Circle().fill(
                                                isSelected
                                                    ? Color.accentColor : Color.clear
                                            )
                                        )

                                        DayProgressCircle(
                                            score: scores[date],
                                            hasDrafts: isDraftDay
                                        )
                                    }
                                }
                            }
                            .onTapGesture {
                                pager.navigate(to: date)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(currDate(for: date))
                            .accessibilityValue(
                                dayAccessibilityValue(
                                    score: scores[date],
                                    isToday: isToday,
                                    isDraftDay: isDraftDay
                                )
                            )
                            .accessibilityAddTraits(
                                isSelected ? [.isButton, .isSelected] : .isButton
                            )
                            .accessibilityAction {
                                pager.navigate(to: date)
                            }

                            if date != weekDates.last {
                                Spacer()
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Home")
            .navigationSubtitle(currDate(for: pager.displayDate))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                alignToLogicalToday()
            }
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
            .onChange(of: dayStartMinutes) { oldMinutes, _ in
                let previousToday = Calendar.current.logicalDay(
                    for: Date(),
                    dayStartMinutes: oldMinutes
                )
                guard pager.selectedDate == previousToday else { return }
                jumpToLogicalToday()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSharePopover = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .background(
                                Color.clear
                                    .popover(isPresented: $showSharePopover) {
                                        Text("Coming soon!")
                                            .padding(70)
                                            .presentationCompactAdaptation(
                                                .popover
                                            )
                                    }
                            )
                    }

                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .background(
                                Color.clear
                                    .popover(isPresented: $showDatePicker) {
                                        VStack(spacing: 0) {
                                            DatePicker(
                                                "Select Date",
                                                selection: Binding(
                                                    get: { pager.selectedDate },
                                                    set: { newDate in
                                                        showDatePicker = false
                                                        pager.navigate(
                                                            to: newDate
                                                        )
                                                    }
                                                ),
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
                                        .onChange(of: pager.selectedDate) {
                                            oldDate,
                                            newDate in
                                            showDatePicker = false
                                        }
                                    }
                            )
                    }

                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .onChange(of: shownSheets) { old, new in
                let opened = new.subtracting(old)
                guard !opened.isEmpty else { return }
                for sheet in new.subtracting(opened) {
                    clear(sheet)
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $drinkLogDay) { request in
                LogDrinkSheet(
                    day: request.day,
                    dayStartMinutes: dayStartMinutes,
                    logicalToday: logicalToday,
                    drink: request.drink
                )
            }
            .sheet(isPresented: $showWaterGoal) {
                WaterGoalSheet()
            }
            .sheet(isPresented: $showManageDrinks) {
                DrinkListView(mode: .manage)
                    .environment(\.tabBarHeight, 0)
            }
            .hydrationDaySheet(item: $hydrationDay, dayStartMinutes: dayStartMinutes)
            .sheet(item: $clickedEntry) { entry in
                NavigationStack {
                    LoggedEntryDetailView(entry: entry, isPushedView: false)
                }
                .environment(\.tabBarHeight, 0)
            }
            .sheet(item: $drinkLogToEdit) { entry in
                LogDrinkSheet(editing: entry)
                    .environment(\.tabBarHeight, 0)
            }
            .sheet(item: $drinkLogForDetails) { entry in
                NavigationStack {
                    LoggedEntryDetailView(
                        entry: entry,
                        isPushedView: false,
                        startsEditing: true
                    )
                }
                .environment(\.tabBarHeight, 0)
            }
            .sheet(item: $entryToEdit) { entry in
                NavigationStack {
                    LoggedEntryDetailView(
                        entry: entry,
                        isPushedView: false,
                        startsEditing: true
                    )
                }
                .environment(\.tabBarHeight, 0)
            }
            .sheet(item: $clickedDraft) { draft in
                if draft.isAvailable, let food = draft.foodItem {
                    if draft.kind == .logRecipe {
                        LogRecipeView(
                            recipe: food,
                            draft: draft
                        )
                    } else {
                        LogEntryView(
                            food: food,
                            draft: draft
                        )
                    }
                }
            }
            .sheet(item: $entryToAddToLibrary) { entry in
                if entry.libraryEntryType == .recipe {
                    AddRecipeView(
                        offersLogNow: true,
                        prefill: entry.addRecipePrefill,
                        onCreate: { food in link(entry, to: food) }
                    )
                } else {
                    AddEntryView(
                        entryType: entry.libraryEntryType,
                        offersLogNow: true,
                        prefill: entry.addEntryPrefill,
                        onCreate: { food in link(entry, to: food) }
                    )
                }
            }
            .sheet(item: $foodToView) { food in
                NavigationStack {
                    FoodDetailView(food: food, isPushedView: false)
                }
                .environment(\.tabBarHeight, 0)
            }
            .sheet(item: $entryToLogAgain) { previousEntry in
                Group {
                    if let foodToLog = previousEntry.originalFoodItem {
                        if foodToLog.type == .recipe {
                            LogRecipeView(
                                recipe: foodToLog,
                                previousEntry: previousEntry
                            )
                        } else {
                            LogEntryView(
                                food: foodToLog,
                                previousEntry: previousEntry
                            )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(CloudSyncMonitor())
}
