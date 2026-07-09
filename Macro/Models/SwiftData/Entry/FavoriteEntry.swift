//
//  FavoriteEntry.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/25/26.
//

import SwiftData

@Model
class FavoriteEntry {
    var orderIndex: Int
    var foodItem: FoodItem?
    
    init(orderIndex: Int, foodItem: FoodItem) {
        self.orderIndex = orderIndex
        self.foodItem = foodItem
    }
}
