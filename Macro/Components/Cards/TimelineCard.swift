//
//  TimelineCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/28/26.
//

import SwiftData
import SwiftUI

private enum TimelineItem: Identifiable {
    case entry(LoggedEntry)
    case draft(EntryDraft)

    var id: UUID {
        switch self {
        case .entry(let entry): entry.id
        case .draft(let draft): draft.id
        }
    }

    var timestamp: Date {
        switch self {
        case .entry(let entry): entry.timestamp
        case .draft(let draft): draft.timestamp ?? draft.createdAt
        }
    }

    var entry: LoggedEntry? {
        if case .entry(let entry) = self { return entry }
        return nil
    }

    var draft: EntryDraft? {
        if case .draft(let draft) = self { return draft }
        return nil
    }

    var isDraft: Bool { draft != nil }

    var detail: Text? {
        let (category, location) = categoryAndLocation
        return Text.detailLine([category], location: location)
    }

    private var categoryAndLocation: (String?, String?) {
        switch self {
        case .entry(let entry):
            return (entry.category?.category, entry.locationName)
        case .draft(let draft):
            let category: String
            let location: EntryLocation?
            switch draft.kind {
            case .logFood:
                guard let state = draft.decodeState(LogEntryDraftState.self)
                else { return (nil, nil) }
                category = state.categorySelection
                location = state.location
            case .logRecipe:
                guard let state = draft.decodeState(LogRecipeDraftState.self)
                else { return (nil, nil) }
                category = state.categorySelection
                location = state.location
            default:
                return (nil, nil)
            }
            return (category == "None" ? nil : category, location?.name)
        }
    }
}

extension LoggedEntry {
    var showsOnTimeline: Bool {
        entryType != .drink || calories > 0 || protein > 0 || carbs > 0 || fat > 0 || fiber > 0
    }
}

struct TimelineCard<MenuContent: View>: View {
    @Query private var entries: [LoggedEntry]
    @Query private var drafts: [EntryDraft]
    @Binding var clickedEntry: LoggedEntry?
    @Binding var clickedDraft: EntryDraft?

    let menuItems: (LoggedEntry) -> MenuContent
    var onDeleteDraft: ((EntryDraft) -> Void)?
    var showsAllDrinks: Bool

    init(
        date: Date,
        dayStartMinutes: Int = 0,
        showsAllDrinks: Bool = false,
        clickedEntry: Binding<LoggedEntry?> = .constant(nil),
        clickedDraft: Binding<EntryDraft?> = .constant(nil),
        onDeleteDraft: ((EntryDraft) -> Void)? = nil,
        @ViewBuilder menuItems: @escaping (LoggedEntry) -> MenuContent
    ) {
        let dayRange = Calendar.current.logicalDayRange(
            for: date,
            dayStartMinutes: dayStartMinutes
        )
        let startOfDay = dayRange.lowerBound
        let endOfDay = dayRange.upperBound

        let predicate = #Predicate<LoggedEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
                && entry.parentEntry == nil
        }

        _entries = Query(filter: predicate, sort: \.timestamp)

        let logFood = DraftKind.logFood.rawValue
        let logRecipe = DraftKind.logRecipe.rawValue
        let distantPast = Date.distantPast
        let draftPredicate = #Predicate<EntryDraft> { draft in
            (draft.kindRawValue == logFood || draft.kindRawValue == logRecipe)
                && (draft.timestamp ?? distantPast) >= startOfDay
                && (draft.timestamp ?? distantPast) < endOfDay
        }

        _drafts = Query(filter: draftPredicate)

        self._clickedEntry = clickedEntry
        self._clickedDraft = clickedDraft
        self.onDeleteDraft = onDeleteDraft
        self.showsAllDrinks = showsAllDrinks
        self.menuItems = menuItems
    }

    var body: some View {
        Card("Timeline") {
            TimelineList(
                entries: showsAllDrinks ? entries : entries.filter(\.showsOnTimeline),
                drafts: drafts,
                emptyText: "No entries logged today.",
                onSelectEntry: { clickedEntry = $0 },
                onSelectDraft: { clickedDraft = $0 },
                onDeleteDraft: onDeleteDraft,
                menuItems: menuItems
            )
        }
    }
}

