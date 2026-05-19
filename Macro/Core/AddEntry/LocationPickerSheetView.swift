//
//  LocationPickerSheet.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-18.
//

import SwiftUI
import MapKit

struct LocationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var locationManager: LocationManager
    @Binding var selectedLocation: SelectedLocation?
    
    @State private var isShowingMapPicker = false
    
    // Stub databases for demo integration
    @State private var savedLocations: [SelectedLocation] = [
        SelectedLocation(title: "Workspace Center", latitude: 49.2827, longitude: -123.1207, isSaved: true, customName: "Priyanka QB")
    ]
    @State private var recentLocations: [SelectedLocation] = []
    
    // MARK: - Filtered Computed Property
    private var matchingSavedLocations: [SelectedLocation] {
        let query = locationManager.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        
        return savedLocations.filter { location in
            let titleMatch = location.title.localizedCaseInsensitiveContains(query)
            let customNameMatch = location.customName?.localizedCaseInsensitiveContains(query) ?? false
            return titleMatch || customNameMatch
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    if locationManager.searchQuery.isEmpty {
                        defaultNavigationSection
                        savedSection
                        recentsSection
                    } else {
                        searchResultsSection
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Find Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $locationManager.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search restaurants, cities or addresses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $isShowingMapPicker) {
                InteractiveMapSelectionView(locationManager: locationManager) { verifiedLocation in
                    recentLocations.insert(verifiedLocation, at: 0)
                    selectedLocation = verifiedLocation
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Subview Sections
    
    private var defaultNavigationSection: some View {
        Section {
            Button {
                if let current = locationManager.currentLocation {
                    selectedLocation = SelectedLocation(
                        title: "Current Location",
                        latitude: current.coordinate.latitude,
                        longitude: current.coordinate.longitude
                    )
                    dismiss()
                } else {
                    locationManager.requestLocation()
                }
            } label: {
                Label("Current Location", systemImage: "location.fill")
                    .foregroundColor(.accentColor)
            }
            
            Button {
                isShowingMapPicker = true
            } label: {
                Label("Choose on Map", systemImage: "map.fill")
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var savedSection: some View {
        Group {
            if !savedLocations.isEmpty {
                Section("Saved Locations") {
                    ForEach(savedLocations) { place in
                        LocationRowItem(location: place) {
                            selectedLocation = place
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private var recentsSection: some View {
        Group {
            if !recentLocations.isEmpty {
                Section("Recent Locations") {
                    ForEach(recentLocations) { place in
                        LocationRowItem(location: place) {
                            selectedLocation = place
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        Group {
            if locationManager.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            let matches = matchingSavedLocations
            if !matches.isEmpty {
                Section("Matching Saved Places") {
                    ForEach(matches) { place in
                        LocationRowItem(location: place) {
                            selectedLocation = place
                            dismiss()
                        }
                    }
                }
            }
            
            Section("Search Results") {
                ForEach(locationManager.searchResults, id: \.self) { item in
                    Button {
                        let resolvedTitle = item.name ?? "Picked Location"
                        let newLoc = SelectedLocation(
                            title: resolvedTitle,
                            latitude: item.placemark.coordinate.latitude,
                            longitude: item.placemark.coordinate.longitude
                        )
                        recentLocations.insert(newLoc, at: 0)
                        selectedLocation = newLoc
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unknown Location")
                                .font(.body)
                                .foregroundColor(.primary)
                            if let subTitle = item.placemark.title, subTitle != item.name {
                                Text(subTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper Row Component
struct LocationRowItem: View {
    let location: SelectedLocation
    let selectAction: () -> Void
    
    var body: some View {
        Button(action: selectAction) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.customName ?? location.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    if location.customName != nil {
                        Text(location.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: location.isSaved ? "star.fill" : "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
