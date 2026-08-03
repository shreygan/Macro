//
//  TimelineCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/28/26.
//

import SwiftData
import SwiftUI

struct TimelineCard: View {
    @Query private var entries: [LoggedEntry]

    init(date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<LoggedEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
        }

        _entries = Query(filter: predicate, sort: \.timestamp)
    }

    var body: some View {
        Card("Timeline") {
            VStack(spacing: 0) {
                if entries.isEmpty {
                    VStack(spacing: 16) {
                        Text("No entries logged today.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) {
                        index,
                        entry in
                        let isFirst = index == 0
                        let isLast = index == entries.count - 1

                        VStack(alignment: .leading, spacing: 0) {

                            HStack(spacing: 0) {
                                Text(formatTime(entry.timestamp))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                if let categoryName = entry.category?.category,
                                    !categoryName.isEmpty
                                {
                                    Text(", \(categoryName)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.system(size: 13))
                            .padding(.leading, -8)

                            MealRow(
                                name: entry.name,
                                source: entry.source?.source ?? "None",
                                isCustomDefaultServing: entry.originalFoodItem?
                                    .isCustomDefaultServing ?? false,
                                customServingSize: EntryHelper.format(
                                    entry.originalFoodItem?.customServingSize
                                        ?? 0
                                ),
                                servingSize: EntryHelper.format(
                                    entry.loggedQuantity
                                ),
                                servingSizeUnit: entry.loggedUnit,
                                servingWeight: "",
                                servingWeightUnit: "",
                                servingUnits: [],
                                calorie: String(entry.calories),
                                protein: String(entry.protein),
                                carbs: String(entry.carbs),
                                fat: String(entry.fat),
                                fiber: String(entry.fiber),
                                action: {
                                }
                            )
                            .padding(.leading, -12)
                        }
                        .padding(.leading, 32)
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

                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 8, height: 8)
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
        TimelineCard(date: today)
            .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .modelContainer(container)
}