struct TimelineList<MenuContent: View>: View {
    @Query(sort: \ServingSizeUnit.displayOrder) private var servingUnits:
        [ServingSizeUnit]
    @Environment(\.volumeUnit) private var volumeUnit

    let entries: [LoggedEntry]
    var drafts: [EntryDraft] = []
    let emptyText: LocalizedStringKey
    var onSelectEntry: (LoggedEntry) -> Void
    var onSelectDraft: (EntryDraft) -> Void = { _ in }
    var onDeleteDraft: ((EntryDraft) -> Void)? = nil
    let menuItems: (LoggedEntry) -> MenuContent

    init(
        entries: [LoggedEntry],
        drafts: [EntryDraft] = [],
        emptyText: LocalizedStringKey,
        onSelectEntry: @escaping (LoggedEntry) -> Void,
        onSelectDraft: @escaping (EntryDraft) -> Void = { _ in },
        onDeleteDraft: ((EntryDraft) -> Void)? = nil,
        @ViewBuilder menuItems: @escaping (LoggedEntry) -> MenuContent
    ) {
        self.entries = entries
        self.drafts = drafts
        self.emptyText = emptyText
        self.onSelectEntry = onSelectEntry
        self.onSelectDraft = onSelectDraft
        self.onDeleteDraft = onDeleteDraft
        self.menuItems = menuItems
    }

    private var items: [TimelineItem] {
        (entries.map(TimelineItem.entry) + drafts.map(TimelineItem.draft))
            .sorted { $0.timestamp < $1.timestamp }
    }

    @ViewBuilder
    private func entryRow(_ entry: LoggedEntry) -> some View {
        let isVolume = entry.loggedUnit == VolumeUnit.milliliters.rawValue
        let mealRow = MealRow(
            name: entry.name,
            source: entry.source?.source ?? "",
            isCustomDefaultServing: false,
            customServingSize: "",
            servingSize: isVolume
                ? volumeUnit.formattedValue(entry.loggedQuantity)
                : EntryHelper.format(entry.loggedQuantity),
            servingSizeUnit: isVolume ? volumeUnit.rawValue : entry.loggedUnit,
            servingWeight: "",
            servingWeightUnit: "",
            servingUnits: servingUnits,
            calorie: String(entry.calories),
            protein: String(entry.protein),
            carbs: String(entry.carbs),
            fat: String(entry.fat),
            fiber: String(entry.fiber),
            icon: entry.entryType?.appSymbol,
            action: {
                onSelectEntry(entry)
            }
        )
        .drink(DrinkRowInfo(entry: entry))
        .attachmentHints(
            hasNote: !(entry.logNote ?? "").isEmpty,
            hasPhotos: !(entry.photos ?? []).isEmpty
        )

        if MenuContent.self != EmptyView.self {
            Menu {
                menuItems(entry)
            } label: {
                mealRow
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
            } primaryAction: {
                onSelectEntry(entry)
            }
            .buttonStyle(.plain)
            .padding(.top, -8)

        } else {
            mealRow
                .padding(.top, -8)
        }
    }

