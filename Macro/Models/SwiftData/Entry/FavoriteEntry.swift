//
//  FavoriteEntry.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/25/26.
//

import Foundation
import SwiftData

@Model
class FavoriteEntry {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var foodItem: FoodItem?
    
    init(orderIndex: Int, foodItem: FoodItem) {
        self.orderIndex = orderIndex
        self.foodItem = foodItem
    }
}
