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
    var text: String
    var lastUpdated: Date
    
    init(text: String, lastUpdated: Date = Date()) {
        self.text = text
        self.lastUpdated = lastUpdated
    }
}
