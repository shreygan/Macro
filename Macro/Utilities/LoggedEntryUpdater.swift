//
//  LoggedEntryUpdater.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/6/26.
//

import Foundation
import SwiftData

struct ServingBase: Equatable {
    let size: Double
    let unit: String
    let weight: Double?
    let weightUnit: String

    init(size: Double, unit: String, weight: Double?, weightUnit: String) {
        self.size = size
        self.unit = unit
        self.weight = weight
        self.weightUnit = weightUnit
    }

    init(_ food: FoodItem) {
        self.init(
            size: food.servingSize,
            unit: food.servingUnit?.unit ?? "serving",
            weight: food.servingWeight,
            weightUnit: food.servingWeightUnit
        )
    }

    init(_ ingredient: RecipeIngredient) {
        self.init(
            size: ingredient.baseServingSize,
            unit: ingredient.baseServingUnitName ?? "serving",
            weight: ingredient.baseServingWeight,
            weightUnit: ingredient.baseServingWeightUnit
        )
    }

    func measures(_ unit: String) -> Bool {
        unit == self.unit || (unit == weightUnit && weight != nil)
    }
}

struct FoodItemSnapshot {
    struct Ingredient: Equatable {
        let itemID: UUID?
        let name: String
        let quantity: Double
        let unit: String
        let baseServingSize: Double
        let baseServingWeight: Double?
        let baseServingWeightUnit: String
        let baseCalories: Double
        let baseProtein: Double
        let baseCarbs: Double
        let baseFat: Double
        let baseFiber: Double

        init(_ ingredient: RecipeIngredient) {
            self.itemID = ingredient.ingredientItem?.id
            self.name = ingredient.name
            self.quantity = ingredient.quantity
            self.unit = ingredient.unit
            self.baseServingSize = ingredient.baseServingSize
            self.baseServingWeight = ingredient.baseServingWeight
            self.baseServingWeightUnit = ingredient.baseServingWeightUnit
            self.baseCalories = ingredient.baseCalories
            self.baseProtein = ingredient.baseProtein
            self.baseCarbs = ingredient.baseCarbs
            self.baseFat = ingredient.baseFat
            self.baseFiber = ingredient.baseFiber
        }

        var weight: Double? {
            EntryHelper.ingredientWeight(
                quantity: quantity,
                unit: unit,
                baseServingSize: baseServingSize,
                baseServingWeight: baseServingWeight,
                baseServingWeightUnit: baseServingWeightUnit
            )
        }
    }

    struct Basis: Equatable {
        let serving: ServingBase
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let ingredients: [Ingredient]

        var loggedWeight: Double? {
            if let weight = serving.weight { return weight }
            let total = ingredients.compactMap(\.weight).reduce(0, +)
            return total > 0 ? total : nil
        }
    }

    let name: String
    let type: EntryType
    let source: String?
    let category: String?
    let foodGroup: String?
    let basis: Basis

    init(_ food: FoodItem) {
        self.name = food.name
        self.type = food.type
        self.source = food.source?.source
        self.category = food.category?.category
        self.foodGroup = food.foodGroup?.foodGroup
        self.basis = Basis(
            serving: ServingBase(food),
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber,
            ingredients: (food.recipeIngredients ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(Ingredient.init)
        )
    }
}

@MainActor
enum LoggedEntryUpdater {
    static func apply(
        _ food: FoodItem,
        from previous: FoodItemSnapshot,
        recipesUpdated: Bool,
        in context: ModelContext
    ) {
        let current = FoodItemSnapshot(food).basis
        let basisChanged = previous.basis != current
        var affectedParentEntries = Set<LoggedEntry>()

        for log in FoodItemStore.loggedEntries(for: food, in: context) {
            if let parent = log.parentEntry, !recipesUpdated,
                usesIngredient(food, in: parent.originalFoodItem)
            {
                continue
            }

            updateDetails(of: log, to: food, from: previous)

            guard basisChanged, !log.isManualOverride else { continue }

            if let parent = log.parentEntry {
                rescale(log, to: food, current: current, from: previous.basis)
                affectedParentEntries.insert(parent)
            } else if food.type == .recipe {
                rebuildRecipeLog(
                    log,
                    to: food,
                    current: current,
                    from: previous.basis,
                    in: context
                )
            } else {
                rescale(log, to: food, current: current, from: previous.basis)
            }
        }

        for parent in affectedParentEntries where !parent.isManualOverride {
            let children = parent.childEntries ?? []
            parent.calories = children.reduce(0) { $0 + $1.calories }
            parent.protein = children.reduce(0) { $0 + $1.protein }
            parent.carbs = children.reduce(0) { $0 + $1.carbs }
            parent.fat = children.reduce(0) { $0 + $1.fat }
            parent.fiber = children.reduce(0) { $0 + $1.fiber }
        }
    }

