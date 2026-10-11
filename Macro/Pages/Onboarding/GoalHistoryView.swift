//
//  GoalHistoryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftData
import SwiftUI

struct GoalHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    let user: User
    var onSelect: ((UserGoals) -> Void)?
    var isActive: ((UserGoals) -> Bool)?

    @State private var editingGoals: UserGoals?
    @State private var dateEdit: GoalDateEdit?
    @State private var isAddingGoals = false
    @State private var deletingPeriod: GoalPeriod?

    init(
        user: User,
        onSelect: ((UserGoals) -> Void)? = nil,
        isActive: ((UserGoals) -> Bool)? = nil
    ) {
        self.user = user
        self.onSelect = onSelect
        self.isActive = isActive
    }

    private var isEditable: Bool {
        onSelect == nil
    }

    private var logicalToday: Date {
        Calendar.current.logicalDay(for: .now, dayStartMinutes: user.dayStartMinutes)
    }

    private func isAlreadyActive(_ goals: UserGoals) -> Bool {
        if let isActive {
            return isActive(goals)
        }
        return user.currentGoals?.hasSameTargets(as: goals) ?? false
    }

    var body: some View {
        let timeline = user.goalTimeline
        let periods = Array(timeline.periods.reversed())
        let today = logicalToday

        ZStack {
            Color.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    if periods.isEmpty {
                        emptyState
                    } else {
                        VStack {
                            ForEach(periods) { period in
                                let isActive = isAlreadyActive(period.goals)

                                Card {
                                    GoalHistoryRow(
                                        goals: period.goals,
                                        title: period.title,
                                        isCurrent: period.isCurrent
                                    )
                                } menuItems: {
                                    Button {
                                        select(
                                            period.goals,
                                            proxy: proxy,
                                            topID: periods.first?.id
                                        )
                                    } label: {
                                        Label(
                                            isActive
                                                ? "Already Active"
                                                : "Set as Active",
                                            systemImage: "checkmark.circle"
                                        )
                                    }
                                    .disabled(isActive)

                                    if isEditable {
                                        Button {
                                            editingGoals = period.goals
                                        } label: {
                                            Label("Edit Goals", systemImage: "pencil")
                                        }

                                        if !period.isFirst {
                                            Button {
                                                guard let bounds = timeline.startDayBounds(
                                                    for: period,
                                                    today: today
                                                ) else { return }
                                                dateEdit = GoalDateEdit(
                                                    period: period,
                                                    kind: .start,
                                                    initialDay: period.startDay,
                                                    lower: bounds.lower,
                                                    upper: bounds.upper
                                                )
                                            } label: {
                                                Label(
                                                    "Change Start Date",
                                                    systemImage: "calendar"
                                                )
                                            }
                                            .disabled(
                                                timeline.startDayBounds(
                                                    for: period,
                                                    today: today
                                                ) == nil
                                            )
                                        }

                                        if !period.isCurrent {
                                            Button {
                                                guard let endDay = period.endDay,
                                                    let next = timeline.next(after: period),
                                                    let bounds = timeline.endDayBounds(
                                                        for: period,
                                                        today: today
                                                    )
                                                else { return }
                                                dateEdit = GoalDateEdit(
                                                    period: period,
                                                    kind: .end(next: next),
                                                    initialDay: endDay,
                                                    lower: bounds.lower,
                                                    upper: bounds.upper
                                                )
                                            } label: {
                                                Label(
                                                    "Change End Date",
                                                    systemImage: "calendar.badge.clock"
                                                )
                                            }
                                            .disabled(
                                                timeline.endDayBounds(
                                                    for: period,
                                                    today: today
                                                ) == nil
                                            )
                                        }

                                        if periods.count > 1 {
                                            Divider()

                                            Button(role: .destructive) {
                                                deletingPeriod = period
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.bottom)
                                .id(period.id)
                                .transition(
                                    .scale(scale: 0.9, anchor: .top)
                                        .combined(with: .opacity)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Goal History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSelect != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            } else if !periods.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingGoals = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Goals for Dates")
                }
            }
        }
        .navigationDestination(isPresented: $isAddingGoals) {
            GoalSetupView(
                isCalorieActive: .constant(false),
                isProteinActive: .constant(false),
                isCarbsActive: .constant(false),
                isFatActive: .constant(false),
                isFiberActive: .constant(false),
                isAddingPeriod: true
            )
        }
        .navigationDestination(item: $editingGoals) { goals in
            GoalSetupView(
                isCalorieActive: .constant(false),
                isProteinActive: .constant(false),
                isCarbsActive: .constant(false),
                isFatActive: .constant(false),
                isFiberActive: .constant(false),
                editingGoals: goals
            )
        }
        .sheet(item: $dateEdit) { edit in
            GoalDateSheet(
                title: edit.title,
                initialDay: edit.initialDay,
                lower: edit.lower,
                upper: edit.upper
            ) { day in
                switch edit.kind {
                case .start:
                    move(edit.period, to: day)
                case .end(let next):
                    changeEnd(of: edit.period, next: next, to: day)
                }
            }
        }
        .alert(
            "Delete Goals?",
            isPresented: Binding(
                get: { deletingPeriod != nil },
                set: { if !$0 { deletingPeriod = nil } }
            ),
            presenting: deletingPeriod
        ) { period in
            Button("Delete", role: .destructive) {
                delete(period)
            }
            Button("Cancel", role: .cancel) {}
        } message: { period in
            Text(
                period.isFirst
                    ? "Days in this period will use the next goals instead."
                    : "Days in this period will use the previous goals instead."
            )
        }
    }

    private func select(_ goals: UserGoals, proxy: ScrollViewProxy, topID: UUID?) {
        guard !isAlreadyActive(goals) else { return }

        if let onSelect {
            onSelect(goals)
            dismiss()
            return
        }

        let targets = goals.targets

        Task {
            try? await Task.sleep(for: .milliseconds(350))

            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(topID, anchor: .top)
            } completion: {
                withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                    perform(
                        String(localized: "Goals Activated"),
                        symbol: "checkmark",
                        failure: String(localized: "Couldn't Activate Goals")
                    ) {
                        try GoalHistoryStore.setCurrent(targets, for: user, in: modelContext)
                    }
                }
            }
        }
    }

    private func move(_ period: GoalPeriod, to day: Date) {
        let goals = period.goals
        withAnimation {
            perform(
                String(localized: "Start Date Changed"),
                symbol: "calendar",
                message: { periodTitle(for: goals) },
                failure: String(localized: "Couldn't Change Start Date")
            ) {
                try GoalHistoryStore.move(goals, toStartDay: day, for: user, in: modelContext)
            }
        }
    }

    private func changeEnd(of period: GoalPeriod, next: GoalPeriod, to day: Date) {
        let goals = period.goals
        guard let nextStart = Calendar.current.date(byAdding: .day, value: 1, to: day)
        else { return }
        withAnimation {
            perform(
                String(localized: "End Date Changed"),
                symbol: "calendar",
                message: { periodTitle(for: goals) },
                failure: String(localized: "Couldn't Change End Date")
            ) {
                try GoalHistoryStore.move(
                    next.goals,
                    toStartDay: nextStart,
                    for: user,
                    in: modelContext
                )
            }
        }
    }

    private func delete(_ period: GoalPeriod) {
        let title = period.title
        withAnimation {
            perform(
                String(localized: "Goals Deleted"),
                symbol: "trash",
                kind: .info,
                tint: .red,
                message: { title },
                failure: String(localized: "Couldn't Delete Goals")
            ) {
                try GoalHistoryStore.delete(period.goals, for: user, in: modelContext)
            }
        }
    }

    private func periodTitle(for goals: UserGoals) -> String? {
        user.goalTimeline.periods.first { $0.id == goals.id }?.title
    }

    private func perform(
        _ title: String,
        symbol: String,
        kind: Toast.Kind = .success,
        tint: Color = .accentColor,
        message: () -> String? = { nil },
        failure: String,
        _ change: () throws -> GoalHistoryStore.Snapshot
    ) {
        do {
            let snapshot = try change()
            toastCenter?.show(
                .goalsChanged(
                    title,
                    kind: kind,
                    symbol: symbol,
                    tint: tint,
                    message: message(),
                    undo: snapshot,
                    for: user,
                    in: modelContext,
                    presenter: toastCenter
                )
            )
        } catch {
            toastCenter?.show(.failure(failure))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(Color.tertiaryText)

            Text("No Goal History Yet")
                .font(.statusLabel)
                .foregroundStyle(.secondary)

            Text("Past goals will appear here after you make a change.")
                .font(.subtitle)
                .foregroundStyle(Color.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }
}

private struct GoalDateEdit: Identifiable {
    enum Kind {
        case start
        case end(next: GoalPeriod)
    }

    let period: GoalPeriod
    let kind: Kind
    let initialDay: Date
    let lower: Date?
    let upper: Date

    var id: UUID { period.id }

    var title: String {
        switch kind {
        case .start: String(localized: "Start Date")
        case .end: String(localized: "End Date")
        }
    }
}

private struct GoalDateSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialDay: Date
    let lower: Date?
    let upper: Date
    let onSave: (Date) -> Void

    @State private var selection: Date
    @State private var contentHeight: CGFloat?
    @State private var chromeHeight: CGFloat = 0

    init(
        title: String,
        initialDay: Date,
        lower: Date?,
        upper: Date,
        onSave: @escaping (Date) -> Void
    ) {
        self.title = title
        self.initialDay = initialDay
        self.lower = lower
        self.upper = upper
        self.onSave = onSave
        _selection = State(initialValue: initialDay)
    }

    @ViewBuilder
    private var picker: some View {
        if let lower {
            DatePicker(
                title,
                selection: $selection,
                in: lower...upper,
                displayedComponents: .date
            )
        } else {
            DatePicker(
                title,
                selection: $selection,
                in: ...upper,
                displayedComponents: .date
            )
        }
    }

    private var isUnchanged: Bool {
        Calendar.current.isDate(selection, inSameDayAs: initialDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    Card {
                        picker
                            .datePickerStyle(.graphical)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        contentHeight = height
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .bottom)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.top
                } action: { insets in
                    chromeHeight = insets
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(Calendar.current.startOfDay(for: selection))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.primary)
                    }
                    .disabled(isUnchanged)
                    .tint(Color.accentColor)
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationDetents(
            contentHeight.map { [.height($0 + chromeHeight)] } ?? [.medium]
        )
    }
}

#Preview {
    let container: ModelContainer
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: User.self,
            UserGoals.self,
            configurations: config
        )
    } catch {
        fatalError(
            "Failed to create preview container: \(error.localizedDescription)"
        )
    }

    let context = container.mainContext
    let user = User(onboardingComplete: true)
    context.insert(user)

    let olderGoals = UserGoals(
        date: .now.addingTimeInterval(-86400 * 30),
        calories: 2200,
        calorieMode: .ceiling,
        protein: 150,
        proteinMode: .floor,
        carbs: 180,
        carbsMode: .floor,
        fat: 120,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off,
        owner: user
    )
    context.insert(olderGoals)

    let currentGoals = UserGoals(
        calories: 2500,
        calorieMode: .ceiling,
        protein: 180,
        proteinMode: .floor,
        carbs: 200,
        carbsMode: .floor,
        fat: 150,
        fatMode: .ceiling,
        fiber: 25,
        fiberMode: .off,
        owner: user
    )
    context.insert(currentGoals)

    return NavigationStack {
        GoalHistoryView(user: user)
    }
    .modelContainer(container)
}
