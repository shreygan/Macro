//
//  NearbyPlaceCache.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/14/26.
//

import CoreLocation
import Foundation

nonisolated struct NearbyPlace: Hashable, Sendable {
    var location: EntryLocation
    var symbol: String?
}

/// Holds the shortlist behind the picker's "Nearby" card. A MapKit round trip is the whole of
/// the wait before the card appears, so anything that already knows what the card will look for
/// can warm it, and reopening the picker costs nothing.
@MainActor
final class NearbyPlaceCache {
    static let shared = NearbyPlaceCache()

    static let placeLimit = 5

    private static let lifetime: TimeInterval = 300

    private struct Key: Hashable {
        /// Results are ordered by distance and reach 25 km out, so a cell this small only ever
        /// re-searches after a move that could genuinely reorder them.
        private static let cellDegrees = 0.00225

        let search: NearbyPlaceSearch
        let latitude: Int
        let longitude: Int

        init(_ search: NearbyPlaceSearch, near origin: CLLocation) {
            self.search = search
            latitude = Int((origin.coordinate.latitude / Self.cellDegrees).rounded())
            longitude = Int((origin.coordinate.longitude / Self.cellDegrees).rounded())
        }
    }

    private struct Record {
        let places: [NearbyPlace]
        let storedAt: Date
    }

    private var records: [Key: Record] = [:]
    private var searches: [Key: Task<[NearbyPlace], Never>] = [:]

    /// What the picker can show on its first frame, before any search of its own has landed.
    func cached(for search: NearbyPlaceSearch, near origin: CLLocation) -> [NearbyPlace]? {
        guard let record = records[Key(search, near: origin)],
            -record.storedAt.timeIntervalSinceNow < Self.lifetime
        else { return nil }
        return record.places
    }

    func places(for search: NearbyPlaceSearch, near origin: CLLocation) async -> [NearbyPlace] {
        if let places = cached(for: search, near: origin) { return places }

        let key = Key(search, near: origin)
        if let running = searches[key] { return await running.value }

        // Unstructured on purpose: a warm-up outlives the view that started it, and a picker
        // opened mid-flight joins that same search instead of firing a second one.
        let task = Task<[NearbyPlace], Never> {
            await ChainLocator.places(for: search, near: origin)
                .filter {
                    ($0.location.clLocation?.distance(from: origin) ?? .infinity)
                        <= ChainLocator.fallbackRadius
                }
                .prefix(Self.placeLimit)
                .map { NearbyPlace(location: $0.location, symbol: $0.symbol) }
        }
        searches[key] = task

        let places = await task.value
        searches[key] = nil
        records = records.filter { -$1.storedAt.timeIntervalSinceNow < Self.lifetime }
        records[key] = Record(places: places, storedAt: .now)
        return places
    }

    /// Warms the card before the picker is opened, but only from a fix we already have —
    /// speculative work shouldn't be what starts the radio.
    func warm(_ search: NearbyPlaceSearch?) {
        let manager = LocationManager.shared
        guard let search,
            !manager.isReducedAccuracy,
            let origin = manager.freshLocation,
            cached(for: search, near: origin) == nil
        else { return }
        Task { _ = await places(for: search, near: origin) }
    }
}
