//
//  DayPager.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/24/26.
//

import SwiftUI

@Observable
final class DayPagerState {
    fileprivate(set) var selectedDate: Date
    fileprivate(set) var displayDate: Date
    var currentWeekStart: Date
    fileprivate(set) var swapTargetDate: Date?
    fileprivate(set) var swapSubstituteDate: Date?
    private(set) var lastDay: Date?

    private var dayAnchor: Date
    private var weekAnchor: Date

    @ObservationIgnored private var swapToken = 0
    @ObservationIgnored private var dateCache: (key: BufferKey, dates: [Date])?
    @ObservationIgnored private var weekCache: (key: BufferKey, dates: [Date])?

    private struct BufferKey: Equatable {
        let anchor: Date
        let lastDay: Date?
    }

    init(day: Date, lastDay: Date? = nil) {
        let calendar = Calendar.current
        let lastDay = lastDay.map { calendar.startOfDay(for: $0) }
        let day = min(calendar.startOfDay(for: day), lastDay ?? .distantFuture)
        self.lastDay = lastDay
        selectedDate = day
        displayDate = day
        currentWeekStart = Self.weekStart(of: day)
        dayAnchor = day
        weekAnchor = Self.weekStart(of: day)
    }

    var bufferDates: [Date] {
        let key = BufferKey(anchor: dayAnchor, lastDay: lastDay)
        if let dateCache, dateCache.key == key { return dateCache.dates }
        let calendar = Calendar.current
        let upper = lastDay.map {
            max(0, min(500, calendar.dateComponents([.day], from: key.anchor, to: $0).day ?? 0))
        } ?? 500
        let dates = (-500...upper).compactMap { calendar.date(byAdding: .day, value: $0, to: key.anchor) }
        dateCache = (key, dates)
        return dates
    }

    var bufferWeeks: [Date] {
        let key = BufferKey(anchor: weekAnchor, lastDay: lastDay)
        if let weekCache, weekCache.key == key { return weekCache.dates }
        let calendar = Calendar.current
        let upper = lastDay.map {
            max(0, min(50, calendar.dateComponents([.weekOfYear], from: key.anchor, to: Self.weekStart(of: $0)).weekOfYear ?? 0))
        } ?? 50
        let weeks = (-50...upper).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: key.anchor) }
        weekCache = (key, weeks)
        return weeks
    }

    static func weekStart(of day: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
        ) ?? calendar.startOfDay(for: day)
    }

    static func days(of weekStart: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    func setLastDay(_ day: Date) {
        let day = Calendar.current.startOfDay(for: day)
        guard lastDay != nil, lastDay != day else { return }
        lastDay = day
    }

    fileprivate func shiftBufferIfNeeded(for date: Date) {
        guard let index = bufferDates.firstIndex(of: date) else { return }
        let threshold = 50
        if index < threshold || (lastDay == nil && index > bufferDates.count - threshold) {
            dayAnchor = date
        }
    }

    fileprivate func shiftBufferWeeksIfNeeded(for week: Date) {
        guard let index = bufferWeeks.firstIndex(of: week) else { return }
        let threshold = 10
        if index < threshold || (lastDay == nil && index > bufferWeeks.count - threshold) {
            weekAnchor = week
        }
    }

    private func ensureBuffered(_ date: Date) {
        if !bufferDates.contains(date) {
            dayAnchor = date
        }
        let week = Self.weekStart(of: date)
        if !bufferWeeks.contains(week) {
            weekAnchor = week
        }
    }

    func jump(to day: Date) {
        let day = min(Calendar.current.startOfDay(for: day), lastDay ?? .distantFuture)
        guard selectedDate != day else { return }
        ensureBuffered(day)
        currentWeekStart = Self.weekStart(of: day)
        selectedDate = day
        displayDate = day
    }

    func navigate(to day: Date) {
        let calendar = Calendar.current
        let newDate = min(calendar.startOfDay(for: day), lastDay ?? .distantFuture)

        guard selectedDate != newDate else { return }
        ensureBuffered(newDate)

        swapToken += 1
        let token = swapToken

        withAnimation {
            displayDate = newDate
        }

        let dayDifference = abs(
            calendar.dateComponents([.day], from: selectedDate, to: newDate).day ?? 0
        )

        if dayDifference <= 1 {
            withAnimation {
                selectedDate = newDate
            }
            if swapTargetDate != nil {
                endSwap(after: 0.35, token: token)
            }
        } else {
            let isTrailing = newDate > selectedDate
            guard
                let adjacentDate = calendar.date(
                    byAdding: .day,
                    value: isTrailing ? -1 : 1,
                    to: newDate
                )
            else { return }

            swapTargetDate = adjacentDate
            swapSubstituteDate = selectedDate

            selectedDate = adjacentDate

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard self.swapToken == token else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.selectedDate = newDate
                }
                self.endSwap(after: 0.35, token: token)
            }
        }
    }

    private func endSwap(after delay: TimeInterval, token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.swapToken == token else { return }
            self.swapTargetDate = nil
            self.swapSubstituteDate = nil
            if self.displayDate != self.selectedDate {
                withAnimation {
                    self.displayDate = self.selectedDate
                }
            }
        }
    }
}

