//
//  LocationPill.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-16.
//

import SwiftUI
internal import CoreLocation

struct LocationPill: View {
    let isAuthorized: Bool
    let displayName: String?
    let action: () -> Void
    
    /// Elegant alternative initializer to accept your modern model directly
    init(
        isAuthorized: Bool,
        location: SelectedLocation?,
        action: @escaping () -> Void
    ) {
        self.isAuthorized = isAuthorized
        // Leverages your custom model's structural truncation rule directly
        self.displayName = location?.truncatedDisplayName
        self.action = action
    }
    
    /// Standard initializer to maintain full backward compatibility
    init(
        isAuthorized: Bool,
        displayName: String?,
        action: @escaping () -> Void
    ) {
        self.isAuthorized = isAuthorized
        self.displayName = displayName
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(displayText)
                    .font(.system(size: 16))
                    .lineLimit(1)
            }
            .foregroundColor(isAuthorized ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(UIColor.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Presentational Styling Layouts
    
    private var iconName: String {
        if !isAuthorized {
            return "location.slash.fill"
        }
        // If a location object is attached, swap to a precise map pin marker
        return displayName == nil ? "location.fill" : "mappin.and.tailward"
    }
    
    private var displayText: String {
        guard isAuthorized else {
            return "Grant Location"
        }
        return displayName ?? "Current Location"
    }
}

// MARK: - Clean Preview System

#Preview {
    VStack(spacing: 16) {
        // State 1: Location Access Disallowed / Restricted
        LocationPill(isAuthorized: false, displayName: nil) {
            print("Pill tapped: Requesting system level access permission...")
        }
        
        // State 2: Authorized, but no specific coordinate selected yet
        LocationPill(isAuthorized: true, displayName: nil) {
            print("Pill tapped: Fetching instant device location coordinates...")
        }
        
        // State 3: Model State using the new location object structure
        let sampleLocation = SelectedLocation(
            title: "Priyanka QB Cafe Workspace Location", // Truncated cleanly by model rules
            latitude: 49.2827,
            longitude: -123.1207
        )
        
        LocationPill(isAuthorized: true, location: sampleLocation) {
            print("Pill tapped: Modifying selection entry parameters...")
        }
    }
    .padding()
}
