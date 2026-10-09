//
//  MacroBackup.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

nonisolated struct MacroBackup: Codable, Sendable {
    static let formatIdentifier = "com.macro.backup"
    static let currentVersion = 1

    var format: String = formatIdentifier
    var version: Int = currentVersion
    var createdAt: Date
    var appVersion: String?

    var user: UserRecord?
    var goals: [GoalRecord]
    var sources: [ListRecord]
    var categories: [ListRecord]
    var foodGroups: [ListRecord]
    var servingUnits: [UnitRecord]
    var foods: [FoodRecord]
    var favorites: [FavoriteRecord]
    var logs: [LogRecord]
    var drafts: [DraftRecord]

    struct UserRecord: Codable, Sendable {
        var name: String?
        var onboardingComplete: Bool
        var dayStartMinutes: Int
    }

    struct GoalRecord: Codable, Sendable {
        var id: UUID
        var date: Date
        var calories: Double
        var calorieMode: String
        var protein: Double
        var proteinMode: String
        var carbs: Double
        var carbsMode: String
        var fat: Double
        var fatMode: String
        var fiber: Double
        var fiberMode: String
    }

    struct ListRecord: Codable, Sendable {
        var name: String
        var isDefault: Bool
        var displayOrder: Int
        var isHidden: Bool?
    }

    struct UnitRecord: Codable, Sendable {
        var unit: String
        var pluralVariant: String?
        var isDefault: Bool
        var displayOrder: Int
    }

    struct NoteRecord: Codable, Sendable {
        var text: String
        var lastUpdated: Date
    }

    struct IngredientRecord: Codable, Sendable {
        var id: UUID
        var ingredientItemID: UUID?
        var quantity: Double
        var unit: String
        var displayOrder: Int
        var name: String
        var baseServingSize: Double
        var baseServingUnitName: String?
        var baseServingWeight: Double?
        var baseServingWeightUnit: String
        var baseCalories: Double
        var baseProtein: Double
        var baseCarbs: Double
        var baseFat: Double
        var baseFiber: Double
    }

    struct FoodRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var type: String
        var source: String?
        var category: String?
        var foodGroup: String?
        var servingUnit: String?
        var servingSize: Double
        var servingWeight: Double?
        var servingWeightUnit: String
        var isAIEstimated: Bool
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var isCustomDefaultServing: Bool
        var customServingSize: Double?
        var dateAdded: Date
        var note: NoteRecord?
        var ingredients: [IngredientRecord]
    }

    struct FavoriteRecord: Codable, Sendable {
        var foodID: UUID
        var orderIndex: Int
    }

    struct PhotoRecord: Codable, Sendable {
        var imageData: Data
        var scale: Double
        var offsetX: Double
        var offsetY: Double
        var displayOrder: Int
    }

    struct LogRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var typeRawValue: String
        var originalFoodID: UUID?
        var source: String?
        var category: String?
        var foodGroup: String?
        var timestamp: Date
        var location: String?
        var loggedQuantity: Double
        var loggedUnit: String
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var isManualOverride: Bool
        var logNote: String?
        var displayOrder: Int
        var photos: [PhotoRecord]
        var children: [LogRecord]
    }

    struct DraftRecord: Codable, Sendable {
        var id: UUID
        var kindRawValue: String
        var typeRawValue: String
        var name: String
        var timestamp: Date?
        var createdAt: Date
        var updatedAt: Date
        var foodItemID: UUID?
        var payload: Data
        var photos: [PhotoRecord]
    }

    var photoCount: Int {
        func count(_ logs: [LogRecord]) -> Int {
            logs.reduce(0) { $0 + $1.photos.count + count($1.children) }
        }
        return count(logs) + drafts.reduce(0) { $0 + $1.photos.count }
    }

    var recipeCount: Int {
        foods.filter { $0.type == EntryType.recipe.rawValue }.count
    }

    var customListCount: Int {
        (sources + categories + foodGroups).filter { !$0.isDefault }.count
            + servingUnits.filter { !$0.isDefault }.count
    }

    static func encode(_ backup: MacroBackup) throws -> Data {
        try JSONEncoder().encode(backup)
    }

    static func decode(_ data: Data) throws -> MacroBackup {
        try JSONDecoder().decode(MacroBackup.self, from: data)
    }
}

