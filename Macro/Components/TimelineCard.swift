//
//  TimelineCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/28/26.
//

import SwiftData
import SwiftUI

struct TimelineCard: View {
    var entries: [LoggedEntry]

    var sortedEntries: [LoggedEntry] {
        entries.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        Card("Timeline") {
            VStack(spacing: 0) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) {
                    index,
                    entry in
                    let isFirst = index == 0
                    let isLast = index == sortedEntries.count - 1

                    VStack(alignment: .leading, spacing: 0) {

                        HStack(spacing: 0) {
                            Text(formatTime(entry.timestamp))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(", \(entry.typeRawValue)")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 13))
                        .padding(.leading, -8)

                        MealRow(
                            name: entry.name,
                            source: buildSourceString(for: entry),
                            isCustomDefaultServing: entry.originalFoodItem?
                                .isCustomDefaultServing ?? false,
                            customServingSize: String(
                                entry.originalFoodItem?.customServingSize ?? 0
                            ),
                            servingSize: String(entry.loggedQuantity),
                            servingSizeUnit: entry.loggedUnit,
                            servingWeight: String(
                                entry.originalFoodItem?.servingWeight ?? 0
                            ),
                            servingWeightUnit: entry.originalFoodItem?
                                .servingWeightUnit ?? "",
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

                            if sortedEntries.count > 1 {
                                if isFirst {
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
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date).lowercased()
    }

    private func buildSourceString(for entry: LoggedEntry) -> String {
        var sourceText = entry.originalFoodItem?.source?.source ?? ""
        if entry.originalFoodItem?.isAIEstimated == true {
            sourceText += sourceText.isEmpty ? "AI estimate" : ", AI estimate"
        }
        return sourceText
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    func makeTime(hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)
            ?? today
    }

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

    return ScrollView {
        TimelineCard(entries: [
            eggsEntry,
            chickenEntry,
            coconutEntry,
            barEntry,
            iceCreamEntry,
        ])
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
