//
//  DataEraser.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/30/26.
//

import SwiftData

extension ModelContext {
    func eraseAllData() throws {
        try deleteEach(EntryPhoto.self)
        try deleteEach(RecipeIngredient.self)
        try deleteEach(Note.self)
        try deleteEach(UserGoals.self)
        try deleteEach(EntryDraft.self)
        try deleteEach(LoggedEntry.self)
        try deleteEach(FavoriteEntry.self)
        try deleteEach(FoodItem.self)
        try deleteEach(EntrySource.self)
        try deleteEach(CategorySource.self)
        try deleteEach(FoodGroupSource.self)
        try deleteEach(ServingSizeUnit.self)
        try deleteEach(User.self)
    }

    private func deleteEach<T: PersistentModel>(_ type: T.Type) throws {
        for model in try fetch(FetchDescriptor<T>()) {
            delete(model)
        }
    }
}
