//
//  AppSymbols.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/18/26.
//

import SwiftUI

enum AppSymbols: String {
    case food = "fork.knife"
    case recipe = "list.clipboard"
    case ingredient = "carrot"
    case drink = "cup.and.saucer"
    case all = "square.grid.2x2"

    var image: Image {
        Image(systemName: self.rawValue)
    }

    static func from(_ str: String) -> AppSymbols? {
        switch str {
        case "Food": return .food
        case "Recipe": return .recipe
        case "Ingredient": return .ingredient
        case "Drink": return .drink
        case "All": return .all
        default: return nil
        }
    }
}

extension EntryType {
    var appSymbol: AppSymbols {
        switch self {
        case .food: return .food
        case .recipe: return .recipe
        case .ingredient: return .ingredient
        case .drink: return .drink
        }
    }
}
