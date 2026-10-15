//
//  PendingLocationNamer.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import Foundation
import SwiftData

enum PendingLocationNamer {
    private static var isRunning = false
    private static var needsRerun = false
    private static let spacing: Duration = .milliseconds(500)

    static func run(in context: ModelContext) async {
        guard !isRunning else {
            needsRerun = true
            return
        }
        isRunning = true
        defer { isRunning = false }

        repeat {
            needsRerun = false
            await namePending(in: context)
        } while needsRerun
    }

    private static func namePending(in context: ModelContext) async {
        let descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate { $0.needsLocationName && $0.parentEntry == nil },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else {
            return
        }

        let savedLocations = (try? context.fetch(FetchDescriptor<SavedLocation>())) ?? []

        for entry in entries {
            guard !entry.isDeleted else { continue }
            guard let pending = entry.storedLocation, let coordinate = pending.coordinate
            else {
                markNamed(entry, as: entry.storedLocation)
                continue
            }

            if pending.mapPin == nil, let clLocation = pending.clLocation,
                let saved = SavedLocation.nearest(to: clLocation, in: savedLocations)
            {
                markNamed(entry, as: saved.entryLocation, savedLocation: saved)
                renameRecent(from: pending, to: saved.entryLocation, in: context)
                try? context.save()
                continue
            }

            guard
                let result = await PlaceNamer.name(
                    for: coordinate,
                    includeNearby: false
                )
            else { break }

            guard !entry.isDeleted, entry.needsLocationName else { continue }
            guard entry.storedLocation == pending else {
                needsRerun = true
                continue
            }

            var named = result.location
            named.savedLocationID = pending.savedLocationID
            named.mapPin = pending.mapPin
            markNamed(entry, as: named)
            renameRecent(from: pending, to: named, in: context)
            try? context.save()

            try? await Task.sleep(for: spacing)
        }
    }

    private static func markNamed(
        _ entry: LoggedEntry,
        as location: EntryLocation?,
        savedLocation: SavedLocation? = nil
    ) {
        var named = location
        named?.needsName = false
        entry.storedLocation = named
        entry.needsLocationName = false
        if let savedLocation { entry.savedLocation = savedLocation }

        for child in entry.childEntries ?? [] {
            child.storedLocation = named
            child.needsLocationName = false
            if let savedLocation { child.savedLocation = savedLocation }
        }
    }

    private static func renameRecent(
        from pending: EntryLocation,
        to named: EntryLocation,
        in context: ModelContext
    ) {
        let recents = (try? context.fetch(FetchDescriptor<RecentLocation>())) ?? []
        for recent in recents
        where recent.location.needsName
            && recent.location.latitude == pending.latitude
            && recent.location.longitude == pending.longitude
        {
            recent.location = named.withoutMapPin
        }
    }
}
