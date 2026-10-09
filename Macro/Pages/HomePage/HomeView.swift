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

    private var dayStartMinutes: Int {
        users.first?.dayStartMinutes ?? 0
    }

    private var logicalToday: Date {
        Calendar.current.logicalDay(for: Date(), dayStartMinutes: dayStartMinutes)
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
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
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
                                if let userGoals = users.first?.currentGoals {
                                    ProgressCard(
                                        goals: userGoals,
                                        date: effectiveDate,
                                        dayStartMinutes: dayStartMinutes
                                    )
                                    .padding([.horizontal, .bottom])
                                    .padding(.top, 5)
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
                                        clickedEntry = entry
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
                                    users.first?.currentGoals == nil ? nil : 0
                                )
                            }
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
                            Color.primary.opacity(0.001).frame(height: 97.5)
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

                                VStack(spacing: 12) {
                                    Text(
                                        date.formatted(
                                            .dateTime.weekday(.narrow)
                                        )
                                    )
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(
                                        isSelected
                                            ? .white
                                            : (isToday ? .blue : .primary)
                                    )
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle().fill(
                                            isSelected
                                                ? Color.blue : Color.clear
                                        )
                                    )

                                    Circle()
                                        .fill(Color(uiColor: .systemGray5))
                                        .frame(width: 40, height: 40)
                                        .overlay(alignment: .bottom) {
                                            if draftDays.contains(
                                                Calendar.current.startOfDay(
                                                    for: date
                                                )
                                            ) {
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
                                        .animation(
                                            .easeInOut(duration: 0.25),
                                            value: draftDays
                                        )
                                }
                                .onTapGesture {
                                    navigateToDate(to: date)
                                }

                                if date != weekDates.last {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .tag(weekStart)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 90)
            }
            .navigationTitle("Home")
            .navigationSubtitle(currDate(for: displayDate))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                alignToLogicalToday()
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
            }
            .sheet(item: $clickedDraft) { draft in
                if draft.isAvailable, let food = draft.foodItem {
                    if draft.kind == .logRecipe {
                        LogRecipeView(
                            recipe: food,
                            draft: draft,
                            isPushedView: false
                        )
                    } else {
                        LogEntryView(
                            food: food,
                            draft: draft,
                            isPushedView: false
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
            }
            .sheet(item: $entryToLogAgain) { previousEntry in
                NavigationStack {
                    if let foodToLog = previousEntry.originalFoodItem {
                        if foodToLog.type == .recipe {
                            LogRecipeView(
                                recipe: foodToLog,
                                previousEntry: previousEntry,
                                isPushedView: false
                            )
                        } else {
                            LogEntryView(
                                food: foodToLog,
                                previousEntry: previousEntry,
                                isPushedView: false
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
}
