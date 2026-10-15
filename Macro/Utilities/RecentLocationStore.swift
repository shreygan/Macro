//
//  RecentLocationStore.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import Foundation
import SwiftData

enum RecentLocationStore {
    static let samePlaceDistance: CLLocationDistance = 50

    static func record(
        _ location: EntryLocation?,
        usedAt date: Date = Date(),
        in context: ModelContext
    ) {
        record([(location, date)], in: context)
    }

    static func record(
        _ uses: [(location: EntryLocation?, date: Date)],
        in context: ModelContext
    ) {
        var recents = (try? context.fetch(FetchDescriptor<RecentLocation>())) ?? []

        for use in uses {
            guard let location = use.location?.withoutMapPin, !location.name.isEmpty
            else { continue }

            if let match = recents.first(where: { isSamePlace($0.location, location) }) {
                guard use.date >= match.lastUsed else { continue }
                match.location = location
                match.lastUsed = use.date
            } else {
                let recent = RecentLocation(location: location, lastUsed: use.date)
                context.insert(recent)
                recents.append(recent)
            }
        }
    }

    static func delete(_ location: EntryLocation, in context: ModelContext) throws {
        let recents = (try? context.fetch(FetchDescriptor<RecentLocation>())) ?? []
        for recent in recents where isSamePlace(recent.location, location) {
            context.delete(recent)
        }
        try context.save()
    }

    static func isSamePlace(_ lhs: EntryLocation, _ rhs: EntryLocation) -> Bool {
        if let left = lhs.savedLocationID, let right = rhs.savedLocationID {
            return left == right
        }
        if let left = lhs.mapItemID, let right = rhs.mapItemID {
            return left == right
        }

        let sameName = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame
        guard let left = lhs.clLocation, let right = rhs.clLocation else {
            return sameName && !lhs.hasCoordinate && !rhs.hasCoordinate
        }
        return sameName && left.distance(from: right) <= samePlaceDistance
    }
}
