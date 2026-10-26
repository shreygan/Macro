//
//  EntryLocation.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import Foundation

nonisolated struct MapPin: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

nonisolated struct EntryLocation: Codable, Hashable, Sendable {
    var name: String
    var address: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var mapItemID: String? = nil
    var savedLocationID: UUID? = nil
    var needsName: Bool = false
    private var mapPinLatitude: Double? = nil
    private var mapPinLongitude: Double? = nil

    init(
        name: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapItemID: String? = nil,
        savedLocationID: UUID? = nil,
        needsName: Bool = false,
        mapPin: MapPin? = nil
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.mapItemID = mapItemID
        self.savedLocationID = savedLocationID
        self.needsName = needsName
        self.mapPin = mapPin
    }

    var mapPin: MapPin? {
        get {
            guard let mapPinLatitude, let mapPinLongitude else { return nil }
            return MapPin(latitude: mapPinLatitude, longitude: mapPinLongitude)
        }
        set {
            mapPinLatitude = newValue?.latitude
            mapPinLongitude = newValue?.longitude
        }
    }

    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    var withoutMapPin: EntryLocation {
        var location = self
        location.mapPin = nil
        return location
    }
}
