//
//  ParsedFoodItem.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/31/26.
//

import SwiftData
import SwiftUI

struct ParsedFoodItem: Identifiable, Equatable {
    let id = UUID()
    var source: String
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var isFavorite: Bool = false
}
