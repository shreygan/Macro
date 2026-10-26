//
//  HydrationCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/18/26.
//

import SwiftData
import SwiftUI

struct HydrationSegment: Identifiable {
    let id: String
    let drinkKey: String
    let tint: Color
    let symbol: String
    let name: String
    var milliliters: Double
    var count: Int
    let start: Date

    static func timeline(from entries: [LoggedEntry]) -> [HydrationSegment] {
        var segments: [HydrationSegment] = []
        var runsByKey: [String: Int] = [:]
        var lastKey: String?
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) where entry.hydrationML > 0 {
            let key = entry.originalFoodItem?.id.uuidString ?? entry.name
            if key == lastKey, var last = segments.popLast() {
                last.milliliters += entry.hydrationML
                last.count += 1
                segments.append(last)
            } else {
                let drink = drinkFood(for: entry)
                let run = runsByKey[key, default: 0]
                runsByKey[key] = run + 1
                segments.append(
                    HydrationSegment(
                        id: "\(key)#\(run)",
                        drinkKey: key,
                        tint: (drink?.drinkTint ?? DrinkFormState.defaultTint).color,
                        symbol: drink?.drinkSymbol ?? DrinkFormState.defaultSymbol,
                        name: entry.name,
                        milliliters: entry.hydrationML,
                        count: 1,
                        start: entry.timestamp
                    )
                )
            }
            lastKey = key
        }
        return segments
    }

    static func totals(from entries: [LoggedEntry]) -> [HydrationSegment] {
        var totals: [HydrationSegment] = []
        var indexByKey: [String: Int] = [:]
        for segment in timeline(from: entries) {
            if let index = indexByKey[segment.drinkKey] {
                totals[index].milliliters += segment.milliliters
                totals[index].count += segment.count
            } else {
                indexByKey[segment.drinkKey] = totals.count
                totals.append(segment)
            }
        }
        return totals
    }

    static func drinkFood(for entry: LoggedEntry) -> FoodItem? {
        if let food = entry.originalFoodItem, food.type == .drink {
            return food
        }
        let drink = (entry.childEntries ?? [])
            .filter { $0.hydrationML > 0 }
            .max { $0.hydrationML < $1.hydrationML }
        return drink?.originalFoodItem.flatMap { $0.type == .drink ? $0 : nil }
    }
}

struct HydrationFactsLine: View {
    let entries: [LoggedEntry]
    var tallyUnit: VolumeUnit? = nil

    private var tally: [HydrationSegment] {
        tallyUnit == nil ? [] : HydrationSegment.totals(from: entries)
    }

