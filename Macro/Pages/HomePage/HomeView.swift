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

    @Query private var users: [User]

    @State private var showDatePicker = false
    @State private var showImportSheet = false
    @State private var showSharePopover = false
    @State private var showGoalSetupSheet = false
    @State private var showDeleteConfirmation = false

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

    private func deleteAllData() {
        do {
            try modelContext.delete(model: User.self)
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: EntrySource.self)
            try modelContext.delete(model: CategorySource.self)
            try modelContext.delete(model: FoodGroupSource.self)
            try modelContext.delete(model: ServingSizeUnit.self)
            try modelContext.delete(model: FavoriteEntry.self)
            try modelContext.delete(model: LoggedEntry.self)

            try modelContext.save()
            print("All data successfully cleared.")

            try AppSeeder.seedDefaults(into: modelContext)
            print("Default data successfully reseeded.")
        } catch {
            print(
                "Failed to clear or reseed data: \(error.localizedDescription)"
            )
        }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                                let isToday = Calendar.current.isDateInToday(
                                    date
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

                TabView(selection: $selectedDate) {
                    ForEach(bufferDates, id: \.self) { date in

                        let effectiveDate =
                            (date == swapTargetDate
                                && swapSubstituteDate != nil)
                            ? swapSubstituteDate! : date

                        ScrollView {
                            VStack {
                                if let userGoals = users.first?.goals {
                                    ProgressCard(
                                        goals: userGoals,
                                        date: effectiveDate
                                    )
                                    .padding()
                                }

                                TimelineCard(date: effectiveDate)
                                    .padding(.horizontal)
                                    .padding(.bottom, 24)
                                    .padding(
                                        .top,
                                        users.first?.goals == nil ? nil : 0
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
                            .tag(date)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .coordinateSpace(name: "MainTabView")
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.01),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Home")
            .navigationSubtitle(currDate(for: displayDate))
            .navigationBarTitleDisplayMode(.inline)
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
                                                let today = Calendar.current
                                                    .startOfDay(for: Date())
                                                showDatePicker = false
                                                navigateToDate(to: today)
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

                    Menu {
                        Button {
                            showImportSheet = true
                        } label: {
                            Label(
                                "Import...",
                                systemImage: "square.and.arrow.down"
                            )
                        }

                        Button {
                            showGoalSetupSheet = true
                        } label: {
                            Label("Update Goals", systemImage: "target")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportView()
            }
            .sheet(isPresented: $showGoalSetupSheet) {
                GoalSetupView(
                    isCalorieActive: .constant(false),
                    isProteinActive: .constant(false),
                    isCarbsActive: .constant(false),
                    isFatActive: .constant(false),
                    isFiberActive: .constant(false)
                )
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(
                    "This will permanently delete all your logged entries, saved foods, and personal data. This action cannot be undone."
                )
            }
        }
    }
}

#Preview {
    HomeView()
}
