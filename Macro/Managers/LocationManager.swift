//
//  LocationManager.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-16.
//

import Foundation
internal import CoreLocation
import MapKit
import Observation
import Combine

// MARK: - Selected Location Model
struct SelectedLocation: Identifiable, Codable, Equatable {
    var id = UUID()
    let title: String          // Custom name, POI name, or Address string
    let latitude: Double
    let longitude: Double
    var isSaved: Bool = false
    var customName: String?    // e.g., "Home", "Work", "Priyanka QB"
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Returns the name truncated with trailing ellipses if it exceeds the maximum size boundaries.
    var truncatedDisplayName: String {
        let name = customName ?? title
        let maxLimit = 22
        if name.count > maxLimit {
            return String(name.prefix(maxLimit)).trimmingCharacters(in: .whitespaces) + "..."
        }
        return name
    }
    
    static func == (lhs: SelectedLocation, rhs: SelectedLocation) -> Bool {
        lhs.id == rhs.id || (lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude)
    }
}

// MARK: - Location Manager Engine
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var searchCancellable: AnyCancellable?
    
    // Core Status tracking
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    
    // Search properties
    var searchQuery = "" {
        didSet {
            debounceSearch()
        }
    }
    var searchResults: [MKMapItem] = []
    var isSearching = false
    
    override init() {
        super.init()
        manager.delegate = self
        self.authorizationStatus = manager.authorizationStatus
    }
    
    // MARK: - Permission & Requests
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        manager.requestLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        // Fetch current location instantly if access was newly granted
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.currentLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to pinpoint device coordinates: \(error.localizedDescription)")
    }
    
    // MARK: - Smart Search Pipeline
    private func debounceSearch() {
        searchCancellable?.cancel()
        
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.searchResults = []
            return
        }
        
        searchCancellable = Just(searchQuery)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performLocalSearch(with: query)
            }
    }
    
    private func performLocalSearch(with query: String) {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let current = currentLocation {
            request.region = MKCoordinateRegion(
                center: current.coordinate,
                latitudinalMeters: 60000,
                longitudinalMeters: 60000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            self.isSearching = false
            if let mapItems = response?.mapItems {
                self.searchResults = mapItems
            }
        }
    }
    
    // MARK: - Modern iOS Reverse Geocoding Waterfall
    /// Resolves structural coordinates using the modern MKReverseGeocodingRequest and addressRepresentations properties
    func resolveLocationName(for location: CLLocation) async -> String {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return "Dropped Pin"
        }
        
        do {
            let mapItems = try await request.mapItems
            guard let primaryItem = mapItems.first else {
                return "Dropped Pin"
            }
            
            // Extract the modern address representation properties
            let addressRep = primaryItem.addressRepresentations
            
            // Grab a single-line address fallback cleanly formatted by MapKit if needed
            let fullAddressString = addressRep?.fullAddress(includingRegion: false, singleLine: true)
            
            // 1. Point of Interest (e.g., "Pike Place Market" or "Chipotle")
            if let name = primaryItem.name, name != fullAddressString {
                return name
            }
            
            // 2. Street Address fallback from the formatted single-line representation
            if let fullAddressString, !fullAddressString.isEmpty {
                return fullAddressString
            }
            
            // 3. City Name / SubLocality fallback
            if let city = addressRep?.cityName {
                return city
            }
            
            return "Dropped Pin"
            
        } catch {
            print("Reverse geocoding step dropped: \(error.localizedDescription)")
            return "Dropped Pin"
        }
    }
    
    // MARK: - Safe Entry Pipeline Driver
    /// Coordinates permission validation and returns a localized SelectedLocation object instance on the main thread loop
    @MainActor
    func fetchAndResolveCurrentLocation() async -> SelectedLocation? {
        // 1. Kick off permission request if the system hasn't prompted yet
        if authorizationStatus == .notDetermined {
            requestPermission()
            return nil
        }
        
        // Exit early if the user has explicitly blocked location access
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            return nil
        }
        
        // 2. Fire the hardware ping request
        requestLocation()
        
        // Give the CoreLocation hardware stack a tiny moment to latch onto a satellite link split
        try? await Task.sleep(for: .milliseconds(300))
        
        // 3. Extract and run our reverse geocoding waterfall
        if let currentGPS = currentLocation {
            let locationName = await resolveLocationName(for: currentGPS)
            
            return SelectedLocation(
                title: locationName,
                latitude: currentGPS.coordinate.latitude,
                longitude: currentGPS.coordinate.longitude
            )
        }
        
        return nil
    }
}