struct DayPager<Page: View, Week: View>: View {
    @Bindable var state: DayPagerState
    let stripHeight: CGFloat
    let bottomMargin: CGFloat
    let indicatorBottomMargin: CGFloat
    let page: (Date) -> Page
    let week: ([Date]) -> Week

    private static var coordinateSpace: String { "DayPager" }

    init(
        state: DayPagerState,
        stripHeight: CGFloat = 90,
        bottomMargin: CGFloat = 0,
        indicatorBottomMargin: CGFloat = 0,
        @ViewBuilder page: @escaping (Date) -> Page,
        @ViewBuilder week: @escaping ([Date]) -> Week
    ) {
        self.state = state
        self.stripHeight = stripHeight
        self.bottomMargin = bottomMargin
        self.indicatorBottomMargin = indicatorBottomMargin
        self.page = page
        self.week = week
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(state.bufferDates, id: \.self) { date in
                    let effectiveDate =
                        date == state.swapTargetDate
                        ? (state.swapSubstituteDate ?? date) : date

                    ScrollView {
                        page(effectiveDate)
                            .id(effectiveDate)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(
                                            of: geo.frame(in: .named(Self.coordinateSpace)).minX
                                        ) { _, newX in
                                            if abs(newX) < 1.0
                                                && state.selectedDate == date
                                                && state.displayDate != date
                                                && state.swapTargetDate == nil
                                            {
                                                withAnimation {
                                                    state.displayDate = date
                                                }
                                            }
                                        }
                                }
                            )
                    }
                    .contentMargins(.bottom, bottomMargin, for: .scrollContent)
                    .contentMargins(.bottom, indicatorBottomMargin, for: .scrollIndicators)
                    .scrollEdgeEffectStyle(.hard, for: .top)
                    .modifier(ScrolledTopEdgeEffect())
                    .safeAreaBar(edge: .top) {
                        Color.primary.opacity(0.001).frame(height: stripHeight + 7.5)
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
                get: { state.selectedDate },
                set: { newDate in
                    if let newDate {
                        state.selectedDate = newDate
                    }
                }
            )
        )
        .scrollIndicators(.hidden, axes: .horizontal)
        .scrollEdgeEffectHidden(true, for: .top)
        .coordinateSpace(name: Self.coordinateSpace)
        .overlay(alignment: .top) {
            TabView(selection: $state.currentWeekStart) {
                ForEach(state.bufferWeeks, id: \.self) { weekStart in
                    week(DayPagerState.days(of: weekStart))
                        .padding(.horizontal, 20)
                        .tag(weekStart)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: stripHeight)
        }
        .onChange(of: state.selectedDate) { _, newDate in
            let newWeekStart = DayPagerState.weekStart(of: newDate)
            if newWeekStart != state.currentWeekStart {
                withAnimation(.easeInOut(duration: 0.3)) {
                    state.currentWeekStart = newWeekStart
                }
            }

            state.shiftBufferIfNeeded(for: newDate)
        }
        .onChange(of: state.currentWeekStart) { oldWeek, newWeek in
            let calendar = Calendar.current

            if !calendar.isDate(state.selectedDate, equalTo: newWeek, toGranularity: .weekOfYear) {
                let daysToShift = calendar.dateComponents([.day], from: oldWeek, to: newWeek).day ?? 0
                if let syncedDate = calendar.date(byAdding: .day, value: daysToShift, to: state.selectedDate) {
                    withAnimation {
                        state.selectedDate = min(syncedDate, state.lastDay ?? .distantFuture)
                    }
                }
            }

            state.shiftBufferWeeksIfNeeded(for: newWeek)
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

