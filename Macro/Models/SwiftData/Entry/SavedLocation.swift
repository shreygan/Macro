//
//  SavedLocation.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import Foundation
import SwiftData

struct DeletedSavedLocationRecord {
    let id: UUID
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let mapItemID: String?
    let isFavorite: Bool
    let mapName: String?
    let displayOrder: Int
    let createdAt: Date
    let entryIDs: [UUID]
}

@Model
class SavedLocation {
    var id: UUID = UUID()
    var name: String = ""
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var mapItemID: String?
    var isFavorite: Bool = true
    var mapName: String?
    var displayOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.savedLocation)
    var entries: [LoggedEntry]? = []

    init(
        id: UUID = UUID(),
        name: String,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        mapItemID: String? = nil,
        isFavorite: Bool = true,
        mapName: String? = nil,
        displayOrder: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.mapItemID = mapItemID
        self.isFavorite = isFavorite
        self.mapName = mapName
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }

    var entryLocation: EntryLocation {
        EntryLocation(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            mapItemID: mapItemID,
            savedLocationID: id
        )
    }

    /// The first rename banks the name this place came into the app with, so the map's own name
    /// is still available to search chains by and to switch back to.
    func rename(to newName: String, in context: ModelContext) throws {
        if mapName == nil, newName != name {
            mapName = name
        }
        name = newName
        for entry in entries ?? [] {
            entry.storedLocation?.name = newName
        }
        for recent in (try? context.fetch(FetchDescriptor<RecentLocation>())) ?? []
        where recent.location.savedLocationID == id {
            recent.location.name = newName
        }
        for food in (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        where food.defaultLocation?.savedLocationID == id {
            food.defaultLocation?.name = newName
        }
        try context.save()
    }

    @discardableResult
    static func save(
        named name: String,
        from location: EntryLocation,
        isFavorite: Bool = true,
        in context: ModelContext
    ) throws -> SavedLocation? {
        guard let latitude = location.latitude, let longitude = location.longitude else {
            return nil
        }
        let existing = (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? []
        guard linked(location, in: existing) == nil else { return nil }

        var place = location.withoutMapPin
        place.savedLocationID = nil
        let saved = SavedLocation(
            name: name,
            address: location.address,
            latitude: latitude,
            longitude: longitude,
            mapItemID: location.mapItemID,
            isFavorite: isFavorite,
            mapName: location.name == name ? nil : location.name,
            displayOrder: (existing.map(\.displayOrder).max() ?? -1) + 1
        )
        context.insert(saved)

        let unlinked = (try? context.fetch(
            FetchDescriptor<LoggedEntry>(predicate: #Predicate { $0.savedLocation == nil })
        )) ?? []
        for entry in unlinked {
            guard var stored = entry.storedLocation?.withoutMapPin else { continue }
            stored.savedLocationID = nil
            guard RecentLocationStore.isSamePlace(stored, place) else { continue }
            entry.savedLocation = saved
            entry.storedLocation?.name = name
            entry.storedLocation?.savedLocationID = saved.id
        }

        let existingIDs = Set(existing.map(\.id))
        for recent in (try? context.fetch(FetchDescriptor<RecentLocation>())) ?? [] {
            if let id = recent.location.savedLocationID, existingIDs.contains(id) { continue }
            var recentPlace = recent.location.withoutMapPin
            recentPlace.savedLocationID = nil
            guard RecentLocationStore.isSamePlace(recentPlace, place) else { continue }
            recent.location.name = name
            recent.location.savedLocationID = saved.id
        }

        for food in (try? context.fetch(FetchDescriptor<FoodItem>())) ?? [] {
            guard var defaultPlace = food.defaultLocation?.withoutMapPin else { continue }
            if let id = defaultPlace.savedLocationID, existingIDs.contains(id) { continue }
            defaultPlace.savedLocationID = nil
            guard RecentLocationStore.isSamePlace(defaultPlace, place) else { continue }
            food.defaultLocation?.name = name
            food.defaultLocation?.savedLocationID = saved.id
        }

        try context.save()
        return saved
    }

    @discardableResult
    static func rename(
        _ location: EntryLocation,
        to name: String,
        in context: ModelContext
    ) throws -> SavedLocation? {
        let existing = (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? []
        if let linked = linked(location, in: existing) {
            try linked.rename(to: name, in: context)
            return linked
        }
        return try save(named: name, from: location, isFavorite: false, in: context)
    }

    /// Puts the map's name back everywhere the custom one reached. A place that only existed to
    /// hold the rename has nothing left to say, so it goes.
    func revertToMapName(in context: ModelContext) throws {
        guard let mapName else { return }
        try rename(to: mapName, in: context)
        self.mapName = nil
        if !isFavorite {
            context.delete(self)
        }
        try context.save()
    }

    func delete(in context: ModelContext) throws -> DeletedSavedLocationRecord {
        let record = DeletedSavedLocationRecord(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            mapItemID: mapItemID,
            isFavorite: isFavorite,
            mapName: mapName,
            displayOrder: displayOrder,
            createdAt: createdAt,
            entryIDs: (entries ?? []).map(\.id)
        )
        context.delete(self)
        try context.save()
        return record
    }

    static func restore(_ record: DeletedSavedLocationRecord, in context: ModelContext) throws {
        let saved =
            find(id: record.id, in: context)
            ?? SavedLocation(
                id: record.id,
                name: record.name,
                address: record.address,
                latitude: record.latitude,
                longitude: record.longitude,
                mapItemID: record.mapItemID,
                isFavorite: record.isFavorite,
                mapName: record.mapName,
                displayOrder: record.displayOrder,
                createdAt: record.createdAt
            )
        if saved.modelContext == nil {
            context.insert(saved)
        }

        let entryIDs = record.entryIDs
        let entries = (try? context.fetch(
            FetchDescriptor<LoggedEntry>(predicate: #Predicate { entryIDs.contains($0.id) })
        )) ?? []
        for entry in entries {
            entry.savedLocation = saved
        }
        try context.save()
    }

    static func find(id: UUID?, in context: ModelContext) -> SavedLocation? {
        guard let id else { return nil }
        return try? context.fetch(
            FetchDescriptor<SavedLocation>(predicate: #Predicate { $0.id == id })
        ).first
    }

    static func matching(_ location: EntryLocation, in context: ModelContext) -> SavedLocation? {
        matching(location, in: (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? [])
    }

    static func matching(_ location: EntryLocation, in saved: [SavedLocation]) -> SavedLocation? {
        var location = location
        location.savedLocationID = nil
        return saved.first { RecentLocationStore.isSamePlace($0.entryLocation, location) }
    }

    static func linked(_ location: EntryLocation, in saved: [SavedLocation]) -> SavedLocation? {
        if let id = location.savedLocationID, let match = saved.first(where: { $0.id == id }) {
            return match
        }
        return matching(location, in: saved)
    }

    static func occupying(_ location: EntryLocation, in saved: [SavedLocation]) -> SavedLocation? {
        if let match = linked(location, in: saved) {
            return match
        }
        guard location.mapItemID == nil, let point = location.clLocation else { return nil }
        return saved
            .map { ($0, point.distance(from: $0.clLocation)) }
            .filter { $0.1 <= PlaceNamer.nearbyRadius }
            .min { $0.1 < $1.1 }?
            .0
    }

    static let nearbyRadius: CLLocationDistance = 75
    static let maxNearbyRadius: CLLocationDistance = 150

    static func nearest(to fix: CLLocation, in context: ModelContext) -> SavedLocation? {
        nearest(to: fix, in: (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? [])
    }

    static func nearest(to fix: CLLocation, in saved: [SavedLocation]) -> SavedLocation? {
        let radius = min(max(nearbyRadius, fix.horizontalAccuracy), maxNearbyRadius)
        return saved
            .map { ($0, fix.distance(from: $0.clLocation)) }
            .filter { $0.1 <= radius }
            .min { $0.1 < $1.1 }?
            .0
    }

    private var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
