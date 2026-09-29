//
//  DraftRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftUI

struct DraftRow: View {
    var name: String
    var subtitle: String
    var icon: AppSymbols?
    var status: String?

    var action: (() -> Void)?

    init(
        draft: EntryDraft,
        servingUnits: [ServingSizeUnit] = [],
        showsLogDate: Bool = false,
        action: (() -> Void)? = nil
    ) {
        let typeName = draft.entryType?.rawValue.capitalized ?? "Entry"
        self.name = draft.name.isEmpty ? "New \(typeName)" : draft.name
        self.subtitle = Self.buildSubtitle(for: draft, units: servingUnits)
        self.icon = draft.entryType?.appSymbol
        self.action = action

        if draft.kind?.isLog == true {
            if showsLogDate, let timestamp = draft.timestamp {
                self.status = Self.formatLogDate(timestamp)
            } else {
                self.status = nil
            }
        } else {
            let edited = draft.updatedAt.formatted(
                .relative(presentation: .named)
            )
            self.status = "Edited \(edited)"
        }
    }

    private static func formatLogDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
            .lowercased()

        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else {
            day = date.formatted(.dateTime.weekday(.abbreviated).month().day())
        }

        return "\(day), \(time)"
    }

    private static func portion(
        _ quantity: String,
        _ unit: String,
        units: [ServingSizeUnit]
    ) -> String {
        let displayUnit =
            units.first(where: { $0.unit == unit })?
            .displayString(for: quantity) ?? unit
        return "\(quantity) \(displayUnit)"
    }

    private static func buildSubtitle(
        for draft: EntryDraft,
        units: [ServingSizeUnit]
    ) -> String {
        let source: String
        let detail: String

        switch draft.kind {
        case .logFood:
            guard let state = draft.decodeState(LogEntryDraftState.self)
            else { return "" }
            source = state.sourceSelection
            detail = portion(
                state.portionQuantity,
                state.portionUnitSelection,
                units: units
            )
        case .logRecipe:
            guard let state = draft.decodeState(LogRecipeDraftState.self)
            else { return "" }
            source = state.sourceSelection
            detail = portion(
                state.portionQuantity,
                state.portionUnitSelection,
                units: units
            )
        case .addFood:
            guard let state = draft.decodeState(AddEntryDraftState.self)
            else { return "" }
            source = state.source
            detail = portion(
                state.servingSize,
                state.servingSizeUnit,
                units: units
            )
        case .addRecipe:
            guard let state = draft.decodeState(AddRecipeDraftState.self)
            else { return "" }
            source = state.source
            let count = state.ingredients.count
            detail = count == 1 ? "1 ingredient" : "\(count) ingredients"
        case nil:
            return ""
        }

        return source.isEmpty ? detail : "\(source), \(detail)"
    }

    var body: some View {
        let rowContent = HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let icon = icon {
                        icon.image
                            .font(.system(size: 13))
                            .foregroundColor(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let status {
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())

        if let action = action {
            rowContent
                .onTapGesture {
                    action()
                }
        } else {
            rowContent
        }
    }
}
