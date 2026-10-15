//
//  LocationManager.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import SwiftUI

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    enum Permission {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    private(set) var permission: Permission = .notDetermined
    private(set) var isReducedAccuracy = false
    private(set) var lastLocation: CLLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var permissionWaiters: [CheckedContinuation<Permission, Never>] = []
    @ObservationIgnored private var locating: Task<Void, Never>?

    private static let freshInterval: TimeInterval = 120
    private static let goodAccuracy: CLLocationAccuracy = 50

    override init() {
        super.init()
        manager.delegate = self
        refreshPermission()
    }

    var isAuthorized: Bool { permission == .authorized }

    var freshLocation: CLLocation? {
        guard let lastLocation,
            -lastLocation.timestamp.timeIntervalSinceNow < Self.freshInterval
        else { return nil }
        return lastLocation
    }

    @discardableResult
    func requestPermission() async -> Permission {
        guard permission == .notDetermined else { return permission }
        return await withCheckedContinuation { continuation in
            permissionWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation(timeout: Duration = .seconds(8)) async -> CLLocation? {
        guard isAuthorized else { return nil }
        if let location = freshLocation,
            location.horizontalAccuracy <= Self.goodAccuracy
        {
            return location
        }

        if let locating {
            await locating.value
            return freshLocation
        }
        let task = Task { await locate(timeout: timeout) }
        locating = task
        await task.value
        locating = nil
        return freshLocation
    }

    private func locate(timeout: Duration) async {
        let updates = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location {
                        record(location)
                        if location.horizontalAccuracy <= Self.goodAccuracy { return }
                    }
                    if update.authorizationDenied || update.authorizationDeniedGlobally {
                        return
                    }
                }
            } catch {}
        }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            updates.cancel()
        }

        await updates.value
        timer.cancel()
    }

    func currentPlace(
        matching saved: [SavedLocation] = [],
        timeout: Duration = .seconds(8)
    ) async -> EntryLocation? {
        guard let fix = await currentLocation(timeout: timeout) else { return nil }
        if !isReducedAccuracy, let match = SavedLocation.nearest(to: fix, in: saved) {
            return match.entryLocation
        }
        if let named = await PlaceNamer.name(
            for: fix.coordinate,
            cityOnly: isReducedAccuracy,
            includeNearby: false
        ) {
            return named.location
        }
        return EntryLocation(
            name: PlaceNamer.droppedPinName,
            latitude: fix.coordinate.latitude,
            longitude: fix.coordinate.longitude,
            needsName: true
        )
    }

    func discardCachedLocation() {
        lastLocation = nil
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func record(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        if let lastLocation,
            -lastLocation.timestamp.timeIntervalSinceNow < Self.freshInterval,
            lastLocation.horizontalAccuracy < location.horizontalAccuracy,
            location.distance(from: lastLocation) < location.horizontalAccuracy
        {
            return
        }
        lastLocation = location
    }

    private func refreshPermission() {
        switch manager.authorizationStatus {
        case .notDetermined: permission = .notDetermined
        case .restricted: permission = .restricted
        case .denied: permission = .denied
        default: permission = .authorized
        }
        isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy

        guard permission != .notDetermined else { return }
        let waiters = permissionWaiters
        permissionWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: permission)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refreshPermission()
        }
    }
}
