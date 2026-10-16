//
//  LocationRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import SwiftData
import SwiftUI

struct LocationRow: View {
    var title: String = String(localized: "Location")
    @Binding var selection: LocationSelection
    var food: FoodItem? = nil
    var photos: [LoggedPhoto] = []
    var logDate: Date? = nil
    var isEnabled: Bool = true
    var promptsForPermission: Bool = true
    var nearbyName: String? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var isPickerPresented = false

    private var locationManager: LocationManager { .shared }

    private struct NearbyWarmUp: Equatable {
        let name: String?
        let fix: Date?
    }

    /// Keyed to the fix as well as the name, since there's often none yet when the log view
    /// appears and the card has nothing to search around until one arrives.
    private var nearbyWarmUp: NearbyWarmUp {
        NearbyWarmUp(name: nearbyName, fix: locationManager.freshLocation?.timestamp)
    }

    private var showsPermissionPrompt: Bool {
        promptsForPermission
            && selection.isNone
            && locationManager.permission == .notDetermined
    }

    /// True for a place you picked by hand while standing at it. A Current Location says so on
    /// its own, so this only has to cover the places that were chosen rather than found.
    private var isAtSelectedPlace: Bool {
        guard !selection.isCurrent, !locationManager.isReducedAccuracy,
            let place = selection.resolvedLocation, let there = place.clLocation,
            let here = locationManager.lastLocation
        else { return false }
        let radius = min(
            max(SavedLocation.nearbyRadius, here.horizontalAccuracy),
            SavedLocation.maxNearbyRadius
        )
        return here.distance(from: there) <= radius
    }

    var body: some View {
        BaseRowLayout(title: title, fitsRightContent: true) {
            LocationPill(
                selection: selection,
                showsPermissionPrompt: showsPermissionPrompt,
                isEnabled: isEnabled,
                isHere: isAtSelectedPlace,
                action: handleTap
            )
        }
        .sheet(isPresented: $isPickerPresented) {
            LocationPickerSheet(
                selection: $selection,
                foodIDs: food.map { [$0.id] } ?? [],
                photos: photos,
                logDate: logDate,
                nearby: nearbyName.map(NearbyPlaceSearch.chain),
                defaultFor: food
            )
        }
        .task(id: selection) {
            await resolveCurrentLocation()
        }
        .task(id: nearbyWarmUp) {
            // A photo's coordinate takes over where the card looks, and only the picker knows
            // which photo wins, so there's nothing worth warming from here.
            guard photos.allSatisfy({ $0.coordinate == nil }) else { return }
            NearbyPlaceCache.shared.warm(nearbyName.map(NearbyPlaceSearch.chain))
        }
    }

    private func handleTap() {
        guard showsPermissionPrompt else {
            isPickerPresented = true
            return
        }
        Task {
            if await locationManager.requestPermission() == .authorized {
                selection = .current(nil)
            }
        }
    }

    private func resolveCurrentLocation() async {
        guard selection == .current(nil), locationManager.isAuthorized else { return }
        let saved = (try? modelContext.fetch(FetchDescriptor<SavedLocation>())) ?? []
        guard let place = await locationManager.currentPlace(matching: saved),
            !Task.isCancelled,
            selection == .current(nil)
        else { return }
        selection = .current(place)
    }
}
