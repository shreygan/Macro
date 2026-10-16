//
//  LogHistoryRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/8/26.
//

import SwiftUI

struct LogHistoryRow: View {
    struct Override {
        var origin: String
        var quantity: Double
        var unit: String
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var isRecalculated = false
    }

    let entry: LoggedEntry
    let servingUnits: [ServingSizeUnit]
    var override: Override? = nil
    var action: (() -> Void)?

    private var category: String? {
        guard let category = entry.category?.category, !category.isEmpty
        else { return nil }
        return category
    }

    private var detailText: Text {
        var parts = [
            EntryHelper.portionText(
                quantity: override?.quantity ?? entry.loggedQuantity,
                unit: override?.unit ?? entry.loggedUnit,
                servingUnits: servingUnits
            )
        ]

        if let source = entry.source?.source, !source.isEmpty,
            source != entry.originalFoodItem?.source?.source
        {
            parts.insert(source, at: 0)
        }

        return Text.detailLine(parts, location: entry.locationName) ?? Text("")
    }

    @ViewBuilder
    private var subtitle: some View {
        if let origin = override?.origin {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(origin)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(" · \(detailText)")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
        } else {
            detailText
                .lineLimit(1)
                .truncationMode(.tail)
        }
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

                subtitle
                    .font(.subtitle)
                    .foregroundStyle(Color.tertiaryText)

                macrosText
                    .contentTransition(override == nil ? .identity : .numericText())
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            AttachmentHints(hasNote: hasNote, hasPhotos: hasPhotos)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.chevron)
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, RowMetrics.verticalPadding)
        .contentShape(Rectangle())
    }

    private var titleText: Text {
        let date = Text(EntryHelper.logDateText(entry.timestamp))
            .font(.compactTitle)
            .foregroundColor(.primary)

        guard let category else { return date }

        let suffix = Text(" · \(category)")
            .font(.compactValue)
            .foregroundColor(.secondary)

        return Text("\(date)\(suffix)")
    }

    private var macrosText: Text {
        let strut = Text("\u{200B}").font(.rowValue)
        var result = macroText(.calorie, value: override?.calories ?? entry.calories, isFirst: true)

        let macros: [(RowIcon, Double)] = [
            (.protein, override?.protein ?? entry.protein),
            (.carbs, override?.carbs ?? entry.carbs),
            (.fat, override?.fat ?? entry.fat),
            (.fiber, override?.fiber ?? entry.fiber),
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
            valueColor: override?.isRecalculated == true ? Color.accentColor : .primary,
            isFirst: isFirst
        )
    }
}

struct AttachmentHints: View {
    let hasNote: Bool
    let hasPhotos: Bool

    var body: some View {
        if hasNote || hasPhotos {
            HStack(spacing: 6) {
                if hasNote {
                    Image(systemName: "note.text")
                        .accessibilityLabel("Has Note")
                }
                if hasPhotos {
                    Image(systemName: "photo")
                        .accessibilityLabel("Has Photos")
                }
            }
            .font(.detail)
            .foregroundStyle(Color.tertiaryText)
        }
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
        location: EntryLocation(name: "Home"),
        loggedQuantity: 1,
        loggedUnit: "serving",
        calories: 216,
        protein: 5,
        carbs: 45,
        fat: 1.8,
        fiber: 3.5
    )

    ZStack {
        Color.background.ignoresSafeArea()

        Card("History") {
            RowGroup(.divider) {
                LogHistoryRow(entry: today, servingUnits: []) {}
                LogHistoryRow(entry: lastWeek, servingUnits: []) {}
            }
        }
        .padding()
    }
}
