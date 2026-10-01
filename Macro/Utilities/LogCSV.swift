//
//  LogCSV.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation

enum LogCSV {
    enum Column: String, CSVColumn {
        case record = "Record"
        case id = "ID"
        case parentID = "Parent ID"
        case foodID = "Food ID"
        case type = "Type"
        case name = "Name"
        case source = "Source"
        case category = "Category"
        case foodGroup = "Food Group"
        case date = "Date"
        case time = "Time"
        case location = "Location"
        case quantity = "Quantity"
        case unit = "Unit"
        case calories = "Calories"
        case protein = "Protein"
        case carbs = "Carbs"
        case fat = "Fat"
        case fiber = "Fiber"
        case isManualOverride = "Manual Override"
        case note = "Note"
        case order = "Order"

        var aliases: [String] {
            switch self {
            case .record: return ["row type", "kind"]
            case .name: return ["meal", "food"]
            case .date: return ["timestamp", "logged at", "date logged", "time"]
            case .time: return ["time logged", "logged time"]
            case .calories: return ["calorie", "kcal", "energy"]
            case .carbs: return ["carb", "carbohydrate", "carbohydrates"]
            case .fat: return ["fats", "total fat"]
            case .fiber: return ["fibre"]
            case .protein: return ["proteins"]
            case .quantity: return ["amount", "portion"]
            case .unit: return ["portion unit", "serving unit"]
            case .note: return ["notes", "log note"]
            default: return []
            }
        }

        var aliasRequiresText: Bool { self == .name }
    }

    static let exportedColumns = Column.allCases.filter { $0 != .time }

    enum Record: String {
        case log = "Log"
        case ingredient = "Ingredient"
    }

    struct ParseResult {
        var entries: [DraftLogEntry] = []
        var issues: [ImportIssue] = []

        var newEntries: [DraftLogEntry] {
            entries.filter { $0.duplicateOf == nil }
        }

        var duplicateEntries: [DraftLogEntry] {
            entries.filter { $0.duplicateOf != nil }
        }

        var invalidCount: Int {
            issues.filter { $0.kind == .invalid }.count
        }
    }

    struct ExistingLog {
        let id: UUID
        let name: String
        let timestamp: Date
    }

    static func duplicateKey(name: String, timestamp: Date) -> String {
        "\(LibraryCSV.normalized(name))|\(Int(timestamp.timeIntervalSince1970.rounded()))"
    }

    static func export(_ entries: [LoggedEntry]) -> String {
        var rows = [exportedColumns.map(\.rawValue)]

        let topLevel = entries
            .filter { $0.parentEntry == nil }
            .sorted { $0.timestamp < $1.timestamp }

        for entry in topLevel {
            rows.append(row(fields(for: entry, parent: nil)))

            let children = (entry.childEntries ?? []).sorted {
                $0.displayOrder < $1.displayOrder
            }
            for child in children {
                rows.append(row(fields(for: child, parent: entry)))
            }
        }

        return "\u{FEFF}" + CSVCoder.encode(rows)
    }

    private static func row(_ values: [Column: String]) -> [String] {
        exportedColumns.map { values[$0] ?? "" }
    }

    private static func fields(for entry: LoggedEntry, parent: LoggedEntry?)
        -> [Column: String]
    {
        [
            .record: parent == nil
                ? Record.log.rawValue : Record.ingredient.rawValue,
            .id: entry.id.uuidString,
            .parentID: parent?.id.uuidString ?? "",
            .foodID: entry.originalFoodItem?.id.uuidString ?? "",
            .type: entry.typeRawValue,
            .name: entry.name,
            .source: entry.source?.source ?? "",
            .category: entry.category?.category ?? "",
            .foodGroup: entry.foodGroup?.foodGroup ?? "",
            .date: LibraryCSV.format(entry.timestamp),
            .location: entry.location ?? "",
            .quantity: LibraryCSV.format(entry.loggedQuantity),
            .unit: entry.loggedUnit,
            .calories: LibraryCSV.format(entry.calories),
            .protein: LibraryCSV.format(entry.protein),
            .carbs: LibraryCSV.format(entry.carbs),
            .fat: LibraryCSV.format(entry.fat),
            .fiber: LibraryCSV.format(entry.fiber),
            .isManualOverride: LibraryCSV.format(entry.isManualOverride),
            .note: entry.logNote ?? "",
            .order: String(entry.displayOrder),
        ]
    }

