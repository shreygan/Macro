//
//  PhotoPlaceNamer.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation

enum PhotoPlaceNamer {
    private static var named: [MapPin: EntryLocation] = [:]

    static func knownLocation(
        at coordinate: CLLocationCoordinate2D,
        savedLocations: [SavedLocation]
    ) -> EntryLocation? {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let saved = SavedLocation.nearest(to: point, in: savedLocations) {
            return saved.entryLocation
        }
        return named[MapPin(coordinate)]
    }

    static func location(
        at coordinate: CLLocationCoordinate2D,
        savedLocations: [SavedLocation]
    ) async -> EntryLocation {
        if let known = knownLocation(at: coordinate, savedLocations: savedLocations) {
            return known
        }
        let pin = MapPin(coordinate)
        if let pending = inFlight[pin] {
            return await pending.value
        }
        let task = Task { await geocode(coordinate) }
        inFlight[pin] = task
        let location = await task.value
        inFlight[pin] = nil
        return location
    }

    private static var inFlight: [MapPin: Task<EntryLocation, Never>] = [:]

    private static func geocode(_ coordinate: CLLocationCoordinate2D) async -> EntryLocation {
        if let result = await PlaceNamer.name(for: coordinate) {
            let location = result.nearbyPlace ?? result.location
            named[MapPin(coordinate)] = location
            return location
        }
        return EntryLocation(
            name: PlaceNamer.droppedPinName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            needsName: true
        )
    }
}
