//
//  Note.swift
//  Macro
//
//  Created by Shrey Gangwar on 6/24/26.
//


import SwiftData
import Foundation

@Model
class Note {
    var id: UUID = UUID()
    var text: String = ""
    var lastUpdated: Date = Date()

    var foodItem: FoodItem?
    
    init(text: String, lastUpdated: Date = Date()) {
        self.text = text
        self.lastUpdated = lastUpdated
    }
}
