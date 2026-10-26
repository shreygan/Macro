//
//  DrinkAliases.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/25/26.
//

import Foundation

enum DrinkAliases {
    struct Match: Equatable {
        let key: String
        let alias: String
    }

    private static let table: [String: [String]] = [
        "cola": ["Coke", "Coca-Cola", "CocaCola", "Pepsi", "RC Cola", "Cherry Coke"],
        "dietCola": [
            "Diet Coke", "Coke Zero", "Coca-Cola Zero", "Diet Pepsi", "Pepsi Max", "Pepsi Zero",
        ],
        "energyDrink": ["Red Bull", "RedBull", "Monster", "Rockstar", "Celsius", "Reign", "Bang"],
        "sportsDrink": ["Gatorade", "Powerade", "BodyArmor", "Body Armor", "Prime Hydration"],
        "electrolyteDrink": ["LMNT", "Liquid I.V.", "Liquid IV", "Nuun", "DripDrop", "Drip Drop", "Pedialyte"],
        "beer": [
            "Guinness", "Heineken", "Corona", "Budweiser", "Bud Light", "Stella Artois", "Modelo",
            "Coors", "IPA", "Lager", "Pilsner", "Stout",
        ],
        "wine": [
            "Merlot", "Cabernet", "Pinot", "Chardonnay", "Sauvignon", "Riesling", "Malbec",
            "Prosecco", "Champagne", "Rosé Wine",
        ],
        "spirits": ["Vodka", "Whisky", "Whiskey", "Gin", "Rum", "Tequila", "Bourbon", "Scotch"],
        "coffee": ["Americano", "Drip Coffee", "Filter Coffee", "Cold Brew", "Black Coffee"],
        "espresso": ["Doppio", "Ristretto"],
        "latte": ["Cappuccino", "Flat White", "Cortado", "Macchiato"],
        "tea": ["Black Tea", "Earl Grey", "English Breakfast", "Chai"],
        "greenTea": ["Matcha", "Sencha"],
        "sparklingWater": [
            "La Croix", "LaCroix", "Perrier", "San Pellegrino", "Pellegrino", "Topo Chico", "Bubly",
            "Seltzer", "Soda Water", "Club Soda",
        ],
        "orangeJuice": ["Tropicana", "Simply Orange"],
    ]

    private static let entries: [(match: Match, words: [String])] = table.flatMap { key, aliases in
        aliases.map { (Match(key: key, alias: $0), words(in: $0)) }
    }

    static func match(in text: String) -> Match? {
        match(words: words(in: text))
    }

    static func match(words typed: [String]) -> Match? {
        var best: (match: Match, length: Int)?
        for entry in entries where contains(typed, alias: entry.words) {
            let length = entry.words.joined().count
            if length > (best?.length ?? 0) {
                best = (entry.match, length)
            }
        }
        return best?.match
    }

    static func words(in text: String) -> [String] {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func contains(_ typed: [String], alias: [String]) -> Bool {
        guard !alias.isEmpty, typed.count >= alias.count else { return false }
        return (0...(typed.count - alias.count)).contains { start in
            Array(typed[start..<(start + alias.count)]) == alias
        }
    }
}

struct DrinkAliasSearch {
    let match: DrinkAliases.Match?
    private let search: FoodSearch

    init(_ query: String) {
        match = DrinkAliases.match(in: query)
        search = FoodSearch(query)
    }

    func includes(_ food: FoodItem) -> Bool {
        guard let match else { return false }
        return food.seedKey == match.key
    }

    func alias(for food: FoodItem) -> String? {
        guard includes(food), !search.matches(food) else { return nil }
        return match?.alias
    }
}
