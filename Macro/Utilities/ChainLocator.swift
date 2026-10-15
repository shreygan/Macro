//
//  ChainLocator.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/13/26.
//

import CoreLocation
import MapKit

/// What the "Nearby" card in the location picker should look for.
nonisolated enum NearbyPlaceSearch: Hashable {
    /// A chain name taken from a food's default location — branches match the name exactly.
    case chain(String)
    /// A source name the user typed — match by prefix, and only places that sell food.
    case source(String)

    var name: String {
        switch self {
        case .chain(let name), .source(let name): name
        }
    }
}

enum ChainLocator {
    static let fallbackRadius: CLLocationDistance = 25_000
    private static let searchSpan: CLLocationDistance = 20_000

    static func places(
        for search: NearbyPlaceSearch,
        near origin: CLLocation
    ) async -> [(location: EntryLocation, symbol: String?)] {
        switch search {
        case .chain(let name):
            return await branches(named: name, near: origin)
        case .source(let name):
            return await foodPlaces(matching: name, near: origin)
        }
    }

    private static func branches(
        named name: String,
        near origin: CLLocation
    ) async -> [(location: EntryLocation, symbol: String?)] {
        let query = searchQuery(name)
        guard !query.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: origin.coordinate,
            latitudinalMeters: searchSpan,
            longitudinalMeters: searchSpan
        )
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else {
            return []
        }
        return located(items.filter { isSameName($0.name, name) }, near: origin)
    }

    private static func foodPlaces(
        matching typed: String,
        near origin: CLLocation
    ) async -> [(location: EntryLocation, symbol: String?)] {
        let query = normalized(typed)
        guard query.count >= 2,
            !AppSeeder.defaultEntrySources.contains(where: { normalized($0) == query })
        else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery(typed)
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: origin.coordinate,
            latitudinalMeters: searchSpan,
            longitudinalMeters: searchSpan
        )
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else {
            return []
        }
        let matches = items.filter { item in
            guard let category = item.pointOfInterestCategory,
                foodSourceCategories.contains(category)
            else { return false }
            return startsWithWord(normalized(item.name ?? ""), query)
        }
        return located(matches, near: origin)
    }

    private static func located(
        _ items: [MKMapItem],
        near origin: CLLocation
    ) -> [(location: EntryLocation, symbol: String?)] {
        items
            .sorted { $0.location.distance(from: origin) < $1.location.distance(from: origin) }
            .compactMap { item in
                EntryLocation(mapItem: item).map { ($0, item.pointOfInterestCategory?.symbolName) }
            }
    }

    private static let foodSourceCategories: Set<MKPointOfInterestCategory> = [
        .restaurant, .cafe, .bakery, .brewery, .winery, .distillery, .nightlife,
        .foodMarket, .store,
    ]

    private static func startsWithWord(_ name: String, _ query: String) -> Bool {
        guard name.hasPrefix(query) else { return false }
        guard let next = name.dropFirst(query.count).first else { return true }
        return !next.isLetter && !next.isNumber
    }

    private static func isSameName(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        return normalized(lhs) == normalized(rhs)
    }

    /// Source names carry tags like "Costco 🇨🇦", which MapKit can't search for and which never
    /// appear in the names it returns.
    private static func searchQuery(_ text: String) -> String {
        withoutEmoji(text).collapsingWhitespace.trimmingCharacters(in: .whitespaces)
    }

    private static func withoutEmoji(_ text: String) -> String {
        text.filter { character in
            !character.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation
                    || scalar.properties.isEmojiModifier
                    || scalar.properties.isEmojiModifierBase
                    || scalar.properties.isVariationSelector
                    || (0x1F1E6...0x1F1FF).contains(scalar.value)
            }
        }
    }

    private static func normalized(_ text: String) -> String {
        searchQuery(text)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacing(/['’]/, with: "")
    }
}