    @ViewBuilder
    private func draftRow(_ draft: EntryDraft) -> some View {
        let row = DraftRow(draft: draft, servingUnits: servingUnits) {
            onSelectDraft(draft)
        }

        if let onDeleteDraft {
            Menu {
                Button {
                    onSelectDraft(draft)
                } label: {
                    Label("Finish Logging", systemImage: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    onDeleteDraft(draft)
                } label: {
                    Label("Delete Draft", systemImage: "trash")
                }
            } label: {
                row
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
            } primaryAction: {
                onSelectDraft(draft)
            }
            .buttonStyle(.plain)
            .padding(.top, -8)
        } else {
            row
                .padding(.top, -8)
        }
    }

    @ViewBuilder
    private func timelineDot(isDraft: Bool) -> some View {
        if isDraft {
            Circle()
                .fill(Color.white)
                .overlay(
                    Circle().strokeBorder(Color.gray, lineWidth: 1.5)
                )
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
        }
    }

    var body: some View {
        let items = items

        VStack(spacing: 0) {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Text(emptyText)
                        .font(.compactTitle)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 16)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) {
                    index,
                    item in
                    let isFirst = index == 0
                    let isLast = index == items.count - 1

                    VStack(alignment: .leading, spacing: 0) {

                        HStack(spacing: 0) {
                            Text(formatTime(item.timestamp))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .fixedSize()

                            if let detail = item.detail {
                                Text(" · \(detail)")
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            if item.isDraft {
                                Text("Draft")
                                    .tagStyle()
                                    .fixedSize()
                                    .padding(.leading, 6)
                            }
                        }
                        .font(.subtitle)
                        .padding(.leading, 4)
                        .padding(.trailing, 16)
                        .padding(.bottom, 6)
                        .modifier(TimelineRemovalFade())

                        Group {
                            if let entry = item.entry {
                                entryRow(entry)
                            } else if let draft = item.draft {
                                draftRow(draft)
                            }
                        }
                        .modifier(TimelineRemovalFade(isMenuLabel: true))
                    }
                    .clipped()
                    .padding(.leading, 20)
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .top) {
                            if isFirst && isLast {
                                Capsule()
                                    .fill(Color.trackFill)
                                    .frame(width: 2)
                                    .padding(.top, 8)
                                    .padding(.bottom, 16)
                            } else if isFirst {
                                Rectangle()
                                    .fill(Color.trackFill)
                                    .frame(width: 2)
                                    .padding(.top, 8)
                            } else if isLast {
                                Capsule()
                                    .fill(Color.trackFill)
                                    .frame(width: 2)
                                    .padding(.bottom, 16)
                            } else {
                                Rectangle()
                                    .fill(Color.trackFill)
                                    .frame(width: 2)
                            }

                            timelineDot(isDraft: item.isDraft)
                                .padding(.top, 4)
                        }
                        .frame(width: 32)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .modifier(TimelineRemovalFade())
                    }
                    .transition(TimelineRowTransition())
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened).lowercased()
    }
}

private extension EnvironmentValues {
    @Entry var isTimelineRowRemoving = false
}

private struct TimelineRowTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase == .willAppear ? 0 : 1)
            .scaleEffect(phase == .willAppear ? 0.95 : 1)
            .environment(\.isTimelineRowRemoving, phase == .didDisappear)
    }
}

private struct TimelineRemovalFade: ViewModifier {
    @Environment(\.isTimelineRowRemoving) private var isRemoving
    var isMenuLabel = false

    func body(content: Content) -> some View {
        content
            .opacity(isRemoving ? 0 : 1)
            .transaction(value: isRemoving) { transaction in
                if isMenuLabel && transaction.isMenuDelete {
                    transaction.animation = nil
                }
            }
    }
}

extension TimelineCard where MenuContent == EmptyView {
    init(
        date: Date,
        clickedEntry: Binding<LoggedEntry?> = .constant(nil)
    ) {
        self.init(
            date: date,
            clickedEntry: clickedEntry,
            menuItems: { _ in EmptyView() }
        )
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    func makeTime(hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)
            ?? today
    }