extension MacroBackup {
    @MainActor
    static func make(from context: ModelContext) throws -> MacroBackup {
        let user = try context.fetch(FetchDescriptor<User>()).first
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let logs = try context.fetch(FetchDescriptor<LoggedEntry>())
        let drafts = try context.fetch(FetchDescriptor<EntryDraft>())
        let favorites = try context.fetch(FetchDescriptor<FavoriteEntry>())

        return MacroBackup(
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                as? String,
            user: user.map {
                UserRecord(
                    name: $0.name,
                    onboardingComplete: $0.onboardingComplete,
                    dayStartMinutes: $0.dayStartMinutes
                )
            },
            goals: (user?.goalsHistory ?? [])
                .sorted { $0.date < $1.date }
                .map(goalRecord),
            sources: try context.fetch(FetchDescriptor<EntrySource>())
                .map { ListRecord(name: $0.source, isDefault: $0.isDefault, displayOrder: $0.displayOrder, isHidden: $0.isHidden) },
            categories: try context.fetch(FetchDescriptor<CategorySource>())
                .map { ListRecord(name: $0.category, isDefault: $0.isDefault, displayOrder: $0.displayOrder, isHidden: $0.isHidden) },
            foodGroups: try context.fetch(FetchDescriptor<FoodGroupSource>())
                .map { ListRecord(name: $0.foodGroup, isDefault: $0.isDefault, displayOrder: $0.displayOrder, isHidden: $0.isHidden) },
            servingUnits: try context.fetch(FetchDescriptor<ServingSizeUnit>())
                .map {
                    UnitRecord(
                        unit: $0.unit,
                        pluralVariant: $0.pluralVariant,
                        isDefault: $0.isDefault,
                        displayOrder: $0.displayOrder
                    )
                },
            foods: foods.sorted { $0.dateAdded < $1.dateAdded }.map(foodRecord),
            favorites: favorites.compactMap { favorite in
                favorite.foodItem.map {
                    FavoriteRecord(foodID: $0.id, orderIndex: favorite.orderIndex)
                }
            },
            logs: logs
                .filter { $0.parentEntry == nil }
                .sorted { $0.timestamp < $1.timestamp }
                .map(logRecord),
            drafts: drafts.map(draftRecord)
        )
    }

    @MainActor
    private static func goalRecord(_ goal: UserGoals) -> GoalRecord {
        GoalRecord(
            id: goal.id,
            date: goal.date,
            calories: goal.calories,
            calorieMode: goal.calorieMode.rawValue,
            protein: goal.protein,
            proteinMode: goal.proteinMode.rawValue,
            carbs: goal.carbs,
            carbsMode: goal.carbsMode.rawValue,
            fat: goal.fat,
            fatMode: goal.fatMode.rawValue,
            fiber: goal.fiber,
            fiberMode: goal.fiberMode.rawValue
        )
    }

    @MainActor
    static func foodRecord(_ food: FoodItem) -> FoodRecord {
        FoodRecord(
            id: food.id,
            name: food.name,
            type: food.type.rawValue,
            source: food.source?.source,
            category: food.category?.category,
            foodGroup: food.foodGroup?.foodGroup,
            servingUnit: food.servingUnit?.unit,
            servingSize: food.servingSize,
            servingWeight: food.servingWeight,
            servingWeightUnit: food.servingWeightUnit,
            isAIEstimated: food.isAIEstimated,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber,
            isCustomDefaultServing: food.isCustomDefaultServing,
            customServingSize: food.customServingSize,
            dateAdded: food.dateAdded,
            note: food.stickyNote.map {
                NoteRecord(text: $0.text, lastUpdated: $0.lastUpdated)
            },
            ingredients: (food.recipeIngredients ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map {
                    IngredientRecord(
                        id: $0.id,
                        ingredientItemID: $0.ingredientItem?.id,
                        quantity: $0.quantity,
                        unit: $0.unit,
                        displayOrder: $0.displayOrder,
                        name: $0.name,
                        baseServingSize: $0.baseServingSize,
                        baseServingUnitName: $0.baseServingUnitName,
                        baseServingWeight: $0.baseServingWeight,
                        baseServingWeightUnit: $0.baseServingWeightUnit,
                        baseCalories: $0.baseCalories,
                        baseProtein: $0.baseProtein,
                        baseCarbs: $0.baseCarbs,
                        baseFat: $0.baseFat,
                        baseFiber: $0.baseFiber
                    )
                }
        )
    }

    @MainActor
    private static func photoRecords(_ photos: [EntryPhoto]?) -> [PhotoRecord] {
        (photos ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map {
                PhotoRecord(
                    imageData: $0.imageData,
                    scale: $0.scale,
                    offsetX: $0.offsetX,
                    offsetY: $0.offsetY,
                    displayOrder: $0.displayOrder
                )
            }
    }

    @MainActor
    static func logRecord(_ log: LoggedEntry) -> LogRecord {
        LogRecord(
            id: log.id,
            name: log.name,
            typeRawValue: log.typeRawValue,
            originalFoodID: log.originalFoodItem?.id,
            source: log.source?.source,
            category: log.category?.category,
            foodGroup: log.foodGroup?.foodGroup,
            timestamp: log.timestamp,
            location: log.location,
            loggedQuantity: log.loggedQuantity,
            loggedUnit: log.loggedUnit,
            calories: log.calories,
            protein: log.protein,
            carbs: log.carbs,
            fat: log.fat,
            fiber: log.fiber,
            isManualOverride: log.isManualOverride,
            logNote: log.logNote,
            displayOrder: log.displayOrder,
            photos: photoRecords(log.photos),
            children: (log.childEntries ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(logRecord)
        )
    }

    @MainActor
    static func draftRecord(_ draft: EntryDraft) -> DraftRecord {
        DraftRecord(
            id: draft.id,
            kindRawValue: draft.kindRawValue,
            typeRawValue: draft.typeRawValue,
            name: draft.name,
            timestamp: draft.timestamp,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt,
            foodItemID: draft.foodItem?.id,
            payload: draft.payload,
            photos: photoRecords(draft.photos)
        )
    }
}