    static func updateRecipeIngredients(
        using food: FoodItem,
        from previous: FoodItemSnapshot,
        in context: ModelContext
    ) {
        let newBase = ServingBase(food)
        var affectedRecipes = Set<FoodItem>()

        for ingredient in FoodItemStore.recipeIngredients(using: food, in: context) {
            ingredient.name = food.name

            let portion = updatedPortion(
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                to: newBase,
                from: ServingBase(ingredient)
            )
            guard newBase.measures(portion.unit) else { continue }

            ingredient.quantity = portion.quantity
            ingredient.unit = portion.unit
            ingredient.baseServingSize = food.servingSize
            ingredient.baseServingUnitName = food.servingUnit?.unit
            ingredient.baseServingWeight = food.servingWeight
            ingredient.baseServingWeightUnit = food.servingWeightUnit
            ingredient.baseCalories = food.calories
            ingredient.baseProtein = food.protein
            ingredient.baseCarbs = food.carbs
            ingredient.baseFat = food.fat
            ingredient.baseFiber = food.fiber

            if let recipe = ingredient.parentRecipe {
                affectedRecipes.insert(recipe)
            }
        }

        for recipe in affectedRecipes {
            var calories = 0.0
            var protein = 0.0
            var carbs = 0.0
            var fat = 0.0
            var fiber = 0.0

            for ingredient in recipe.recipeIngredients ?? [] {
                let multiplier = EntryHelper.ingredientMultiplier(
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    baseServingSize: ingredient.baseServingSize,
                    baseServingWeight: ingredient.baseServingWeight,
                    baseServingWeightUnit: ingredient.baseServingWeightUnit
                )

                calories += ingredient.baseCalories * multiplier
                protein += ingredient.baseProtein * multiplier
                carbs += ingredient.baseCarbs * multiplier
                fat += ingredient.baseFat * multiplier
                fiber += ingredient.baseFiber * multiplier
            }

            recipe.calories = calories
            recipe.protein = protein
            recipe.carbs = carbs
            recipe.fat = fat
            recipe.fiber = fiber
        }
    }

    private static func usesIngredient(
        _ food: FoodItem,
        in recipe: FoodItem?
    ) -> Bool {
        (recipe?.recipeIngredients ?? []).contains {
            $0.ingredientItem?.id == food.id
        }
    }

    private static func updateDetails(
        of log: LoggedEntry,
        to food: FoodItem,
        from previous: FoodItemSnapshot
    ) {
        if log.name == previous.name {
            log.name = food.name
        }

        guard log.parentEntry == nil else { return }

        if log.typeRawValue == previous.type.rawValue {
            log.typeRawValue = food.type.rawValue
        }
        if log.source?.source == previous.source {
            log.source = food.source
        }
        if log.category?.category == previous.category {
            log.category = food.category
        }
        if log.foodGroup?.foodGroup == previous.foodGroup {
            log.foodGroup = food.foodGroup
        }
    }

    private static func rescale(
        _ log: LoggedEntry,
        to food: FoodItem,
        current: FoodItemSnapshot.Basis,
        from previous: FoodItemSnapshot.Basis
    ) {
        guard
            let multiplier = updatePortion(
                of: log,
                current: current,
                from: previous
            )
        else { return }

        log.calories = food.calories * multiplier
        log.protein = food.protein * multiplier
        log.carbs = food.carbs * multiplier
        log.fat = food.fat * multiplier
        log.fiber = food.fiber * multiplier
    }

