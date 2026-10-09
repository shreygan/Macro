//
//  LogHistoryRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/8/26.
//

import SwiftUI

struct LogHistoryRow: View {
    let entry: LoggedEntry
    let servingUnits: [ServingSizeUnit]
    var action: (() -> Void)?

    private var category: String? {
        guard let category = entry.category?.category, !category.isEmpty
        else { return nil }
        return category
    }

    private var subtitle: String {
        var parts = [
            EntryHelper.portionText(
                quantity: entry.loggedQuantity,
                unit: entry.loggedUnit,
                servingUnits: servingUnits
            )
        ]

        if let source = entry.source?.source, !source.isEmpty,
            source != entry.originalFoodItem?.source?.source
        {
            parts.insert(source, at: 0)
        }

        if let location = entry.location, !location.isEmpty {
            parts.append(location)
        }

        return parts.joined(separator: " · ")
    }

    private var hasNote: Bool {
        !(entry.logNote ?? "").isEmpty
    }

    private var hasPhotos: Bool {
        !(entry.photos ?? []).isEmpty
    }

    var body: some View {
        if let action {
            rowContent
                .onTapGesture {
                    action()
                }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                titleText
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                macrosText
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if hasNote || hasPhotos {
                HStack(spacing: 6) {
                    if hasNote {
                        Image(systemName: "note.text")
                    }
                    if hasPhotos {
                        Image(systemName: "photo")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            }

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var titleText: Text {
        let date = Text(EntryHelper.logDateText(entry.timestamp))
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)

        guard let category else { return date }

        let suffix = Text(" · \(category)")
            .font(.system(size: 14))
            .foregroundColor(.secondary)

        return Text("\(date)\(suffix)")
    }

    private var macrosText: Text {
        let strut = Text("\u{200B}").font(.system(size: 16))
        var result = macroText(.calorie, value: entry.calories, isFirst: true)

        let macros: [(RowIcon, Double)] = [
            (.protein, entry.protein),
            (.carbs, entry.carbs),
            (.fat, entry.fat),
            (.fiber, entry.fiber),
        ]
        for (icon, value) in macros where value > 0 {
            result = Text("\(result)\(macroText(icon, value: value, isFirst: false))")
        }

        return Text("\(result)\(strut)")
    }

    private func macroText(_ icon: RowIcon, value: Double, isFirst: Bool) -> Text {
        icon.macroText(
            EntryHelper.formatMacro(value),
            iconSize: 12,
            valueSize: 12,
            valueColor: .primary,
            isFirst: isFirst
        )
    }
}

#Preview {
    let today = LoggedEntry(
        name: "Brown Rice",
        typeRawValue: "ingredient",
        loggedQuantity: 2,
        loggedUnit: "serving",
        calories: 432,
        protein: 10,
        carbs: 90,
        fat: 3.6,
        fiber: 7,
        logNote: "Cooked with extra butter"
    )
    let lastWeek = LoggedEntry(
        name: "Brown Rice",
        typeRawValue: "ingredient",
        timestamp: Date().addingTimeInterval(-6 * 86400),
        location: "Home",
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 216,
        protein: 5,
        carbs: 45,
        fat: 1.8,
        fiber: 3.5
    )

    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        Card("History") {
            RowGroup(.divider) {
                LogHistoryRow(entry: today, servingUnits: []) {}
                LogHistoryRow(entry: lastWeek, servingUnits: []) {}
            }
        }
        .padding()
    }
}
