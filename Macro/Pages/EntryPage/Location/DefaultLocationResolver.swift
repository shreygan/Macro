//
//  DefaultLocationResolver.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/13/26.
//

import CoreLocation
import SwiftData

enum DefaultLocationResolver {
    /// Re-reads a saved location, so renaming or moving it follows through to the foods using it.
    static func resolved(_ location: EntryLocation, in context: ModelContext) -> EntryLocation {
        guard let saved = SavedLocation.find(id: location.savedLocationID, in: context) else {
            var location = location
            location.savedLocationID = nil
            return location
        }
        return saved.entryLocation
    }

    struct UnnamedLocationError: Error {}

    static func set(
        _ location: EntryLocation?,
        for food: FoodItem,
        in context: ModelContext
    ) throws {
        if let place = location {
            guard !place.needsName else { throw UnnamedLocationError() }
            food.defaultLocation = place.withoutMapPin
        } else {
            food.defaultLocation = nil
        }
        try context.save()
    }

    static func named(_ location: EntryLocation) async -> EntryLocation? {
        guard location.needsName else { return location }
        guard let coordinate = location.coordinate,
            let result = await PlaceNamer.name(for: coordinate, includeNearby: false),
            result.location.name != PlaceNamer.droppedPinName
        else { return nil }
        var named = result.location
        named.savedLocationID = location.savedLocationID
        return named
    }

    /// A map place is one branch of a possibly larger chain, so the picker offers the others
    /// nearby. Saved and typed places stand for themselves and have nothing to look up.
    ///
    /// Renaming a branch doesn't make it any less a branch, so the card stays — but only the
    /// map's name finds the siblings, since that's the name they all share.
    static func nearbyName(for food: FoodItem?, in context: ModelContext) -> String? {
        guard let location = food?.defaultLocation, location.mapItemID != nil else { return nil }
        guard let saved = SavedLocation.find(id: location.savedLocationID, in: context) else {
            return location.name
        }
        return saved.isFavorite ? nil : saved.mapName ?? saved.name
    }
}
