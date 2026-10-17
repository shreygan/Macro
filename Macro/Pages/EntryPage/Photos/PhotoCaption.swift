//
//  PhotoCaption.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import ImageIO
import MapKit
import SwiftData
import SwiftUI

struct PhotoCaption<Accessory: View>: View {
    let coordinate: CLLocationCoordinate2D?
    let capturedAt: Date?
    let logDate: Date?
    let logLocation: EntryLocation?
    let nearbyCoordinates: [CLLocationCoordinate2D]
    let onUseTime: ((Date) -> Void)?
    let onUseLocation: ((EntryLocation) -> Void)?
    let accessory: Accessory

    @Query private var savedLocations: [SavedLocation]
    @State private var resolvedPlaces: [MapPin: EntryLocation] = [:]
    @State private var appliedCount = 0

    init(
        coordinate: CLLocationCoordinate2D?,
        capturedAt: Date?,
        logDate: Date? = nil,
        logLocation: EntryLocation? = nil,
        nearbyCoordinates: [CLLocationCoordinate2D] = [],
        onUseTime: ((Date) -> Void)? = nil,
        onUseLocation: ((EntryLocation) -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.coordinate = coordinate
        self.capturedAt = capturedAt
        self.logDate = logDate
        self.logLocation = logLocation
        self.nearbyCoordinates = nearbyCoordinates
        self.onUseTime = onUseTime
        self.onUseLocation = onUseLocation
        self.accessory = accessory()
    }

    private var validCapturedAt: Date? {
        guard let capturedAt, capturedAt <= .now else { return nil }
        return capturedAt
    }

    private var place: EntryLocation? {
        guard let coordinate else { return nil }
        return PhotoPlaceNamer.knownLocation(at: coordinate, savedLocations: savedLocations)
            ?? resolvedPlaces[MapPin(coordinate)]
    }

    private var isTimeApplied: Bool {
        guard let validCapturedAt, let logDate else { return false }
        return Calendar.current.isDate(validCapturedAt, equalTo: logDate, toGranularity: .minute)
    }

    private var isLocationApplied: Bool {
        guard let place, let logLocation else { return false }
        return RecentLocationStore.isSamePlace(place.withoutMapPin, logLocation.withoutMapPin)
    }

    private var timeText: String? {
        guard let validCapturedAt else { return nil }
        if let logDate, Calendar.current.isDate(validCapturedAt, inSameDayAs: logDate) {
            return validCapturedAt.formatted(date: .omitted, time: .shortened)
        }
        return PhotoMetadata.captureText(for: validCapturedAt)
    }

    private var shownPlace: EntryLocation? {
        guard let place, !place.needsName, !(hidesLogMatches && isLocationApplied) else { return nil }
        return place
    }

    private var hidesLogMatches: Bool {
        onUseTime == nil && onUseLocation == nil
    }

    private var text: String {
        [timeText, shownPlace?.name].compactMap { $0 }.joined(separator: " · ")
    }

    private var accessibilityText: String {
        switch (timeText, shownPlace?.name) {
        case let (time?, place?): String(localized: "Photo taken \(time), at \(place)")
        case let (time?, nil): String(localized: "Photo taken \(time)")
        case let (nil, place?): String(localized: "Photo taken at \(place)")
        case (nil, nil): ""
        }
    }

    private var canUseTime: Bool {
        onUseTime != nil && validCapturedAt != nil
    }

    private var canUseLocation: Bool {
        onUseLocation != nil && coordinate != nil
    }

    private var isInteractive: Bool {
        shownPlace != nil || canUseTime || canUseLocation
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if !text.isEmpty {
                    Menu {
                        menuContent
                    } label: {
                        Text(text)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                            .font(.compactValue)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(isInteractive ? .regular.interactive() : .regular, in: .capsule)
                    .contentShape(.capsule)
                    .allowsHitTesting(isInteractive)
                    .accessibilityLabel(accessibilityText)
                    .accessibilityRemoveTraits(isInteractive ? [] : .isButton)
                    .sensoryFeedback(.success, trigger: appliedCount)
                    .transition(.opacity)
                }
            }
            .layoutPriority(1)

            accessory
        }
        .animation(.snappy(duration: 0.3), value: text)
        .task(id: coordinate.map { MapPin($0) }) {
            await resolvePlace()
        }
        .task(id: nearbyCoordinates.map { MapPin($0) }) {
            await prefetchNearbyPlaces()
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if let shownPlace {
            Button {
                Task { await shownPlace.openInMaps() }
            } label: {
                Text("Open in Maps")
                Text(shownPlace.name)
                Image(systemName: "map")
            }
        }

        if canUseTime || canUseLocation {
            Section {
                PhotoDetailsActions(
                    capturedAt: canUseTime ? validCapturedAt : nil,
                    location: canUseLocation ? place : nil,
                    hasLocation: canUseLocation,
                    isTimeApplied: isTimeApplied,
                    isLocationApplied: isLocationApplied,
                    onUseTime: onUseTime,
                    onUseLocation: onUseLocation,
                    onApply: { appliedCount += 1 }
                )
            }
        }
    }

    private func prefetchNearbyPlaces() async {
        for coordinate in nearbyCoordinates {
            guard !Task.isCancelled else { return }
            _ = await PhotoPlaceNamer.location(at: coordinate, savedLocations: savedLocations)
        }
    }

    private func resolvePlace() async {
        guard let coordinate, place == nil else { return }
        let resolved = await PhotoPlaceNamer.location(at: coordinate, savedLocations: savedLocations)
        guard !Task.isCancelled else { return }
        resolvedPlaces[MapPin(coordinate)] = resolved
    }
}

extension PhotoCaption where Accessory == EmptyView {
    init(
        coordinate: CLLocationCoordinate2D?,
        capturedAt: Date?,
        logDate: Date? = nil,
        logLocation: EntryLocation? = nil,
        nearbyCoordinates: [CLLocationCoordinate2D] = [],
        onUseTime: ((Date) -> Void)? = nil,
        onUseLocation: ((EntryLocation) -> Void)? = nil
    ) {
        self.init(
            coordinate: coordinate,
            capturedAt: capturedAt,
            logDate: logDate,
            logLocation: logLocation,
            nearbyCoordinates: nearbyCoordinates,
            onUseTime: onUseTime,
            onUseLocation: onUseLocation,
            accessory: { EmptyView() }
        )
    }
}

extension EntryLocation {
    func openInMaps() async {
        if let mapItemID,
            let identifier = MKMapItem.Identifier(rawValue: mapItemID),
            let item = try? await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
        {
            _ = item.openInMaps()
            return
        }
        guard let latitude, let longitude else { return }
        var components = URLComponents(string: "https://maps.apple.com/place")
        components?.queryItems = [
            URLQueryItem(name: "coordinate", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "name", value: name),
        ]
        guard let url = components?.url else { return }
        await UIApplication.shared.open(url)
    }
}

#Preview {
    @Previewable @State var selection: UUID?
    let photo: LoggedPhoto = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        }
        let data = NSMutableData()
        if let cgImage = image.cgImage,
            let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
        {
            let properties: [CFString: Any] = [
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifDateTimeOriginal: "2026:09:03 12:40:00"
                ]
            ]
            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
            CGImageDestinationFinalize(destination)
        }
        return LoggedPhoto(image: image, originalData: data as Data, pickerItem: nil)
    }()

    LoggedPhotoViewer(photos: [photo], selection: $selection)
        .onAppear { selection = photo.id }
        .modelContainer(
            try! ModelContainer(
                for: SavedLocation.self,
                configurations: ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            )
        )
}
