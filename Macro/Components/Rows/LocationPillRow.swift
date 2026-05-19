//
//  LocationPillRow.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-16.
//

import SwiftUI
internal import CoreLocation

struct LocationPillRow: View {
    /// Read-only reference to the state-driven manager passed down from the parent view
    let locationManager: LocationManager
    
    /// Two-way binding to update or clear the active location model state
    @Binding var selectedLocation: SelectedLocation?
    
    /// The action block that fires when the row or the pill is pressed
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Clean layout row title label
            Text("Location")
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Center/Right side: Your lightweight presentational capsule pill component
            LocationPill(
                isAuthorized: locationManager.authorizationStatus != .denied && locationManager.authorizationStatus != .restricted,
                location: selectedLocation,
                action: action
            )
            
            // Right edge: Quick-clear button to detach the location entry object safely
            if selectedLocation != nil {
                Button(role: .cancel) {
                    withAnimation(.spring(duration: 0.2)) {
                        selectedLocation = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 18))
                        .padding(.leading, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        // Ensures the entire row area responds nicely to taps, not just the text elements
        .contentShape(Rectangle())
    }
}

// MARK: - Safe Preview System Hook

#Preview {
    // Spin up a mock instance of your modern observable LocationManager
    @Previewable @State var mockManager = LocationManager()
    
    @Previewable @State var activeLocation: SelectedLocation? = SelectedLocation(
        title: "Richmond, BC",
        latitude: 49.1666,
        longitude: -123.1336
    )
    
    List {
        Section("Layout Previews") {
            // State 1: Populated selected state row wrapper layout
            LocationPillRow(
                locationManager: mockManager,
                selectedLocation: $activeLocation
            ) {
                print("Row tapped while location is populated")
            }
            
            // State 2: Unselected empty state row wrapper layout
            LocationPillRow(
                locationManager: mockManager,
                selectedLocation: .constant(nil)
            ) {
                print("Row tapped while location is empty")
            }
        }
    }
}
