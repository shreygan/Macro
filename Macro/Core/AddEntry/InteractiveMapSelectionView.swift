//
//  InteractiveMapSelectionView.swift
//  Macro
//
//  Created by Priyanka Sangha on 2026-05-18.
//

import SwiftUI
import MapKit

struct InteractiveMapSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let locationManager: LocationManager
    var onCompletion: (SelectedLocation) -> Void
    
    // Set default view frame around user or fallback regional tracking coordinates
    @State private var position: MapCameraPosition
    @State private var resolvedString: String = "Locating center..."
    @State private var currentCenterCoordinate: CLLocationCoordinate2D
    
    @State private var isShowingSaveAlert = false
    @State private var customLocationNameInput = ""
    
    init(locationManager: LocationManager, onCompletion: @escaping (SelectedLocation) -> Void) {
        self.locationManager = locationManager
        self.onCompletion = onCompletion
        
        let initialTarget = locationManager.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)
        _currentCenterCoordinate = State(initialValue: initialTarget)
        _position = State(initialValue: .region(MKCoordinateRegion(center: initialTarget, latitudinalMeters: 1000, longitudinalMeters: 1000)))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main Map Canvas tracking camera modifications in real-time
                Map(position: $position)
                    .onMapCameraChange(frequency: .continuous) { context in
                        currentCenterCoordinate = context.camera.centerCoordinate
                        triggerReverseGeocode(for: context.camera.centerCoordinate)
                    }
                
                // Fixed Crosshair Pin Overlay staying dead center during gesture transformations
                VStack {
                    Image(systemName: "mappin")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(radius: 4)
                        .alignmentGuide(VerticalAlignment.center) { d in d[.bottom] }
                    Circle()
                        .fill(.black.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .scaleEffect(y: 0.5)
                }
                
                // Card View anchoring metadata and contextual operations
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            Text(resolvedString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                isShowingSaveAlert = true
                            } label: {
                                Label("Save As...", systemImage: "star")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            
                            Button {
                                let finalLocation = SelectedLocation(
                                    title: resolvedString,
                                    latitude: currentCenterCoordinate.latitude,
                                    longitude: currentCenterCoordinate.longitude
                                )
                                onCompletion(finalLocation)
                                dismiss()
                            } label: {
                                Text("Set Location")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    )
                    .padding()
                }
            }
            .navigationTitle("Pan to Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .alert("Save Location As", isPresented: $isShowingSaveAlert) {
                TextField("e.g. Home, Work, Priyanka QB", text: $customLocationNameInput)
                Button("Save", action: saveAsCustomNamedLocation)
                Button("Cancel", role: .cancel) { customLocationNameInput = "" }
            } message: {
                Text("Enter a custom reference identifier tag for this exact coordinate location map frame.")
            }
            .onAppear {
                triggerReverseGeocode(for: currentCenterCoordinate)
            }
        }
    }
    
    // Reverse geocodes coordinates via standard LocationManager parameter properties
    private func triggerReverseGeocode(for coordinate: CLLocationCoordinate2D) {
        Task {
            let clLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let matchResult = await locationManager.resolveLocationName(for: clLoc)
            await MainActor.run {
                self.resolvedString = matchResult
            }
        }
    }
    
    private func saveAsCustomNamedLocation() {
        let trimmedName = customLocationNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let namedLocation = SelectedLocation(
            title: resolvedString,
            latitude: currentCenterCoordinate.latitude,
            longitude: currentCenterCoordinate.longitude,
            isSaved: !trimmedName.isEmpty,
            customName: trimmedName.isEmpty ? nil : trimmedName
        )
        customLocationNameInput = ""
        onCompletion(namedLocation)
        dismiss()
    }
}