    let container: ModelContainer
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: LoggedEntry.self,
            FoodItem.self,
            configurations: config
        )
    } catch {
        fatalError(
            "Failed to create preview container: \(error.localizedDescription)"
        )
    }

    let context = container.mainContext

    // 1. Eggs & Tater Tots
    let eggsEntry = LoggedEntry(
        name: "Eggs & Tater Tots",
        typeRawValue: "food",
        timestamp: makeTime(hour: 9, minute: 45),
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 750,
        protein: 35,
        carbs: 40,
        fat: 50,
        fiber: 4
    )
    let eggsFood = FoodItem(
        name: "Eggs & Tater Tots",
        servingSize: 1,
        servingWeightUnit: "g",
        isAIEstimated: true,
        calories: 750,
        protein: 35,
        carbs: 40,
        fat: 50,
        fiber: 4,
        isCustomDefaultServing: false
    )
    eggsEntry.originalFoodItem = eggsFood
    context.insert(eggsEntry)

    // 2. Double Chicken Bowl
    let chickenEntry = LoggedEntry(
        name: "Double Chicken Bowl",
        typeRawValue: "recipe",
        timestamp: makeTime(hour: 14, minute: 9),
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 955,
        protein: 84,
        carbs: 68,
        fat: 38,
        fiber: 11
    )
    context.insert(chickenEntry)

    // 3. Coconut Water
    let coconutEntry = LoggedEntry(
        name: "Coconut Water",
        typeRawValue: "drink",
        timestamp: makeTime(hour: 14, minute: 11),
        loggedQuantity: 310,
        loggedUnit: "ml",
        calories: 60,
        protein: 0,
        carbs: 13,
        fat: 0,
        fiber: 0
    )
    let coconutFood = FoodItem(
        name: "Coconut Water",
        type: .drink,
        servingSize: 1,
        servingWeight: 310,
        servingWeightUnit: "ml",
        isAIEstimated: false,
        calories: 60,
        protein: 0,
        carbs: 13,
        fat: 0,
        fiber: 0,
        isCustomDefaultServing: false
    )
    coconutFood.symbol = "leaf.fill"
    coconutFood.tintRawValue = DrinkTint.green.rawValue
    coconutEntry.originalFoodItem = coconutFood
    context.insert(coconutEntry)
    coconutEntry.snapshotDrinkAmounts(children: [])

    // 4. Vanilla Chocolate Sprinkle Bar
    let barEntry = LoggedEntry(
        name: "Vanilla Chocolate Sprinkle Bar",
        typeRawValue: "food",
        timestamp: makeTime(hour: 16, minute: 3),
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 440,
        protein: 4,
        carbs: 54,
        fat: 23,
        fiber: 0
    )
    context.insert(barEntry)

    // Unfinished log
    let bagelFood = FoodItem(
        name: "Everything Bagel",
        servingSize: 1,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 290,
        protein: 11,
        carbs: 56,
        fat: 2,
        fiber: 2,
        isCustomDefaultServing: false
    )
    context.insert(bagelFood)
    let bagelDraft = EntryDraft(
        kind: .logFood,
        type: .food,
        name: "Everything Bagel",
        timestamp: makeTime(hour: 17, minute: 30),
        foodItem: bagelFood
    )
    context.insert(bagelDraft)

    // 5. Lights Caramel Action
    let iceCreamEntry = LoggedEntry(
        name: "Lights Caramel Action",
        typeRawValue: "food",
        timestamp: makeTime(hour: 20, minute: 3),
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 390,
        protein: 5,
        carbs: 47,
        fat: 21,
        fiber: 0
    )
    let iceCreamFood = FoodItem(
        name: "Lights Caramel Action",
        servingSize: 1,
        servingWeight: 144,
        servingWeightUnit: "g",
        isAIEstimated: false,
        calories: 390,
        protein: 5,
        carbs: 47,
        fat: 21,
        fiber: 0,
        isCustomDefaultServing: false
    )
    iceCreamEntry.originalFoodItem = iceCreamFood
    context.insert(iceCreamEntry)

    return ScrollView {
        TimelineCard(
            date: today,
            onDeleteDraft: { draft in
                print("Delete draft \(draft.name)")
            }
        ) { entry in
            Button {
                print("Edit \(entry.name)")
            } label: {
                Label("Edit Entry", systemImage: "pencil")
            }

            Button {
                print("Duplicate \(entry.name)")
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Divider()

            Button(role: .destructive) {
                print("Delete \(entry.name)")
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .modelContainer(container)
}

