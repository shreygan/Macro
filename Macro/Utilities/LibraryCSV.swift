//
//  LibraryCSV.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import CoreTransferable
import Foundation
import SwiftData
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
        case hydrationPercent = "Hydration Percent"
        case caffeine = "Caffeine (mg)"
        case abv = "ABV (%)"
        case drinkNutrition = "Drink Nutrition"
        case drinkSymbol = "Drink Symbol"
        case drinkTint = "Drink Tint"
        case drinkSizes = "Drink Sizes"
        case logDrinkOrder = "Log Drink Order"
        case defaultLocation = "Default Location"
        case defaultLocationAddress = "Default Location Address"
        case defaultLocationLatitude = "Default Location Latitude"
        case defaultLocationLongitude = "Default Location Longitude"
        case defaultLocationMapID = "Default Location Map ID"
        case favoriteOrder = "Favorite Order"
        case inLibrary = "In Library"
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
            case .defaultLocation: return ["location"]
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
        let location = item.defaultLocation.map { location in
            item.modelContext.map { DefaultLocationResolver.resolved(location, in: $0) } ?? location
        }

        var fields: [Column: String] = [
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
            .defaultLocation: location?.name ?? "",
            .defaultLocationAddress: location?.address ?? "",
            .defaultLocationLatitude: location?.latitude.map { String($0) } ?? "",
            .defaultLocationLongitude: location?.longitude.map { String($0) } ?? "",
            .defaultLocationMapID: location?.mapItemID ?? "",
            .favoriteOrder: item.favoriteEntry.map { String($0.orderIndex) }
                ?? "",
            .inLibrary: format(item.isInLibrary),
            .note: item.stickyNote?.text ?? "",
            .noteUpdated: format(item.stickyNote?.lastUpdated),
            .dateAdded: format(item.dateAdded),
        ]
        if let drink = MacroBackup.drinkRecord(item) {
            fields[.hydrationPercent] = format(drink.hydrationPercent)
            fields[.caffeine] = format(drink.caffeineMg)
            fields[.abv] = format(drink.abv)
            fields[.drinkNutrition] = format(drink.hasNutrition)
            fields[.drinkSymbol] = drink.symbol ?? ""
            fields[.drinkTint] = drink.tint ?? ""
            fields[.drinkSizes] = formatSizes(drink.sizes)
            fields[.logDrinkOrder] = drink.hydrationOrder.map { String($0) } ?? ""
        }
        return fields
    }

    static func formatSizes(_ sizes: [MacroBackup.DrinkSizeRecord]) -> String {
        sizes.sorted { $0.displayOrder < $1.displayOrder }.map { size in
            var text = "\(format(size.volumeML)) ml"
            if let name = size.name, !name.isEmpty { text = "\(name): \(text)" }
            if size.isDefault { text += " (default)" }
            return text
        }
        .joined(separator: "; ")
    }

    static func parseSizes(_ string: String) -> [MacroBackup.DrinkSizeRecord] {
        var sizes: [MacroBackup.DrinkSizeRecord] = []
        var carried = ""
        for part in string.split(separator: ";") {
            let joined = carried.isEmpty ? String(part) : carried + ";" + part
            carried = ""
            var text = joined.trimmingCharacters(in: .whitespaces)
            var isDefault = false
            if normalized(text).hasSuffix("(default)") {
                isDefault = true
                text = String(text.dropLast("(default)".count)).trimmingCharacters(in: .whitespaces)
            }
            var name: String?
            if let colon = text.lastIndex(of: ":") {
                let rawName = text[..<colon].trimmingCharacters(in: .whitespaces)
                name = rawName.isEmpty ? nil : rawName
                text = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            var factor = 1.0
            let lowered = normalized(text)
            if let suffix = millilitersPerVolumeUnit.keys
                .filter({ lowered.hasSuffix($0) })
                .max(by: { $0.count < $1.count })
            {
                factor = millilitersPerVolumeUnit[suffix] ?? 1
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
            guard let volume = positive(text).map({ $0 * factor }) else {
                carried = joined
                continue
            }
            sizes.append(
                MacroBackup.DrinkSizeRecord(
                    id: UUID(),
                    name: name,
                    volumeML: volume,
                    displayOrder: sizes.count,
                    isDefault: isDefault && !sizes.contains(where: \.isDefault)
                )
            )
        }
        if !sizes.isEmpty && !sizes.contains(where: \.isDefault) {
            sizes[0].isDefault = true
        }
        return sizes
    }

    private static func drink(
        _ field: (Column) -> String,
        type: EntryType,
        macros: [Double]
    ) -> MacroBackup.DrinkRecord? {
        let drinkColumns: [Column] = [
            .hydrationPercent, .caffeine, .abv, .drinkNutrition, .drinkSymbol,
            .drinkTint, .drinkSizes, .logDrinkOrder,
        ]
        guard type == .drink || drinkColumns.contains(where: { !field($0).isEmpty }) else {
            return nil
        }
        let nutrition = field(.drinkNutrition)
        let symbol = field(.drinkSymbol)
        let tint = field(.drinkTint)
        return MacroBackup.DrinkRecord(
            hydrationPercent: Double(field(.hydrationPercent)).map { min(max($0, 0), 100) } ?? 100,
            caffeineMg: Double(field(.caffeine)).map { max($0, 0) },
            abv: Double(field(.abv)).map { min(max($0, 0), 100) },
            hasNutrition: nutrition.isEmpty ? macros.contains { $0 > 0 } : bool(nutrition),
            symbol: DrinkSymbol.contains(symbol) ? symbol : nil,
            tint: DrinkTint(rawValue: tint) == nil ? nil : tint,
            hydrationOrder: Int(field(.logDrinkOrder)),
            seedKey: nil,
            sizes: parseSizes(field(.drinkSizes))
        )
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
        .defaultLocation, .defaultLocationAddress, .defaultLocationLatitude,
        .defaultLocationLongitude,
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
        let weight = canonicalWeight(positive(field(.servingWeight)), unit: field(.servingWeightUnit))
        let note = field(.note)
        let favorite = field(.favoriteOrder)
        let favoriteOrder = Int(favorite) ?? (bool(favorite) ? Int.max : nil)
        let type = EntryType(rawValue: normalized(field(.type))) ?? .food
        let inLibrary = field(.inLibrary)

        return DraftFoodItem(
            type: type,
            name: name,
            source: field(.source),
            category: field(.category),
            foodGroup: field(.foodGroup),
            servingSize: positive(field(.servingSize)) ?? 1.0,
            servingUnit: servingUnit.isEmpty ? "serving" : servingUnit,
            servingWeight: weight.value,
            servingWeightUnit: weight.unit,
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
            dateAdded: date(field(.dateAdded)),
            defaultLocation: defaultLocation(field),
            drink: drink(field, type: type, macros: [calories, protein, carbs, fat, fiber]),
            isInLibrary: inLibrary.isEmpty ? nil : bool(inLibrary)
        )
    }

    private static func defaultLocation(_ field: (Column) -> String) -> EntryLocation? {
        let name = field(.defaultLocation)
        guard !name.isEmpty else { return nil }

        let address = field(.defaultLocationAddress)
        let mapItemID = field(.defaultLocationMapID)
        var latitude = Double(field(.defaultLocationLatitude))
        var longitude = Double(field(.defaultLocationLongitude))
        let isValidCoordinate =
            latitude.map { (-90...90).contains($0) } == true
            && longitude.map { (-180...180).contains($0) } == true
        if !isValidCoordinate {
            latitude = nil
            longitude = nil
        }

        return EntryLocation(
            name: name,
            address: address.isEmpty ? nil : address,
            latitude: latitude,
            longitude: longitude,
            mapItemID: mapItemID.isEmpty ? nil : mapItemID
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
        let weight = canonicalWeight(positive(field(.servingWeight)), unit: field(.servingWeightUnit))
        var quantityUnit = field(.quantityUnit)

        var quantity: Double
        if field(.quantity).isEmpty {
            quantity = baseServingSize
        } else if let parsed = Double(field(.quantity)), parsed >= 0 {
            quantity = parsed
        } else {
            return nil
        }

        if normalized(quantityUnit) != normalized(baseServingUnit),
            let canonical = canonicalUnit(for: quantityUnit),
            canonical.unit == weight.unit
        {
            quantity *= canonical.factor
            quantityUnit = canonical.unit
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
            baseServingWeight: weight.value,
            baseServingWeightUnit: weight.unit,
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

    static let millilitersPerVolumeUnit: [String: Double] = [
        "ml": 1, "milliliter": 1, "milliliters": 1, "millilitre": 1, "millilitres": 1,
        "l": 1000, "liter": 1000, "liters": 1000, "litre": 1000, "litres": 1000,
        "fl oz": VolumeUnit.millilitersPerFluidOunce, "fl. oz": VolumeUnit.millilitersPerFluidOunce,
        "fl.oz": VolumeUnit.millilitersPerFluidOunce, "floz": VolumeUnit.millilitersPerFluidOunce,
        "fluid ounce": VolumeUnit.millilitersPerFluidOunce, "fluid ounces": VolumeUnit.millilitersPerFluidOunce,
    ]

    static let gramsPerMassUnit: [String: Double] = [
        "g": 1, "gram": 1, "grams": 1, "kg": 1000, "kilogram": 1000, "kilograms": 1000,
        "mg": 0.001, "oz": 28.349523125, "ounce": 28.349523125, "ounces": 28.349523125,
        "lb": 453.59237, "lbs": 453.59237, "pound": 453.59237, "pounds": 453.59237,
    ]

    static func canonicalUnit(for unit: String, includesMass: Bool = true) -> (factor: Double, unit: String)? {
        let key = normalized(unit)
        if let factor = millilitersPerVolumeUnit[key] {
            return (factor, VolumeUnit.milliliters.rawValue)
        }
        if includesMass, let factor = gramsPerMassUnit[key] {
            return (factor, "g")
        }
        return nil
    }

    static func canonicalWeight(_ value: Double?, unit: String) -> (value: Double?, unit: String) {
        guard !unit.isEmpty else { return (value, "g") }
        guard let canonical = canonicalUnit(for: unit) else { return (value, unit) }
        return (value.map { $0 * canonical.factor }, canonical.unit)
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

extension Date {
    var fileNameStamp: String {
        formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }
}

struct ExportDocument: Transferable {
    var data = Data()
    var fileURL: URL?
    var fileName = ""

    init(data: Data) {
        self.data = data
    }

    init(fileURL: URL, fileName: String) {
        self.fileURL = fileURL
        self.fileName = fileName
    }

    func removeFile() {
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            document.data
        }
        FileRepresentation(exportedContentType: .macroBackup) { document in
            guard let fileURL = document.fileURL else { throw CocoaError(.fileNoSuchFile) }
            return SentTransferredFile(fileURL, allowAccessingOriginalFile: true)
        }
        .suggestedFileName { document in
            let name = document.fileName.isEmpty ? "Macro Backup" : document.fileName
            return "\(name).macrobackup"
        }
    }
}
