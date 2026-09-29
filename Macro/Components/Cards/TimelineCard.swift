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
}

struct TimelineCard<MenuContent: View>: View {
    @Query private var entries: [LoggedEntry]
    @Query private var drafts: [EntryDraft]
    @Query(sort: \ServingSizeUnit.displayOrder) private var servingUnits:
        [ServingSizeUnit]
    @Binding var clickedEntry: LoggedEntry?
    @Binding var clickedDraft: EntryDraft?

    let menuItems: (LoggedEntry) -> MenuContent
    var onDeleteDraft: ((EntryDraft) -> Void)?

    init(
        date: Date,
        clickedEntry: Binding<LoggedEntry?> = .constant(nil),
        clickedDraft: Binding<EntryDraft?> = .constant(nil),
        onDeleteDraft: ((EntryDraft) -> Void)? = nil,
        @ViewBuilder menuItems: @escaping (LoggedEntry) -> MenuContent
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

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
        self.menuItems = menuItems
    }

    private var items: [TimelineItem] {
        (entries.map(TimelineItem.entry) + drafts.map(TimelineItem.draft))
            .sorted { $0.timestamp < $1.timestamp }
    }

    @ViewBuilder
    private func entryRow(_ entry: LoggedEntry) -> some View {
        let mealRow = MealRow(
            name: entry.name,
            source: entry.source?.source ?? "None",
            isCustomDefaultServing: false,
            customServingSize: "",
            servingSize: EntryHelper.format(
                entry.loggedQuantity
            ),
            servingSizeUnit: entry.loggedUnit,
            servingWeight: "",
            servingWeightUnit: "",
            servingUnits: servingUnits,
            calorie: String(entry.calories),
            protein: String(entry.protein),
            carbs: String(entry.carbs),
            fat: String(entry.fat),
            fiber: String(entry.fiber),
            action: {
                clickedEntry = entry
            }
        )

        if MenuContent.self != EmptyView.self {
            Menu {
                menuItems(entry)
            } label: {
                mealRow
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
            } primaryAction: {
                clickedEntry = entry
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
            clickedDraft = draft
        }

        if let onDeleteDraft {
            Menu {
                Button {
                    clickedDraft = draft
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
                clickedDraft = draft
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

        Card("Timeline") {
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Text("No entries logged today.")
                            .font(.subheadline)
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

                                if let categoryName = item.entry?.category?
                                    .category,
                                    !categoryName.isEmpty
                                {
                                    Text(", \(categoryName)")
                                        .foregroundColor(.secondary)
                                }

                                if item.isDraft {
                                    Text("Draft")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule()
                                                .strokeBorder(
                                                    Color.secondary,
                                                    lineWidth: 1
                                                )
                                        )
                                        .padding(.leading, 6)
                                }
                            }
                            .font(.system(size: 13))
                            .padding(.leading, 4)
                            .padding(.bottom, 6)

                            if let entry = item.entry {
                                entryRow(entry)
                            } else if let draft = item.draft {
                                draftRow(draft)
                            }
                        }
                        .clipped()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.animation(.linear(duration: 0))
                            )
                        )
                        .padding(.leading, 20)
                        .overlay(alignment: .topLeading) {
                            ZStack(alignment: .top) {
                                if isFirst && isLast {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .padding(.top, 8)
                                        .padding(.bottom, 16)
                                } else if isFirst {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .padding(.top, 8)
                                } else if isLast {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .padding(.bottom, 16)
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                }

                                timelineDot(isDraft: item.isDraft)
                                    .padding(.top, 4)
                            }
                            .frame(width: 32)
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date).lowercased()
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
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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
        typeRawValue: "meal",
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
        typeRawValue: "meal",
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
        calories: 750,
        protein: 0,
        carbs: 13,
        fat: 0,
        fiber: 0
    )
    context.insert(coconutEntry)

    // 4. Vanilla Chocolate Sprinkle Bar
    let barEntry = LoggedEntry(
        name: "Vanilla Chocolate Sprinkle Bar",
        typeRawValue: "snack",
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
        typeRawValue: "snack",
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
