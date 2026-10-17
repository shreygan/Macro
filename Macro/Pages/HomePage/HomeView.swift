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
    @State private var entryToEdit: LoggedEntry? = nil

    @State private var clickedDraft: EntryDraft? = nil

    @State private var swapTargetDate: Date? = nil
    @State private var swapSubstituteDate: Date? = nil

    @State private var selectedDate: Date = Calendar.current.startOfDay(
        for: Date()
    )

    @State private var displayDate: Date = Calendar.current.startOfDay(
        for: Date()
    )

    @State private var bufferDates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-500...500).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
    }()

    @State private var bufferWeeks: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart =
            calendar.date(
                from: calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: today
                )
            ) ?? today

        return (-50...50).compactMap {
            calendar.date(
                byAdding: .weekOfYear,
                value: $0,
                to: currentWeekStart
            )
        }
    }()

    @State private var currentWeekStart: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: today
            )
        ) ?? today
    }()

    @State private var swipeDirection: Edge = .trailing
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
                    parts.append(
                        isDraftDay
                            ? String(localized: "All goals hit, pending drafts")
                            : String(localized: "All goals hit")
                    )
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
        let calendar = Calendar.current
        let today = logicalToday
        guard selectedDate != today else { return }

        currentWeekStart =
            calendar.date(
                from: calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: today
                )
            ) ?? currentWeekStart
        selectedDate = today
        displayDate = today
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

    private func deleteEntry(_ entry: LoggedEntry) {
        EntryActions.delete(entry, in: modelContext, toastCenter: toastCenter)
    }

    private func deleteDraft(_ draft: EntryDraft) {
        EntryActions.delete(draft, in: modelContext, toastCenter: toastCenter)
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

    private var currentWeekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: currentWeekStart)
        }
    }

    private func shiftBufferIfNeeded(for date: Date) {
        guard let index = bufferDates.firstIndex(of: date) else { return }
        let threshold = 50

        if index < threshold || index > bufferDates.count - threshold {
            let calendar = Calendar.current
            bufferDates = (-500...500).compactMap {
                calendar.date(byAdding: .day, value: $0, to: date)
            }
        }
    }

    private func shiftBufferWeeksIfNeeded(for week: Date) {
        guard let index = bufferWeeks.firstIndex(of: week) else { return }
        let threshold = 10

        if index < threshold || index > bufferWeeks.count - threshold {
            let calendar = Calendar.current
            bufferWeeks = (-50...50).compactMap {
                calendar.date(byAdding: .weekOfYear, value: $0, to: week)
            }
        }
    }

    private func navigateToDate(to newDate: Date) {
        let calendar = Calendar.current

        guard selectedDate != newDate else { return }

        swipeDirection = newDate > selectedDate ? .trailing : .leading

        withAnimation {
            displayDate = newDate
        }

        let dayDifference = abs(
            calendar.dateComponents([.day], from: selectedDate, to: newDate).day
                ?? 0
        )

        if dayDifference <= 1 {
            withAnimation {
                selectedDate = newDate
            }
        } else {
            let isTrailing = newDate > selectedDate
            let adjacentDate = calendar.date(
                byAdding: .day,
                value: isTrailing ? -1 : 1,
                to: newDate
            )!

            swapTargetDate = adjacentDate
            swapSubstituteDate = selectedDate

            selectedDate = adjacentDate

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.selectedDate = newDate
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if self.selectedDate == newDate {
                        self.swapTargetDate = nil
                        self.swapSubstituteDate = nil
                    }
                }
            }
        }
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
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(bufferDates, id: \.self) { date in

                        let effectiveDate =
                            (date == swapTargetDate
                                && swapSubstituteDate != nil)
                            ? swapSubstituteDate! : date

                        ScrollView {
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
                                        isPastGoals: !dayGoals.hasSameTargets(as: currentGoals)
                                    )
                                    .padding([.horizontal, .bottom])
                                    .padding(.top, syncMonitor.isInitialRestoreInProgress ? 0 : 5)
                                }

                                TimelineCard(
                                    date: effectiveDate,
                                    dayStartMinutes: dayStartMinutes,
                                    clickedEntry: $clickedEntry,
                                    clickedDraft: $clickedDraft,
                                    onDeleteDraft: { draft in
                                        deleteDraft(draft)
                                    }
                                ) { entry in
                                    if entry.originalFoodItem != nil {
                                        Button {
                                            entryToLogAgain = entry
                                        } label: {
                                            Label(
                                                "Log Again",
                                                systemImage: "plus.square.on.square"
                                            )
                                        }
                                    } else {
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
                                        entryToEdit = entry
                                    } label: {
                                        Label(
                                            "Edit Entry",
                                            systemImage: "pencil"
                                        )
                                    }

                                    if let food = entry.originalFoodItem {
                                        Button {
                                            foodToView = food
                                        } label: {
                                            Label(
                                                "View in Library",
                                                systemImage: "book.pages"
                                            )
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
                                    currentGoals == nil && !syncMonitor.isInitialRestoreInProgress ? nil : 0
                                )
                            }
                            .animation(.snappy, value: syncMonitor.isInitialRestoreInProgress)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(
                                            of: geo.frame(
                                                in: .named("MainTabView")
                                            ).minX
                                        ) { oldX, newX in
                                            if abs(newX) < 1.0
                                                && selectedDate == date
                                            {
                                                if displayDate != date
                                                    && swapTargetDate == nil
                                                {
                                                    withAnimation {
                                                        displayDate = date
                                                    }
                                                }
                                            }
                                        }
                                }
                            )
                        }
                        .contentMargins(
                            .bottom,
                            tabBarHeight + 28,
                            for: .scrollContent
                        )
                        .contentMargins(
                            .bottom,
                            tabBarHeight,
                            for: .scrollIndicators
                        )
                        .scrollEdgeEffectStyle(.hard, for: .top)
                        .modifier(ScrolledTopEdgeEffect())
                        .safeAreaBar(edge: .top) {
                            Color.primary.opacity(0.001).frame(
                                height: dayCircleMode == .off
                                    ? 97.5 - hiddenCirclesInset : 97.5
                            )
                        }
                        .containerRelativeFrame(.horizontal)
                        .id(date)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(
                id: Binding<Date?>(
                    get: { selectedDate },
                    set: { newDate in
                        if let newDate {
                            selectedDate = newDate
                        }
                    }
                )
            )
            .scrollIndicators(.hidden, axes: .horizontal)
            .scrollEdgeEffectHidden(true, for: .top)
            .coordinateSpace(name: "MainTabView")
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                TabView(selection: $currentWeekStart) {
                    ForEach(bufferWeeks, id: \.self) { weekStart in

                        let weekDates = (0..<7).compactMap {
                            Calendar.current.date(
                                byAdding: .day,
                                value: $0,
                                to: weekStart
                            )
                        }

                        WeekGoalScores(
                            weekDates: weekDates,
                            goalTimeline: goalTimeline
                                ?? GoalTimeline([], dayStartMinutes: dayStartMinutes),
                            mode: dayCircleMode,
                            goal: users.first?.resolvedDayCircleGoal ?? .calories,
                            dayStartMinutes: dayStartMinutes,
                            logicalToday: logicalToday
                        ) { scores in
                            HStack {
                                ForEach(weekDates, id: \.self) { date in
                                    let isSelected = Calendar.current.isDate(
                                        date,
                                        inSameDayAs: displayDate
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
                                    .animation(
                                        .easeInOut(duration: 0.25),
                                        value: draftDays
                                    )
                                    .onTapGesture {
                                        navigateToDate(to: date)
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
                                        navigateToDate(to: date)
                                    }

                                    if date != weekDates.last {
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .tag(weekStart)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: dayCircleMode == .off ? 90 - hiddenCirclesInset : 90)
            }
            .navigationTitle("Home")
            .navigationSubtitle(currDate(for: displayDate))
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
                guard selectedDate == previousToday else { return }
                jumpToLogicalToday()
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                swipeDirection = newDate > oldDate ? .trailing : .leading

                let calendar = Calendar.current
                guard
                    let newWeekStart = calendar.date(
                        from: calendar.dateComponents(
                            [.yearForWeekOfYear, .weekOfYear],
                            from: newDate
                        )
                    )
                else { return }

                if newWeekStart != currentWeekStart {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentWeekStart = newWeekStart
                    }
                }

                shiftBufferIfNeeded(for: newDate)
            }
            .onChange(of: currentWeekStart) { oldWeek, newWeek in
                let calendar = Calendar.current

                if !calendar.isDate(
                    selectedDate,
                    equalTo: newWeek,
                    toGranularity: .weekOfYear
                ) {

                    let daysToShift =
                        calendar.dateComponents(
                            [.day],
                            from: oldWeek,
                            to: newWeek
                        ).day ?? 0
                    if let syncedDate = calendar.date(
                        byAdding: .day,
                        value: daysToShift,
                        to: selectedDate
                    ) {

                        swipeDirection =
                            newWeek > oldWeek ? .trailing : .leading
                        withAnimation {
                            selectedDate = syncedDate
                        }
                    }
                }

                shiftBufferWeeksIfNeeded(for: newWeek)
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
                                                    get: { selectedDate },
                                                    set: { newDate in
                                                        showDatePicker = false
                                                        navigateToDate(
                                                            to: newDate
                                                        )
                                                    }
                                                ),
                                                displayedComponents: [.date]
                                            )
                                            .datePickerStyle(.graphical)

                                            Button("Today") {
                                                showDatePicker = false
                                                navigateToDate(to: logicalToday)
                                            }
                                            .padding(.top, 8)
                                            .padding(.bottom, 24)
                                        }
                                        .padding(.horizontal)
                                        .frame(width: 320)
                                        .presentationCompactAdaptation(.popover)
                                        .onChange(of: selectedDate) {
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
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $clickedEntry) { entry in
                NavigationStack {
                    LoggedEntryDetailView(entry: entry, isPushedView: false)
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

private struct ScrolledTopEdgeEffect: ViewModifier {
    @State private var isScrolled = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 1
            } action: { _, newValue in
                isScrolled = newValue
            }
            .scrollEdgeEffectHidden(!isScrolled, for: .top)
    }
}

#Preview {
    HomeView()
        .environment(CloudSyncMonitor())
}
