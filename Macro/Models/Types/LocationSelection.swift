//
//  LocationSelection.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import Foundation
import SwiftData

enum LocationSelection: Equatable {
    case none
    case current(EntryLocation?)
    case place(EntryLocation)

    init(_ location: EntryLocation?, usesCurrentLocation: Bool = false) {
        if usesCurrentLocation {
            self = .current(location)
        } else if let location {
            self = .place(location)
        } else {
            self = .none
        }
    }

    static var defaultForNewLog: LocationSelection {
        LocationManager.shared.isAuthorized ? .current(nil) : .none
    }

    static func defaultForNewLog(
        food: FoodItem?,
        repeating previousEntry: LoggedEntry? = nil
    ) -> LocationSelection {
        if let location = food?.defaultLocation {
            guard let context = food?.modelContext else { return .place(location) }
            return .place(DefaultLocationResolver.resolved(location, in: context))
        }
        if let previous = previousEntry?.location {
            return .place(previous)
        }
        return defaultForNewLog
    }

    /// The place a Current Location has landed on, under the name it will be logged with. A pin
    /// still waiting on its reverse-geocode has no name worth showing, so it reads as nothing and
    /// the selection goes on describing itself.
    var currentPlaceName: String? {
        guard case .current(let place) = self, let place, !place.needsName else { return nil }
        return place.name
    }

    /// What a draft should remember. A draft is written where you are and finished later
    /// somewhere else — at a restaurant now, at home tonight — so a place that has already been
    /// found is frozen into it. Only a selection that never resolved stays dynamic, since there
    /// is nothing to freeze; an unnamed pin counts as unresolved, or the draft would come back
    /// reading "Dropped Pin".
    var draftLocation: (location: EntryLocation?, usesCurrentLocation: Bool) {
        let resolved = resolvedLocation
        guard isCurrent, resolved == nil || resolved?.needsName == true else {
            return (resolved, false)
        }
        return (nil, true)
    }

    func isChosenDifferently(from initial: LocationSelection) -> Bool {
        guard !(isCurrent && initial.isCurrent) else { return false }
        return self != initial
    }

    var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }

    var isNone: Bool { self == .none }

    var mapPin: MapPin? {
        if case .place(let location) = self { return location.mapPin }
        return nil
    }

    var resolvedLocation: EntryLocation? {
        switch self {
        case .none:
            return nil
        case .place(let location):
            return location
        case .current(let location):
            return location ?? Self.pendingCurrentLocation
        }
    }

    private static var pendingCurrentLocation: EntryLocation? {
        guard let fix = LocationManager.shared.freshLocation else { return nil }
        return EntryLocation(
            name: PlaceNamer.droppedPinName,
            latitude: fix.coordinate.latitude,
            longitude: fix.coordinate.longitude,
            needsName: true
        )
    }
}
