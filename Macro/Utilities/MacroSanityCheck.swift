//
//  MacroSanityCheck.swift
//  Macro
//

import Foundation

enum MacroSanityCheck {
    enum Scope {
        case full
        case sizeOnly
    }

    struct Values: Equatable {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var fiber: Double
        var weight: Double?
        var weightUnit: String

        init(
            calories: Double,
            protein: Double,
            carbs: Double,
            fat: Double,
            fiber: Double = 0,
            weight: Double? = nil,
            weightUnit: String = "g"
        ) {
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            self.weight = weight
            self.weightUnit = weightUnit
        }

        init(
            calories: String,
            protein: String,
            carbs: String,
            fat: String,
            fiber: String = "",
            weight: Double? = nil,
            weightUnit: String = "g"
        ) {
            self.init(
                calories: Self.number(calories),
                protein: Self.number(protein),
                carbs: Self.number(carbs),
                fat: Self.number(fat),
                fiber: Self.number(fiber),
                weight: weight,
                weightUnit: weightUnit
            )
        }

        var weightInGrams: Double? {
            guard let weight,
                let gramsPerUnit = MacroSanityCheck.gramsPerUnit[
                    weightUnit.trimmingCharacters(in: .whitespaces).lowercased()
                ]
            else { return nil }
            return weight * gramsPerUnit
        }

        init(_ food: FoodItem, multiplier: Double) {
            self.init(
                calories: food.calories * multiplier,
                protein: food.protein * multiplier,
                carbs: food.carbs * multiplier,
                fat: food.fat * multiplier
            )
        }

        init(_ entry: LoggedEntry) {
            self.init(
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat
            )
        }

        func hasSameMacros(as other: Values?) -> Bool {
            guard let other else { return false }
            return [
                (calories, other.calories), (protein, other.protein),
                (carbs, other.carbs), (fat, other.fat),
            ].allSatisfy { abs($0 - $1) < 0.5 }
        }

        private static func number(_ text: String) -> Double {
            Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
    }

    private static let gramsPerUnit: [String: Double] = [
        "g": 1, "kg": 1000, "mg": 0.001, "oz": 28.349523125, "lb": 453.59237, "lbs": 453.59237,
    ]

    static let maxCalories: Double = 5000
    static let maxMacroGrams: Double = 500

    static func issue(for values: Values, scope: Scope = .full, alcoholCalories: Double? = nil) -> String? {
        if let issue = sizeIssue(for: values) { return issue }
        guard scope == .full else { return nil }

        if let issue = alcoholIssue(calories: values.calories, alcoholCalories: alcoholCalories) {
            return issue
        }

        if let weight = values.weightInGrams, weight > 0 {
            let weightLabel = weightText(values)
            let macroGrams = values.protein + values.carbs + values.fat
            if macroGrams > weight + max(1, weight * 0.05) {
                return String(
                    localized:
                        "Protein, carbs and fat add up to \(grams(macroGrams)), more than the \(weightLabel) serving weight."
                )
            }

            if values.calories > weight * 9.5 && values.calories - weight * 9 > 10 {
                return String(
                    localized:
                        "\(kcal(values.calories)) in \(weightLabel) is more than pure fat, the densest food at 9 kcal per gram."
                )
            }
        }

        guard values.protein + values.carbs + values.fat > 0 else { return nil }

        let fiber = min(max(values.fiber, 0), values.carbs)
        let expected =
            4 * values.protein + 4 * (values.carbs - fiber) + 2 * fiber + 9 * values.fat
        let shortfall = expected - values.calories
        let excess = values.calories - expected

        if shortfall > max(30, expected * 0.3) {
            guard values.calories > 0 else {
                return String(
                    localized:
                        "Protein, carbs and fat add up to about \(kcal(expected)), but calories are \(kcal(values.calories))."
                )
            }
            return String(
                localized:
                    "Protein, carbs and fat add up to about \(kcal(expected)), but calories are \(kcal(values.calories)). This can be normal for sugar-free foods with sugar alcohols."
            )
        }

        if excess >= 250 && values.calories > expected * 2.5 {
            return String(
                localized:
                    "Calories (\(kcal(values.calories))) are much higher than protein, carbs and fat add up to (about \(kcal(expected))). This can be normal for alcohol, or the label may be in kJ."
            )
        }

        return nil
    }

    static func alcoholIssue(calories: Double, alcoholCalories: Double?) -> String? {
        guard let alcoholCalories, alcoholCalories >= 10,
            calories < alcoholCalories - max(5, alcoholCalories * 0.05)
        else { return nil }
        return String(
            localized:
                "Calories (\(kcal(calories))) are lower than the alcohol alone (\(kcal(alcoholCalories)))."
        )
    }

    private static func sizeIssue(for values: Values) -> String? {
        if values.calories > maxCalories {
            return String(localized: "\(kcal(values.calories)) is unusually high.")
        }

        let macros: [(String, Double)] = [
            (String(localized: "Protein"), values.protein),
            (String(localized: "Carbs"), values.carbs),
            (String(localized: "Fat"), values.fat),
        ]
        if let (name, value) = macros.first(where: { $0.1 > maxMacroGrams }) {
            return String(localized: "\(name) (\(grams(value))) is unusually high.")
        }

        return nil
    }

    private static func kcal(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) kcal"
    }

    private static func weightText(_ values: Values) -> String {
        guard let weight = values.weight else { return "" }
        let unit = values.weightUnit.trimmingCharacters(in: .whitespaces)
        return "\(weight.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    private static func grams(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}