    private var text: String? {
        var parts: [String] = []
        let caffeine = entries.reduce(0) { $0 + $1.caffeineMg }
        if caffeine > 0 {
            parts.append(String(localized: "\(caffeine.formatted(.number.precision(.fractionLength(0)))) mg caffeine"))
        }
        let alcohol = entries.reduce(0) { $0 + $1.alcoholGrams }
        if alcohol > 0 {
            parts.append(DrinkAmounts.standardDrinksText(DrinkAmounts.standardDrinks(alcoholGrams: alcohol)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        let tally = tally
        if let tallyUnit, !tally.isEmpty {
            tallyLines(tally, unit: tallyUnit)
                .font(.subtitle)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenTally(tally, unit: tallyUnit))
                .transition(.opacity)
        } else if let text {
            Text(text)
                .font(.subtitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .transition(.opacity)
        }
    }

    private func tallyLines(_ tally: [HydrationSegment], unit: VolumeUnit) -> some View {
        ViewThatFits(in: .horizontal) {
            if let text {
                Text("\(tallyText(tally, hidden: 0, unit: unit)) · \(text)")
                    .lineLimit(1)
                    .fixedSize()
            }

            ForEach(Array(stride(from: tally.count, through: 1, by: -1)), id: \.self) { shown in
                VStack(alignment: .leading, spacing: 4) {
                    tallyText(largest(shown, of: tally), hidden: tally.count - shown, unit: unit)
                        .lineLimit(1)
                        .fixedSize(horizontal: shown > 1, vertical: false)

                    if let text {
                        Text(text)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func largest(_ count: Int, of tally: [HydrationSegment]) -> [HydrationSegment] {
        let kept = Set(tally.sorted { $0.milliliters > $1.milliliters }.prefix(count).map(\.id))
        return tally.filter { kept.contains($0.id) }
    }

    private func tallyText(_ items: [HydrationSegment], hidden: Int, unit: VolumeUnit) -> Text {
        var result: Text?
        for item in items {
            let symbol = Text(Image(symbol: item.symbol)).foregroundStyle(item.tint)
            let drink = Text("\(symbol)\u{202F}\(unit.formattedCompactAmount(item.milliliters))")
            result = result.map { Text("\($0) · \(drink)") } ?? drink
        }
        let tally = result ?? Text("")
        return hidden > 0 ? Text("\(tally) · +\(hidden) more") : tally
    }

    private func spokenTally(_ tally: [HydrationSegment], unit: VolumeUnit) -> String {
        let drinks = tally.map { "\($0.name) \(unit.formattedCompactAmount($0.milliliters))" }
        return ([drinks.formatted(.list(type: .and))] + [text].compactMap { $0 })
            .joined(separator: ", ")
    }
}

struct HydrationCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    @Query private var entries: [LoggedEntry]
    @Query(filter: #Predicate<FoodItem> { $0.hydrationOrder != nil }) private var pinnedDrinks:
        [FoodItem]

    let date: Date
    let dayStartMinutes: Int
    let logicalToday: Date
    let goalML: Double?
    let unit: VolumeUnit
    var onLogDrink: (FoodItem?) -> Void
    var onViewHydration: () -> Void
    var onManageDrinks: () -> Void
    var onEditGoal: (() -> Void)?
    var promptsForGoal: Bool
    var hasWaterGoal: Bool
    var onHide: (() -> Void)?

    init(
        date: Date,
        dayStartMinutes: Int,
        logicalToday: Date,
        goalML: Double?,
        unit: VolumeUnit,
        onLogDrink: @escaping (FoodItem?) -> Void,
        onViewHydration: @escaping () -> Void,
        onManageDrinks: @escaping () -> Void,
        onEditGoal: (() -> Void)? = nil,
        promptsForGoal: Bool = false,
        hasWaterGoal: Bool = true,
        onHide: (() -> Void)? = nil
    ) {
        self.date = date
        self.dayStartMinutes = dayStartMinutes
        self.logicalToday = logicalToday
        self.goalML = goalML
        self.unit = unit
        self.onLogDrink = onLogDrink
        self.onViewHydration = onViewHydration
        self.onManageDrinks = onManageDrinks
        self.onEditGoal = onEditGoal
        self.promptsForGoal = promptsForGoal
        self.hasWaterGoal = hasWaterGoal
        self.onHide = onHide

        let dayRange = Calendar.current.logicalDayRange(for: date, dayStartMinutes: dayStartMinutes)
        let start = dayRange.lowerBound
        let end = dayRange.upperBound
        let drinkType = EntryType.drink.rawValue
        _entries = Query(
            filter: #Predicate<LoggedEntry> { entry in
                entry.timestamp >= start && entry.timestamp < end
                    && entry.parentEntry == nil
                    && (entry.isHydrationLog || entry.typeRawValue == drinkType || entry.volumeML > 0)
            },
            sort: \.timestamp
        )
    }

    private var totalML: Double {
        entries.reduce(0) { $0 + $1.hydrationML }
    }

    private var showsGoalPrompt: Bool {
        promptsForGoal && (goalML ?? 0) <= 0
    }

    private var chipDrinks: [FoodItem] {
        pinnedDrinks
            .filter(\.isLoggableDrink)
            .sorted { ($0.hydrationOrder ?? 0) < ($1.hydrationOrder ?? 0) }
    }

    private func log(_ chip: HydrationChip) {
        let timestamp = HydrationLogger.timestamp(forDay: date, dayStartMinutes: dayStartMinutes)
        let goalFeedback = WaterGoalFeedback(at: timestamp, in: modelContext)
        do {
            let entry = try withAnimation {
                try HydrationLogger.log(
                    chip.food,
                    volumeML: chip.volumeML,
                    sizeName: chip.sizeName,
                    at: timestamp,
                    in: modelContext
                )
            }
            goalFeedback.playIfReached()
            if let toastCenter {
                toastCenter.show(
                    .hydrationLogged(
                        entry,
                        title: HydrationLogger.loggedTitle(forDay: date, logicalToday: logicalToday),
                        unit: unit,
                        in: modelContext,
                        presenter: toastCenter
                    )
                )
            }
        } catch {
            toastCenter?.show(.failure(String(localized: "Couldn't Log Drink"), message: chip.food.name))
        }
    }

    var body: some View {
        Card("Hydration") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: (goalML ?? 0) > 0 ? 10 : 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(unit.formattedTotalValue(totalML))
                            .font(.pageTitle)
                            .contentTransition(.numericText(value: totalML))

                        Text(unit.totalUnitLabel)
                            .font(.rowValue)
                            .foregroundStyle(.secondary)

                        if let goalML, goalML > 0 {
                            Text("/ \(unit.formattedTotal(goalML))")
                                .font(.rowValue)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)

                            WaterGoalStar(isReached: totalML >= goalML)
                        }

                        if showsGoalPrompt, let onEditGoal {
                            Button(action: onEditGoal) {
                                Text("· Set Goal")
                                    .font(.rowValue)
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }

                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(unit.spokenProgress(totalML, goal: goalML))

                    VStack(alignment: .leading, spacing: 8) {
                        if let goalML, goalML > 0 {
                            HydrationBar(
                                segments: HydrationSegment.timeline(from: entries),
                                goalML: goalML,
                                scrubUnit: unit
                            )
                            .transition(.leadingReveal)
                        }

                        HydrationFactsLine(
                            entries: entries,
                            tallyUnit: (goalML ?? 0) > 0 ? nil : unit
                        )
                    }
                }
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture(perform: onViewHydration)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens Hydration")
                .accessibilityAction(.default, onViewHydration)
                .accessibilityActions {
                    if showsGoalPrompt, let onEditGoal {
                        Button("Set Goal", action: onEditGoal)
                    }
                }

                HStack(spacing: 4) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(chipDrinks) { drink in
                                DrinkChipMenu(drink: drink, unit: unit, onLog: log) {
                                    onLogDrink(drink)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .chipScrollFade()

                    Button {
                        onLogDrink(nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.filterChipIcon)
                    .accessibilityLabel("Log Drink")
                    .padding(.trailing, 16)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 16)
            .animation(.snappy, value: totalML)
            .animation(.snappy, value: goalML)
            .animation(.snappy, value: showsGoalPrompt)
        } headerAccessory: {
            Menu {
                Button("View Hydration", systemImage: "drop", action: onViewHydration)
                Button(hasWaterGoal ? "Edit Goal" : "Set Goal", systemImage: "target") {
                    onEditGoal?()
                }
                .disabled(onEditGoal == nil)
                Button("Manage Drinks", systemImage: "slider.horizontal.3", action: onManageDrinks)
                if let onHide {
                    Button("Hide Hydration", systemImage: "eye.slash", action: onHide)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.menuIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.controlFill))
            }
            .buttonStyle(.plain)
            .padding(.vertical, -2)
            .padding(.trailing, -6)
            .accessibilityLabel("Hydration Options")
        }
    }
}

private struct DrinkChipMenu: View {
    @Query private var recentLogs: [LoggedEntry]

    let drink: FoodItem
    let unit: VolumeUnit
    var onLog: (HydrationChip) -> Void
    var onCustomAmount: () -> Void

    init(
        drink: FoodItem,
        unit: VolumeUnit,
        onLog: @escaping (HydrationChip) -> Void,
        onCustomAmount: @escaping () -> Void
    ) {
        self.drink = drink
        self.unit = unit
        self.onLog = onLog
        self.onCustomAmount = onCustomAmount
        _recentLogs = Query(HydrationLogger.recentLogsDescriptor(for: drink))
    }

    var body: some View {
        Menu {
            ForEach(HydrationLogger.menuSizes(for: drink)) { size in
                Button {
                    onLog(size)
                } label: {
                    Text(unit.formattedAmount(size.volumeML))
                    if let name = size.sizeName, !name.isEmpty {
                        Text(name)
                    }
                }
            }

            let recent = HydrationLogger.recentAmounts(
                for: drink,
                volumes: recentLogs.map(\.volumeML),
                limit: HydrationLogger.menuRecentAmountLimit
            )
            ForEach(recent, id: \.self) { volume in
                Button {
                    onLog(HydrationChip(food: drink, volumeML: volume, sizeName: nil))
                } label: {
                    Text(unit.formattedAmount(volume))
                    Text("Recent")
                }
            }

            Divider()

            Button("Custom Amount…", action: onCustomAmount)
        } label: {
            Label {
                Text(drink.name)
            } icon: {
                Image(symbol: drink.drinkSymbol)
                    .foregroundStyle(drink.drinkTint.color)
            }
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.filterChip(isSelected: false))
        .accessibilityLabel("Log \(drink.name)")
    }
}

struct WaterGoalStar: View {
    let isReached: Bool

    @State private var showsStar: Bool

    init(isReached: Bool) {
        self.isReached = isReached
        _showsStar = State(initialValue: isReached)
    }

    var body: some View {
        ZStack {
            if showsStar {
                Text(Image(systemName: "star.fill"))
                    .font(.rowValue)
                    .foregroundStyle(DrinkTint.blue.color)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
        .onChange(of: isReached) { _, newValue in
            withAnimation(.snappy) {
                showsStar = newValue
            }
        }
    }
}

struct HydrationBar: View {
    let segments: [HydrationSegment]
    let goalML: Double
    var scrubUnit: VolumeUnit? = nil

    @State private var isScrubbing = false
    @State private var scrubX: CGFloat?
    @State private var calloutSize: CGSize = .zero

    private static let height: CGFloat = 8
    private static let scrubHeight: CGFloat = 20
    private static let gap: CGFloat = 2
    private static let minSegmentWidth: CGFloat = 2

    private enum ScrubTarget: Equatable {
        case segment(String)
        case remaining
    }

    private var totalML: Double {
        segments.reduce(0) { $0 + $1.milliliters }
    }

    private var scaleML: Double {
        max(goalML, totalML)
    }

    private func spacing(in barWidth: CGFloat) -> CGFloat {
        let count = CGFloat(segments.count)
        return count * (Self.gap + Self.minSegmentWidth) <= barWidth ? Self.gap : 0
    }

    private func widths(in barWidth: CGFloat) -> [CGFloat] {
        guard scaleML > 0, !segments.isEmpty else { return segments.map { _ in 0 } }
        let fillWidth = max(barWidth - spacing(in: barWidth) * CGFloat(segments.count - 1), 0)
        let raw = segments.map { fillWidth * CGFloat($0.milliliters / scaleML) }
        let minimum = min(Self.minSegmentWidth, fillWidth / CGFloat(segments.count))
        let widths = raw.map { max($0, minimum) }
        let overflow = widths.reduce(0, +) - fillWidth
        guard overflow > 0 else { return widths }
        let shrinkable = widths.reduce(0) { $0 + ($1 - minimum) }
        guard shrinkable > 0 else { return widths }
        let factor = min(overflow / shrinkable, 1)
        return widths.map { $0 - ($0 - minimum) * factor }
    }

    private func goalX(in barWidth: CGFloat) -> CGFloat {
        let spacing = spacing(in: barWidth)
        var start: CGFloat = 0
        var remainingML = goalML
        for (segment, width) in zip(segments, widths(in: barWidth)) {
            if remainingML <= segment.milliliters {
                let fraction = segment.milliliters > 0 ? remainingML / segment.milliliters : 0
                return start + width * fraction
            }
            remainingML -= segment.milliliters
            start += width + spacing
        }
        return barWidth
    }

    private func target(at x: CGFloat, in barWidth: CGFloat) -> ScrubTarget? {
        let spacing = spacing(in: barWidth)
        var end: CGFloat = 0
        for (segment, width) in zip(segments, widths(in: barWidth)) {
            end += width
            if x <= end + spacing / 2 {
                return .segment(segment.id)
            }
            end += spacing
        }
        return goalML > totalML ? .remaining : segments.last.map { .segment($0.id) }
    }

    private func updateScrub(_ x: CGFloat?) {
        guard scrubUnit != nil else { return }
        isScrubbing = x != nil
        scrubX = x
    }

    var body: some View {
        GeometryReader { proxy in
            let barWidth = proxy.size.width
            let current = scrubX.flatMap { target(at: $0, in: barWidth) }

            HStack(spacing: spacing(in: barWidth)) {
                ForEach(Array(zip(segments, widths(in: barWidth))), id: \.0.id) { segment, width in
                    Rectangle()
                        .fill(segment.tint)
                        .frame(width: width)
                        .transition(
                            .modifier(
                                active: SegmentGrowth(width: width, progress: 0),
                                identity: SegmentGrowth(width: width, progress: 1)
                            )
                        )
                }
            }
            .frame(width: barWidth, height: isScrubbing ? Self.scrubHeight : Self.height, alignment: .leading)
            .background(Color.trackFill)
            .clipShape(Capsule())
            .frame(height: proxy.size.height)
            .overlay {
                if totalML > goalML {
                    GoalMarker(mode: .floor)
                        .position(
                            x: goalX(in: barWidth),
                            y: proxy.size.height / 2 + GoalMarker.verticalOffset
                        )
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                if let scrubX, let current, let scrubUnit {
                    callout(for: current, unit: scrubUnit)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { calloutSize = $0 }
                        .offset(
                            x: min(max(scrubX - calloutSize.width / 2, 0), max(barWidth - calloutSize.width, 0)),
                            y: -calloutSize.height - Self.scrubHeight / 2 - 4
                        )
                        .transition(.opacity)
                }
            }
            .sensoryFeedback(.selection, trigger: current) { _, new in new != nil }
        }
        .frame(height: Self.height)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .gesture(HoldToScrubGesture(onChange: updateScrub))
        .padding(.vertical, -12)
        .animation(.snappy, value: isScrubbing)
        .sensoryFeedback(.impact(weight: .light), trigger: isScrubbing) { _, new in new }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func callout(for target: ScrubTarget, unit: VolumeUnit) -> some View {
        Group {
            switch target {
            case .segment(let id):
                if let segment = segments.first(where: { $0.id == id }) {
                    let detail = segment.count > 1
                        ? String(localized: "\(segment.count) drinks")
                        : segment.start.formatted(date: .omitted, time: .shortened)
                    HStack(spacing: 6) {
                        Image(symbol: segment.symbol)
                            .foregroundStyle(segment.tint)
                        Text(segment.name)
                            .foregroundStyle(.primary)
                        Text("\(unit.formattedCompactAmount(segment.milliliters)) · \(detail)")
                            .foregroundStyle(.secondary)
                    }
                }
            case .remaining:
                Text("\(unit.formattedTotal(goalML - totalML)) to go")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.compactTitle)
        .lineLimit(1)
        .fixedSize()
        .frame(height: FontSize.compactLineHeight)
        .contentTransition(.interpolate)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy(duration: 0.25), value: target)
    }
}

private struct HoldToScrubGesture: UIGestureRecognizerRepresentable {
    var onChange: (CGFloat?) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.25
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChange(context.converter.localLocation.x)
        default:
            onChange(nil)
        }
    }
}

private struct LeadingReveal: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                Rectangle()
                    .scaleEffect(x: min(max(progress, 0), 1), y: 1, anchor: .leading)
                    .padding(.vertical, -80)
            }
    }
}

extension AnyTransition {
    static var leadingReveal: AnyTransition {
        .modifier(active: LeadingReveal(progress: 0), identity: LeadingReveal(progress: 1))
    }
}

private struct SegmentGrowth: ViewModifier, Animatable {
    let width: CGFloat
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let fraction = min(max(progress, 0), 1)
        content
            .mask(alignment: .leading) {
                Rectangle()
                    .scaleEffect(x: fraction, y: 1, anchor: .leading)
            }
            .frame(width: width * fraction, alignment: .leading)
            .clipped()
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
        _ = try? HydrationLogger.log(water, volumeML: 250, sizeName: "Glass", at: .now, in: context)
    }

    return ZStack {
        Color.background.ignoresSafeArea()
        HydrationCard(
            date: .now,
            dayStartMinutes: 0,
            logicalToday: Calendar.current.startOfDay(for: .now),
            goalML: 2500,
            unit: .milliliters,
            onLogDrink: { _ in },
            onViewHydration: {},
            onManageDrinks: {}
        )
        .padding()
    }
    .modelContainer(container)
}

#Preview("Over Goal") {
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
        _ = try? HydrationLogger.log(water, volumeML: 1000, sizeName: nil, at: .now, in: context)
        _ = try? HydrationLogger.log(coffee, volumeML: 350, sizeName: "Mug", at: .now, in: context)
        _ = try? HydrationLogger.log(water, volumeML: 1500, sizeName: nil, at: .now, in: context)
    }

    return ZStack {
        Color.background.ignoresSafeArea()
        HydrationCard(
            date: .now,
            dayStartMinutes: 0,
            logicalToday: Calendar.current.startOfDay(for: .now),
            goalML: 2500,
            unit: .milliliters,
            onLogDrink: { _ in },
            onViewHydration: {},
            onManageDrinks: {}
        )
        .padding()
    }
    .modelContainer(container)
}

#Preview("No Goal") {
    let container = try! ModelContainer(
        for: User.self, FoodItem.self, LoggedEntry.self, ServingSizeUnit.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = container.mainContext
    container.mainContext.insert(User(onboardingComplete: true))
    AppSeeder.resetListSeeding()
    try? AppSeeder.seedDefaults(into: context)
    for seed in AppSeeder.starterDrinks {
        _ = try? AppSeeder.storedDrink(for: seed, in: context)
    }
    let drinks = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
    if let water = drinks.first(where: { $0.seedKey == "water" }),
        let coffee = drinks.first(where: { $0.seedKey == "coffee" })
    {
        _ = try? HydrationLogger.log(coffee, volumeML: 350, sizeName: "Mug", at: .now, in: context)
        _ = try? HydrationLogger.log(water, volumeML: 500, sizeName: "Bottle", at: .now, in: context)
        _ = try? HydrationLogger.log(water, volumeML: 250, sizeName: "Glass", at: .now, in: context)
        for key in ["latte", "orangeJuice", "beer", "tea"] {
            if let drink = drinks.first(where: { $0.seedKey == key }) {
                _ = try? HydrationLogger.log(drink, volumeML: drink.servingVolumeML ?? 250, sizeName: nil, at: .now, in: context)
            }
        }
    }

    return ZStack {
        Color.background.ignoresSafeArea()
        HydrationCard(
            date: .now,
            dayStartMinutes: 0,
            logicalToday: Calendar.current.startOfDay(for: .now),
            goalML: nil,
            unit: .milliliters,
            onLogDrink: { _ in },
            onViewHydration: {},
            onManageDrinks: {}
        )
        .padding()
    }
    .modelContainer(container)
}
