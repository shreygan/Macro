//
//  DraftRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/28/26.
//

import SwiftUI

struct DraftRow: View {
    var name: String
    var nameSuffix: String?
    var subtitle: String
    var icon: AppSymbols?
    var status: String?
    var statusSymbol: String?

    var action: (() -> Void)?

    init(
        draft: EntryDraft,
        servingUnits: [ServingSizeUnit] = [],
        showsLogDate: Bool = false,
        showsFoodName: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.action = action

        if !showsFoodName {
            let details = Self.historyDetails(for: draft, units: servingUnits)
            self.name =
                draft.timestamp.map(EntryHelper.logDateText) ?? "No Date"
            self.nameSuffix = details.category
            self.subtitle = details.subtitle
            let edited = draft.updatedAt.formatted(
                .relative(presentation: .named)
            )
            self.status = "Edited \(edited)"
            self.statusSymbol = "clock.arrow.circlepath"
            return
        }

        let typeName = draft.entryType?.rawValue.capitalized ?? "Entry"
        self.name = draft.name.isEmpty ? "New \(typeName)" : draft.name
        self.subtitle = Self.buildSubtitle(for: draft, units: servingUnits)
        self.icon = draft.entryType?.appSymbol

        if draft.kind?.isLog == true {
            if showsLogDate, let timestamp = draft.timestamp {
                self.status = "Logging for \(EntryHelper.logDateText(timestamp))"
                self.statusSymbol = "calendar.badge.clock"
            } else {
                self.status = nil
                self.statusSymbol = nil
            }
        } else {
            let edited = draft.updatedAt.formatted(
                .relative(presentation: .named)
            )
            self.status = "Adding to Library · Edited \(edited)"
            self.statusSymbol = "book.pages"
        }
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

    private static func historyDetails(
        for draft: EntryDraft,
        units: [ServingSizeUnit]
    ) -> (category: String?, subtitle: String) {
        let source: String
        let category: String
        let location: String
        let detail: String

        switch draft.kind {
        case .logFood:
            guard let state = draft.decodeState(LogEntryDraftState.self)
            else { return (nil, "") }
            source = state.sourceSelection
            category = state.categorySelection
            location = state.location
            detail = portion(
                state.portionQuantity,
                state.portionUnitSelection,
                units: units
            )
        case .logRecipe:
            guard let state = draft.decodeState(LogRecipeDraftState.self)
            else { return (nil, "") }
            source = state.sourceSelection
            category = state.categorySelection
            location = state.location
            detail = portion(
                state.portionQuantity,
                state.portionUnitSelection,
                units: units
            )
        default:
            return (nil, buildSubtitle(for: draft, units: units))
        }

        var parts = [detail]
        if !source.isEmpty, source != "None",
            source != draft.foodItem?.source?.source
        {
            parts.insert(source, at: 0)
        }
        if !location.isEmpty {
            parts.append(location)
        }

        let categoryText =
            category.isEmpty || category == "None" ? nil : category
        return (categoryText, parts.joined(separator: " · "))
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

    private var titleText: Text {
        let title = Text(name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)

        guard let nameSuffix else { return title }

        let suffix = Text(" · \(nameSuffix)")
            .font(.system(size: 14))
            .foregroundColor(.tertiary)

        return Text("\(title)\(suffix)")
    }

    var body: some View {
        let rowContent = HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    titleText
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
                    HStack(spacing: 4) {
                        if let statusSymbol {
                            Image(systemName: statusSymbol)
                                .font(.system(size: 11, weight: .medium))
                        }

                        Text(status)
                            .font(.system(size: 12, weight: .medium))
                    }
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
