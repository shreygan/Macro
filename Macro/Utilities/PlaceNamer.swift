//
//  PlaceNamer.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import MapKit

struct PlaceName {
    var location: EntryLocation
    var nearbyPlace: EntryLocation?
    var nearbySymbol: String?
}

enum PlaceNamer {
    static let droppedPinName = String(localized: "Dropped Pin")
    static let nearbyRadius: CLLocationDistance = 25

    static func name(
        for coordinate: CLLocationCoordinate2D,
        cityOnly: Bool = false,
        includeNearby: Bool = true
    ) async -> PlaceName? {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        async let nearby = includeNearby && !cityOnly
            ? nearbyPlace(to: location) : nil

        guard let request = MKReverseGeocodingRequest(location: location),
            let item = try? await request.mapItems.first
        else {
            _ = await nearby
            return nil
        }

        let street = cityOnly ? nil : streetAddress(of: item)
        let city = item.addressRepresentations?.cityName

        let named = EntryLocation(
            name: street ?? city ?? droppedPinName,
            address: fullAddress(of: item),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let closest = await nearby
        return PlaceName(
            location: named,
            nearbyPlace: closest?.location,
            nearbySymbol: closest?.symbol
        )
    }

    static func nearbyPlace(
        to location: CLLocation
    ) async -> (location: EntryLocation, symbol: String?)? {
        let request = MKLocalPointsOfInterestRequest(
            center: location.coordinate,
            radius: nearbyRadius
        )
        guard let items = try? await MKLocalSearch(request: request).start().mapItems
        else { return nil }

        let closest = items.min {
            $0.location.distance(from: location) < $1.location.distance(from: location)
        }
        guard let closest, let place = EntryLocation(mapItem: closest) else { return nil }
        return (place, closest.pointOfInterestCategory?.symbolName)
    }

    static func streetAddress(of item: MKMapItem) -> String? {
        let candidates = [
            item.address?.shortAddress,
            item.address?.fullAddress.components(separatedBy: .newlines).first,
        ]
        for candidate in candidates.compactMap({ $0 }) {
            let street = candidate
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let street, !street.isEmpty,
                street != item.addressRepresentations?.cityName
            {
                return street
            }
        }
        return nil
    }

    static func fullAddress(of item: MKMapItem) -> String? {
        (item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            ?? item.address?.shortAddress)?
            .collapsingWhitespace
    }
}

extension String {
    var collapsingWhitespace: String {
        replacing(/\s+/, with: " ")
    }
}

extension EntryLocation {
    init?(mapItem item: MKMapItem) {
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name = (name?.isEmpty == false ? name : nil)
            ?? PlaceNamer.streetAddress(of: item)
            ?? item.addressRepresentations?.cityName
        else { return nil }

        let coordinate = item.location.coordinate
        self.init(
            name: name,
            address: PlaceNamer.fullAddress(of: item),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            mapItemID: item.identifier?.rawValue
        )
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}