    private static func rebuildRecipeLog(
        _ log: LoggedEntry,
        to recipe: FoodItem,
        current: FoodItemSnapshot.Basis,
        from previous: FoodItemSnapshot.Basis,
        in context: ModelContext
    ) {
        let oldChildren = (log.childEntries ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }

        guard
            let previousMultiplier = portionMultiplier(
                quantity: log.loggedQuantity,
                unit: log.loggedUnit,
                basis: previous
            ),
            matchesRecipe(
                oldChildren,
                ingredients: previous.ingredients,
                multiplier: previousMultiplier
            ),
            let multiplier = updatePortion(
                of: log,
                current: current,
                from: previous
            )
        else { return }

        log.childEntries = []
        for child in oldChildren {
            context.delete(child)
        }

        var calories = 0.0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0

        let ingredients = (recipe.recipeIngredients ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }

        for (index, ingredient) in ingredients.enumerated() {
            let ingredientMultiplier =
                EntryHelper.ingredientMultiplier(
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    baseServingSize: ingredient.baseServingSize,
                    baseServingWeight: ingredient.baseServingWeight,
                    baseServingWeightUnit: ingredient.baseServingWeightUnit
                ) * multiplier

            let child = LoggedEntry(
                name: ingredient.name,
                typeRawValue: "ingredient",
                originalFoodItem: ingredient.ingredientItem,
                parentEntry: log,
                timestamp: log.timestamp,
                location: log.location,
                loggedQuantity: ingredient.quantity * multiplier,
                loggedUnit: ingredient.unit,
                calories: ingredient.baseCalories * ingredientMultiplier,
                protein: ingredient.baseProtein * ingredientMultiplier,
                carbs: ingredient.baseCarbs * ingredientMultiplier,
                fat: ingredient.baseFat * ingredientMultiplier,
                fiber: ingredient.baseFiber * ingredientMultiplier,
                displayOrder: index
            )
            context.insert(child)

            calories += child.calories
            protein += child.protein
            carbs += child.carbs
            fat += child.fat
            fiber += child.fiber
        }

        log.calories = calories
        log.protein = protein
        log.carbs = carbs
        log.fat = fat
        log.fiber = fiber
    }

    private static func matchesRecipe(
        _ children: [LoggedEntry],
        ingredients: [FoodItemSnapshot.Ingredient],
        multiplier: Double
    ) -> Bool {
        guard children.count == ingredients.count else { return false }

        return zip(children, ingredients).allSatisfy { child, ingredient in
            let isSameItem =
                ingredient.itemID == nil
                ? child.originalFoodItem == nil && child.name == ingredient.name
                : child.originalFoodItem?.id == ingredient.itemID
            return isSameItem
                && child.loggedUnit == ingredient.unit
                && isClose(
                    child.loggedQuantity,
                    ingredient.quantity * multiplier
                )
        }
    }

    private static func isClose(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.001 * max(1, abs(lhs), abs(rhs))
    }

    private static func portionMultiplier(
        quantity: Double,
        unit: String,
        basis: FoodItemSnapshot.Basis
    ) -> Double? {
        let weight = basis.loggedWeight
        guard unit == basis.serving.unit
            || (unit == basis.serving.weightUnit && weight != nil)
        else { return nil }

        return EntryHelper.portionMultiplier(
            quantity: quantity,
            unit: unit,
            servingSize: basis.serving.size,
            servingWeight: weight,
            servingWeightUnit: basis.serving.weightUnit
        )
    }

    private static func updatePortion(
        of log: LoggedEntry,
        current: FoodItemSnapshot.Basis,
        from previous: FoodItemSnapshot.Basis
    ) -> Double? {
        let portion = updatedPortion(
            quantity: log.loggedQuantity,
            unit: log.loggedUnit,
            to: current.serving,
            from: previous.serving
        )
        guard
            let multiplier = portionMultiplier(
                quantity: portion.quantity,
                unit: portion.unit,
                basis: current
            )
        else { return nil }

        log.loggedQuantity = portion.quantity
        log.loggedUnit = portion.unit
        return multiplier
    }

    private static func updatedPortion(
        quantity: Double,
        unit: String,
        to new: ServingBase,
        from previous: ServingBase
    ) -> (quantity: Double, unit: String) {
        if unit == previous.weightUnit,
            let previousWeight = previous.weight, previousWeight > 0
        {
            let servings = quantity / previousWeight

            guard let newWeight = new.weight, newWeight > 0 else {
                return (servings * new.size, new.unit)
            }
            guard unit != new.weightUnit else {
                return (quantity, unit)
            }
            return (servings * newWeight, new.weightUnit)
        }

        if unit == previous.unit, unit != new.unit, previous.size > 0 {
            let servings = quantity / previous.size
            return (servings * new.size, new.unit)
        }
        return (quantity, unit)
    }
}
