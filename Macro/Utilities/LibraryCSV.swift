//
//  LibraryCSV.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum LibraryCSV {
    enum Column: String, CSVColumn {
        case record = "Record"
        case id = "ID"
        case recipeID = "Recipe ID"
        case ingredientID = "Ingredient ID"
        case type = "Type"
        case name = "Name"
        case source = "Source"
        case category = "Category"
        case foodGroup = "Food Group"
        case servingSize = "Serving Size"
        case servingUnit = "Serving Unit"
        case servingUnitPlural = "Serving Unit Plural"
        case servingWeight = "Serving Weight"
        case servingWeightUnit = "Serving Weight Unit"
        case calories = "Calories"
        case protein = "Protein"
        case carbs = "Carbs"
        case fat = "Fat"
        case fiber = "Fiber"
        case quantity = "Quantity"
        case quantityUnit = "Quantity Unit"
        case isAIEstimated = "AI Estimated"
        case isCustomDefaultServing = "Custom Default Serving"
        case customServingSize = "Custom Serving Size"
        case favoriteOrder = "Favorite Order"
        case note = "Note"
        case noteUpdated = "Note Updated"
        case dateAdded = "Date Added"

        var aliases: [String] {
            switch self {
            case .record: return ["row type", "kind"]
            case .name: return ["meal", "food"]
            case .calories: return ["calorie", "kcal", "energy"]
            case .carbs: return ["carb", "carbohydrate", "carbohydrates"]
            case .fat: return ["fats", "total fat"]
            case .fiber: return ["fibre"]
            case .protein: return ["proteins"]
            case .servingUnit: return ["unit"]
            case .note: return ["notes", "sticky note"]
            default: return []
            }
        }

        var aliasRequiresText: Bool { self == .name }
    }

    enum Record: String {
        case entry = "Entry"
        case ingredient = "Ingredient"
    }

    struct ParseResult {
        var items: [DraftFoodItem] = []
        var issues: [ImportIssue] = []

        var duplicateCount: Int {
            issues.filter { $0.kind != .invalid }.count
        }

        var invalidCount: Int {
            issues.filter { $0.kind == .invalid }.count
        }

        mutating func skip(
            _ row: Int,
            _ kind: ImportIssue.Kind = .invalid,
            name: String?,
            reason: String
        ) {
            issues.append(
                ImportIssue(
                    kind: kind,
                    row: row,
                    name: name?.isEmpty == true ? nil : name,
                    reason: reason
                )
            )
        }
    }

    private static let dateStyle = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true
    )

    static func lookupKey(source: String, name: String) -> String {
        "\(normalized(source))-\(normalized(name))"
    }

    static func normalized(_ string: String) -> String {
        string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func export(_ items: [FoodItem]) -> String {
        var rows = [Column.allCases.map(\.rawValue)]

        for item in items.sorted(by: { $0.dateAdded < $1.dateAdded }) {
            rows.append(row(entryFields(for: item)))

            let ingredients = (item.recipeIngredients ?? []).sorted {
                $0.displayOrder < $1.displayOrder
            }
            for ingredient in ingredients {
                rows.append(row(ingredientFields(for: ingredient, in: item)))
            }
        }

        return "\u{FEFF}" + CSVCoder.encode(rows)
    }

    static let simplifiedHeader = [
        "Source", "Name", "Calories", "Protein", "Carbohydrates", "Fat", "Fiber",
        "Type", "Category", "Food Group", "Note",
    ]

    static func exportSimplified(_ items: [FoodItem]) -> String {
        var rows = [simplifiedHeader]

        for item in items.sorted(by: { $0.dateAdded < $1.dateAdded }) {
            rows.append([
                item.source?.source ?? "",
                item.name,
                format(item.calories),
                format(item.protein),
                format(item.carbs),
                format(item.fat),
                format(item.fiber),
                item.type.rawValue,
                item.category?.category ?? "",
                item.foodGroup?.foodGroup ?? "",
                item.stickyNote?.text ?? "",
            ])
        }

        return "\u{FEFF}" + CSVCoder.encode(rows)
    }

    private static func row(_ values: [Column: String]) -> [String] {
        Column.allCases.map { values[$0] ?? "" }
    }

    private static func entryFields(for item: FoodItem) -> [Column: String] {
        [
            .record: Record.entry.rawValue,
            .id: item.id.uuidString,
            .type: item.type.rawValue,
            .name: item.name,
            .source: item.source?.source ?? "",
            .category: item.category?.category ?? "",
            .foodGroup: item.foodGroup?.foodGroup ?? "",
            .servingSize: format(item.servingSize),
            .servingUnit: item.servingUnit?.unit ?? "",
            .servingUnitPlural: item.servingUnit?.pluralVariant ?? "",
            .servingWeight: format(item.servingWeight),
            .servingWeightUnit: item.servingWeightUnit,
            .calories: format(item.calories),
            .protein: format(item.protein),
            .carbs: format(item.carbs),
            .fat: format(item.fat),
            .fiber: format(item.fiber),
            .isAIEstimated: format(item.isAIEstimated),
            .isCustomDefaultServing: format(item.isCustomDefaultServing),
            .customServingSize: format(item.customServingSize),
            .favoriteOrder: item.favoriteEntry.map { String($0.orderIndex) }
                ?? "",
            .note: item.stickyNote?.text ?? "",
            .noteUpdated: format(item.stickyNote?.lastUpdated),
            .dateAdded: format(item.dateAdded),
        ]
    }

    private static func ingredientFields(
        for ingredient: RecipeIngredient,
        in recipe: FoodItem
    ) -> [Column: String] {
        [
            .record: Record.ingredient.rawValue,
            .recipeID: recipe.id.uuidString,
            .ingredientID: ingredient.ingredientItem?.id.uuidString ?? "",
            .type: ingredient.ingredientItem?.type.rawValue ?? "",
            .name: ingredient.name,
            .source: ingredient.ingredientItem?.source?.source ?? "",
            .servingSize: format(ingredient.baseServingSize),
            .servingUnit: ingredient.baseServingUnitName ?? "",
            .servingWeight: format(ingredient.baseServingWeight),
            .servingWeightUnit: ingredient.baseServingWeightUnit,
            .calories: format(ingredient.baseCalories),
            .protein: format(ingredient.baseProtein),
            .carbs: format(ingredient.baseCarbs),
            .fat: format(ingredient.baseFat),
            .fiber: format(ingredient.baseFiber),
            .quantity: format(ingredient.quantity),
            .quantityUnit: ingredient.unit,
        ]
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }

    static func format(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    static func format(_ date: Date?) -> String {
        guard let date else { return "" }
        return dateStyle.format(date)
    }

    static let requiredColumns: [Column] = [.name, .calories]

    static let optionalColumns: [Column] = [
        .protein, .carbs, .fat, .fiber, .source, .category, .foodGroup,
        .servingSize, .servingUnit, .servingWeight, .note,
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

    static func looksLikeLibrary(header: [String]) -> Bool {
        guard let columns = columns(forHeader: header) else {
            return header.count >= 7 && Double(header[2]) != nil
        }
        let libraryOnly: [Column] = [
            .recipeID, .ingredientID, .servingSize, .servingUnitPlural,
            .servingWeight, .customServingSize, .favoriteOrder, .dateAdded,
        ]
        let isSimplifiedHeader =
            header.count >= 7
            && normalized(header[0]) == "source"
            && normalized(header[1]) == "name"
        return isSimplifiedHeader || libraryOnly.contains { columns[$0] != nil }
    }

    static func parse(
        rows: [CSVRow],
        columns: [Column: Int],
        existingIDs: Set<UUID>,
        existingKeys: [String: UUID]
    ) -> ParseResult {
        var result = ParseResult()

        var seenIDs = Set<UUID>()
        var seenKeys = Set<String>()
        var indexByID: [UUID: Int] = [:]
        var skippedIDs = Set<UUID>()
        var claimedExistingIDs = Set<UUID>()
        var blankMacroIndices = Set<Int>()

        var lastEntryIndex: Int?
        var lastEntryWasSkipped = false
        var lastSkippedID: UUID?
        var deferredIngredients:
            [(row: Int, recipeID: UUID, ingredient: DraftImportIngredient)] = []

        for row in rows {
            let field: (Column) -> String = { column in
                guard let index = columns[column], index < row.fields.count
                else {
                    return ""
                }
                return row.fields[index].trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            let rowName = field(.name)

            let isIngredientRow =
                normalized(field(.record)) == normalized(Record.ingredient.rawValue)

            if isIngredientRow {
                let recipeID = UUID(uuidString: field(.recipeID))

                if let recipeID, skippedIDs.contains(recipeID) { continue }
                if lastEntryWasSkipped
                    && (recipeID == nil || recipeID == lastSkippedID)
                {
                    continue
                }

                if let reason = invalidReason(field, isIngredient: true) {
                    result.skip(row.number, name: rowName, reason: reason)
                    continue
                }
                guard let ingredient = makeIngredient(field) else {
                    result.skip(
                        row.number,
                        name: rowName,
                        reason: "Ingredient quantity isn't a valid number."
                    )
                    continue
                }

                if let recipeID {
                    deferredIngredients.append((row.number, recipeID, ingredient))
                } else if let lastEntryIndex {
                    result.items[lastEntryIndex].ingredients.append(ingredient)
                } else {
                    result.skip(
                        row.number,
                        name: rowName,
                        reason: "Ingredient row has no recipe above it."
                    )
                }
                continue
            }

            lastEntryIndex = nil
            lastEntryWasSkipped = false
            lastSkippedID = nil

            if let reason = invalidReason(field, isIngredient: false) {
                result.skip(row.number, name: rowName, reason: reason)
                lastEntryWasSkipped = true
                if let id = UUID(uuidString: field(.id)) {
                    lastSkippedID = id
                    skippedIDs.insert(id)
                }
                continue
            }
            guard
                var draft = makeEntry(
                    field,
                    hasPluralColumn: columns[.servingUnitPlural] != nil
                )
            else { continue }

            let key = lookupKey(source: draft.source, name: draft.name)
            let isRepeatedInFile =
                if let id = draft.importID {
                    seenIDs.contains(id)
                } else {
                    seenKeys.contains(key)
                }

            if isRepeatedInFile {
                result.skip(
                    row.number,
                    .repeated,
                    name: rowName,
                    reason: "Appears earlier in this file."
                )
                lastEntryWasSkipped = true
                lastSkippedID = draft.importID
                continue
            }

            if let id = draft.importID, existingIDs.contains(id) {
                draft.duplicateOf = id
            } else if let match = existingKeys[key],
                !claimedExistingIDs.contains(match)
            {
                draft.duplicateOf = match
            }
            if let match = draft.duplicateOf {
                claimedExistingIDs.insert(match)
            }

            if draft.duplicateOf != nil {
                result.skip(
                    row.number,
                    .duplicate,
                    name: rowName,
                    reason: "Already in your library."
                )
            }

            if let id = draft.importID {
                seenIDs.insert(id)
                indexByID[id] = result.items.count
            } else {
                seenKeys.insert(key)
            }

            let macroColumns: [Column] = [.calories, .protein, .carbs, .fat, .fiber]
            if macroColumns.allSatisfy({ field($0).isEmpty }) {
                blankMacroIndices.insert(result.items.count)
            }

            lastEntryIndex = result.items.count
            result.items.append(draft)
        }

        for (rowNumber, recipeID, ingredient) in deferredIngredients {
            if skippedIDs.contains(recipeID) { continue }
            guard let index = indexByID[recipeID] else {
                result.skip(
                    rowNumber,
                    name: ingredient.name,
                    reason: "Its Recipe ID doesn't match any recipe in this file."
                )
                continue
            }
            result.items[index].ingredients.append(ingredient)
        }

        for index in result.items.indices
        where !result.items[index].ingredients.isEmpty {
            if result.items[index].type == .food {
                result.items[index].type = .recipe
            }
            if blankMacroIndices.contains(index) {
                applyIngredientTotals(to: &result.items[index])
            }
        }

        return result
    }

    static func parseSimplified(
        rows: [CSVRow],
        existingKeys: [String: UUID]
    ) -> ParseResult {
        var result = ParseResult()
        var seenInCSV = Set<String>()
        var claimedExistingIDs = Set<UUID>()
        let macroNames = ["Calories", "Protein", "Carbohydrates", "Fat", "Fiber"]

        for (index, row) in rows.enumerated() {
            let columns = row.fields.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard columns.count >= 7 else {
                result.skip(
                    row.number,
                    name: nil,
                    reason: "Expected 7 columns but found \(columns.count)."
                )
                continue
            }

            let source = columns[0]
            let name = columns[1]

            if index == 0 && Double(columns[2]) == nil {
                continue
            }

            if name.isEmpty {
                result.skip(row.number, name: nil, reason: "Entry is missing a name.")
                continue
            }

            let macros = (2...6).map { macro(columns[$0]) }
            if let badIndex = macros.firstIndex(where: { $0 == nil }) {
                result.skip(
                    row.number,
                    name: name,
                    reason:
                        "\"\(columns[badIndex + 2])\" isn't a valid number for \(macroNames[badIndex])."
                )
                continue
            }

            let key = lookupKey(source: source, name: name)
            if seenInCSV.contains(key) {
                result.skip(
                    row.number,
                    .repeated,
                    name: name,
                    reason: "Appears earlier in this file."
                )
                continue
            }
            seenInCSV.insert(key)

            var draft = DraftFoodItem(
                name: name,
                source: source,
                category: "",
                foodGroup: "",
                servingSize: 1.0,
                servingUnit: "serving",
                servingWeight: nil,
                servingWeightUnit: "g",
                isAIEstimated: false,
                calories: macros[0] ?? 0,
                protein: macros[1] ?? 0,
                carbs: macros[2] ?? 0,
                fat: macros[3] ?? 0,
                fiber: macros[4] ?? 0,
                isCustomDefaultServing: false,
                customServingSize: nil
            )

            if let match = existingKeys[key], !claimedExistingIDs.contains(match) {
                claimedExistingIDs.insert(match)
                draft.duplicateOf = match
                result.skip(
                    row.number,
                    .duplicate,
                    name: name,
                    reason: "Already in your library."
                )
            }

            result.items.append(draft)
        }

        return result
    }

    private static func invalidReason(
        _ field: (Column) -> String,
        isIngredient: Bool
    ) -> String? {
        if field(.name).isEmpty {
            return isIngredient
                ? "Ingredient is missing a name." : "Entry is missing a name."
        }

        let numericColumns: [Column] = [.calories, .protein, .carbs, .fat, .fiber]
        for column in numericColumns where macro(field(column)) == nil {
            return "\"\(field(column))\" isn't a valid number for \(column.rawValue)."
        }

        return nil
    }

    private static func makeEntry(
        _ field: (Column) -> String,
        hasPluralColumn: Bool
    ) -> DraftFoodItem? {
        let name = field(.name)
        guard !name.isEmpty,
            let calories = macro(field(.calories)),
            let protein = macro(field(.protein)),
            let carbs = macro(field(.carbs)),
            let fat = macro(field(.fat)),
            let fiber = macro(field(.fiber))
        else { return nil }

        let servingUnit = field(.servingUnit)
        let servingWeightUnit = field(.servingWeightUnit)
        let note = field(.note)
        let favorite = field(.favoriteOrder)
        let favoriteOrder = Int(favorite) ?? (bool(favorite) ? Int.max : nil)

        return DraftFoodItem(
            type: EntryType(rawValue: normalized(field(.type))) ?? .food,
            name: name,
            source: field(.source),
            category: field(.category),
            foodGroup: field(.foodGroup),
            servingSize: positive(field(.servingSize)) ?? 1.0,
            servingUnit: servingUnit.isEmpty ? "serving" : servingUnit,
            servingWeight: positive(field(.servingWeight)),
            servingWeightUnit: servingWeightUnit.isEmpty ? "g" : servingWeightUnit,
            isAIEstimated: bool(field(.isAIEstimated)),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            isCustomDefaultServing: bool(field(.isCustomDefaultServing)),
            customServingSize: positive(field(.customServingSize)),
            stickyNote: note.isEmpty ? nil : note,
            isFavorite: favoriteOrder != nil,
            favoriteOrder: favoriteOrder,
            importID: UUID(uuidString: field(.id)),
            servingUnitPlural: hasPluralColumn
                ? field(.servingUnitPlural) : nil,
            noteUpdated: date(field(.noteUpdated)),
            dateAdded: date(field(.dateAdded))
        )
    }

    private static func makeIngredient(
        _ field: (Column) -> String
    ) -> DraftImportIngredient? {
        let name = field(.name)
        guard !name.isEmpty,
            let calories = macro(field(.calories)),
            let protein = macro(field(.protein)),
            let carbs = macro(field(.carbs)),
            let fat = macro(field(.fat)),
            let fiber = macro(field(.fiber))
        else { return nil }

        let baseServingSize = positive(field(.servingSize)) ?? 1.0
        let baseServingUnit = field(.servingUnit)
        let servingWeightUnit = field(.servingWeightUnit)
        let quantityUnit = field(.quantityUnit)

        let quantity: Double
        if field(.quantity).isEmpty {
            quantity = baseServingSize
        } else if let parsed = Double(field(.quantity)), parsed >= 0 {
            quantity = parsed
        } else {
            return nil
        }

        return DraftImportIngredient(
            linkedItemID: UUID(uuidString: field(.ingredientID)),
            linkedItemType: EntryType(rawValue: normalized(field(.type))),
            linkedItemSource: field(.source),
            name: name,
            quantity: quantity,
            unit: quantityUnit.isEmpty
                ? (baseServingUnit.isEmpty ? "serving" : baseServingUnit)
                : quantityUnit,
            baseServingSize: baseServingSize,
            baseServingUnitName: baseServingUnit.isEmpty ? nil : baseServingUnit,
            baseServingWeight: positive(field(.servingWeight)),
            baseServingWeightUnit: servingWeightUnit.isEmpty
                ? "g" : servingWeightUnit,
            baseCalories: calories,
            baseProtein: protein,
            baseCarbs: carbs,
            baseFat: fat,
            baseFiber: fiber
        )
    }

    private static func applyIngredientTotals(to item: inout DraftFoodItem) {
        item.calories = item.ingredients.reduce(0) { $0 + $1.baseCalories * $1.multiplier }
        item.protein = item.ingredients.reduce(0) { $0 + $1.baseProtein * $1.multiplier }
        item.carbs = item.ingredients.reduce(0) { $0 + $1.baseCarbs * $1.multiplier }
        item.fat = item.ingredients.reduce(0) { $0 + $1.baseFat * $1.multiplier }
        item.fiber = item.ingredients.reduce(0) { $0 + $1.baseFiber * $1.multiplier }
    }

    static func macro(_ string: String) -> Double? {
        string.isEmpty ? 0.0 : Double(string)
    }

    static func positive(_ string: String) -> Double? {
        guard let value = Double(string), value > 0 else { return nil }
        return value
    }

    static func bool(_ string: String) -> Bool {
        ["yes", "y", "true", "1"].contains(normalized(string))
    }

    private static let localDateFormatters: [DateFormatter] = [
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd", "M/d/yyyy H:mm", "M/d/yyyy h:mm a",
        "M/d/yyyy",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    static func date(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        if let date = (try? dateStyle.parse(string))
            ?? (try? Date.ISO8601FormatStyle().parse(string))
        {
            return date
        }
        return localDateFormatters.lazy.compactMap { $0.date(from: string) }
            .first
    }

    private static let timeFormatters: [DateFormatter] = [
        "HH:mm:ss", "HH:mm", "h:mm:ss a", "h:mm a", "h:mma", "h a", "ha",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    static func time(_ string: String) -> DateComponents? {
        guard !string.isEmpty,
            let time = timeFormatters.lazy.compactMap({
                $0.date(from: string.uppercased())
            }).first
        else { return nil }
        return Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: time
        )
    }

    static func date(_ dateString: String, time timeString: String) -> Date? {
        guard let date = date(dateString) else { return nil }
        guard !timeString.isEmpty else { return date }
        guard let time = time(timeString) else { return nil }

        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: calendar.startOfDay(for: date)
        )
    }
}

struct ExportDocument: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            document.data
        }
        DataRepresentation(exportedContentType: .json) { document in
            document.data
        }
    }
}