    static let requiredColumns: [Column] = [.name, .date, .calories]

    static let optionalColumns: [Column] = [
        .time, .protein, .carbs, .fat, .fiber, .quantity, .unit, .source, .category,
        .foodGroup, .location, .note,
    ]

    static func columns(
        forHeader header: [String],
        rows: [CSVRow] = []
    ) -> [Column: Int]? {
        let columns = CSVCoder.columns(in: header, rows: rows, as: Column.self)
        guard requiredColumns.allSatisfy({ columns[$0] != nil }) else {
            return nil
        }
        return columns
    }

    static func containsLogRecords(_ rows: [CSVRow], columns: [Column: Int]) -> Bool {
        guard let index = columns[.record] else { return false }
        let logRecord = LibraryCSV.normalized(Record.log.rawValue)
        return rows.contains { row in
            index < row.fields.count
                && LibraryCSV.normalized(row.fields[index]) == logRecord
        }
    }

    static func parse(
        rows: [CSVRow],
        columns: [Column: Int],
        existing: [ExistingLog]
    ) -> ParseResult {
        var result = ParseResult()

        let existingIDs = Set(existing.map(\.id))
        var existingByKey: [String: [UUID]] = [:]
        for log in existing {
            existingByKey[
                duplicateKey(name: log.name, timestamp: log.timestamp),
                default: []
            ].append(log.id)
        }
        var claimedExistingIDs = Set<UUID>()
        var skippedIDs = Set<UUID>()

        var seenIDs = Set<UUID>()
        var seenKeys = Set<String>()
        var indexByID: [UUID: Int] = [:]
        var lastIndex: Int?
        var lastWasSkipped = false
        var lastSkippedID: UUID?
        var deferred:
            [(row: Int, parentID: UUID, hasDate: Bool, component: DraftLogEntry)] = []

        for row in rows {
            let field: (Column) -> String = { column in
                guard let index = columns[column], index < row.fields.count
                else { return "" }
                return row.fields[index].trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            let rowName = field(.name)

            let isComponent =
                LibraryCSV.normalized(field(.record))
                == LibraryCSV.normalized(Record.ingredient.rawValue)

            if isComponent {
                let parentID = UUID(uuidString: field(.parentID))
                if let parentID, skippedIDs.contains(parentID) { continue }
                if lastWasSkipped && (parentID == nil || parentID == lastSkippedID) {
                    continue
                }

                if let reason = invalidReason(field) {
                    skip(&result, row.number, rowName, reason)
                    continue
                }
                guard let component = makeEntry(field, isComponent: true) else {
                    continue
                }
                let hasDate = timestamp(field) != nil

                if let parentID {
                    deferred.append((row.number, parentID, hasDate, component))
                } else if let lastIndex {
                    var component = component
                    component.displayOrder =
                        result.entries[lastIndex].components.count
                    if !hasDate {
                        component.timestamp = result.entries[lastIndex].timestamp
                    }
                    result.entries[lastIndex].components.append(component)
                } else {
                    skip(
                        &result,
                        row.number,
                        rowName,
                        "Ingredient row has no log above it."
                    )
                }
                continue
            }

            lastIndex = nil
            lastWasSkipped = false
            lastSkippedID = nil

            if let reason = invalidReason(field) {
                skip(&result, row.number, rowName, reason)
                lastWasSkipped = true
                if let id = UUID(uuidString: field(.id)) {
                    lastSkippedID = id
                    skippedIDs.insert(id)
                }
                continue
            }
            guard var draft = makeEntry(field, isComponent: false) else {
                continue
            }

            let key = duplicateKey(name: draft.name, timestamp: draft.timestamp)
            let isRepeatedInFile =
                if let id = draft.importID {
                    seenIDs.contains(id)
                } else {
                    seenKeys.contains(key)
                }

            if isRepeatedInFile {
                result.issues.append(
                    ImportIssue(
                        kind: .repeated,
                        row: row.number,
                        name: rowName,
                        reason: "Appears earlier in this file."
                    )
                )
                lastWasSkipped = true
                lastSkippedID = draft.importID
                continue
            }

            if let id = draft.importID, existingIDs.contains(id) {
                draft.duplicateOf = id
            } else if let match = existingByKey[key]?.first(where: {
                !claimedExistingIDs.contains($0)
            }) {
                draft.duplicateOf = match
            }
            if let match = draft.duplicateOf {
                claimedExistingIDs.insert(match)
            }

            if draft.duplicateOf != nil {
                result.issues.append(
                    ImportIssue(
                        kind: .duplicate,
                        row: row.number,
                        name: rowName,
                        reason: "Already in your log history."
                    )
                )
            }

            if let id = draft.importID {
                seenIDs.insert(id)
                indexByID[id] = result.entries.count
            } else {
                seenKeys.insert(key)
            }

            lastIndex = result.entries.count
            result.entries.append(draft)
        }

        for (rowNumber, parentID, hasDate, component) in deferred {
            if skippedIDs.contains(parentID) { continue }
            guard let index = indexByID[parentID] else {
                if !seenIDs.contains(parentID) {
                    skip(
                        &result,
                        rowNumber,
                        component.name,
                        "Its Parent ID doesn't match any log in this file."
                    )
                }
                continue
            }
            var component = component
            if !hasDate {
                component.timestamp = result.entries[index].timestamp
            }
            result.entries[index].components.append(component)
        }

        for index in result.entries.indices {
            result.entries[index].components.sort {
                $0.displayOrder < $1.displayOrder
            }
            if !result.entries[index].components.isEmpty
                && result.entries[index].typeRawValue == EntryType.food.rawValue
            {
                result.entries[index].typeRawValue = EntryType.recipe.rawValue
            }
        }

        return result
    }

    private static func skip(
        _ result: inout ParseResult,
        _ row: Int,
        _ name: String,
        _ reason: String
    ) {
        result.issues.append(
            ImportIssue(
                kind: .invalid,
                row: row,
                name: name.isEmpty ? nil : name,
                reason: reason
            )
        )
    }

    private static func invalidReason(_ field: (Column) -> String) -> String? {
        if field(.name).isEmpty {
            return "Log is missing a name."
        }

        let isComponent =
            LibraryCSV.normalized(field(.record))
            == LibraryCSV.normalized(Record.ingredient.rawValue)
        if !isComponent && timestamp(field) == nil {
            if field(.date).isEmpty { return "Log is missing a date." }
            if LibraryCSV.date(field(.date)) == nil {
                return "\"\(field(.date))\" isn't a recognized date."
            }
            return "\"\(field(.time))\" isn't a recognized time."
        }

        let numericColumns: [Column] = [
            .calories, .protein, .carbs, .fat, .fiber,
        ]
        for column in numericColumns where LibraryCSV.macro(field(column)) == nil {
            return "\"\(field(column))\" isn't a valid number for \(column.rawValue)."
        }

        let quantity = field(.quantity)
        if !quantity.isEmpty && Double(quantity) == nil {
            return "\"\(quantity)\" isn't a valid number for Quantity."
        }

        return nil
    }

    private static func timestamp(_ field: (Column) -> String) -> Date? {
        LibraryCSV.date(field(.date), time: field(.time))
    }

    private static func makeEntry(
        _ field: (Column) -> String,
        isComponent: Bool
    ) -> DraftLogEntry? {
        let type = LibraryCSV.normalized(field(.type))
        let unit = field(.unit)
        let note = field(.note)
        let location = field(.location)

        return DraftLogEntry(
            importID: UUID(uuidString: field(.id)),
            foodID: UUID(uuidString: field(.foodID)),
            typeRawValue: EntryType(rawValue: type)?.rawValue
                ?? (isComponent
                    ? EntryType.ingredient.rawValue : EntryType.food.rawValue),
            name: field(.name),
            source: field(.source),
            category: field(.category),
            foodGroup: field(.foodGroup),
            timestamp: timestamp(field) ?? Date(),
            location: location.isEmpty ? nil : location,
            quantity: Double(field(.quantity)) ?? 1,
            unit: unit.isEmpty ? "serving" : unit,
            calories: LibraryCSV.macro(field(.calories)) ?? 0,
            protein: LibraryCSV.macro(field(.protein)) ?? 0,
            carbs: LibraryCSV.macro(field(.carbs)) ?? 0,
            fat: LibraryCSV.macro(field(.fat)) ?? 0,
            fiber: LibraryCSV.macro(field(.fiber)) ?? 0,
            isManualOverride: LibraryCSV.bool(field(.isManualOverride)),
            note: note.isEmpty ? nil : note,
            displayOrder: Int(field(.order)) ?? 0
        )
    }
}
