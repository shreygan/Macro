//
//  MapPinPickerView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import MapKit
import SwiftData
import SwiftUI

struct MapPhotoPin: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let thumbnail: UIImage?
    let location: EntryLocation?
}

struct MapPinPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    var savesOnly: Bool
    var query: String?
    var photos: [MapPhotoPin]
    var onSelect: (LocationSelection) -> Void

    @Query(sort: \SavedLocation.displayOrder) private var savedLocations: [SavedLocation]

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D?
    @State private var isMoving = false
    @State private var placeName: PlaceName?
    @State private var isNaming = false
    @State private var namingFailed = false
    @State private var choice: Choice = .address
    @State private var namingTask: Task<Void, Never>?
    @State private var compactCardHeight: CGFloat = 0
    @State private var restoredMapPin: CLLocationCoordinate2D?
    @State private var restoredNearby: EntryLocation?
    @State private var restoredNearbySymbol: String?
    @State private var mapSelection: MapSelection<MapTarget>?
    @State private var pinnedSelection: MapSelection<MapTarget>?
    @State private var isFlyingToSelection = false
    @State private var featureTask: Task<Void, Never>?
    @State private var camera: MapCamera?
    @State private var settledRegion: MKCoordinateRegion?
    @State private var userCenter: CLLocationCoordinate2D?
    @State private var results: [EntryLocation]
    @State private var resultSymbols: [EntryLocation: String]
    @State private var searchedRegion: MKCoordinateRegion?
    @State private var areaSearchTask: Task<Void, Never>?
    @State private var hasMovedMap = false

    @State private var isSaving = false
    @State private var pendingSave: PendingSave?
    @State private var saveName = ""

    private enum Choice {
        case address, saved, nearby
    }

    /// What the naming alert is about to write. The map keeps reacting while the alert is up —
    /// the keyboard alone resizes it — so the place is settled when the alert opens rather than
    /// read back from the card afterwards.
    private struct PendingSave {
        var location: EntryLocation
        var center: CLLocationCoordinate2D
        var existing: SavedLocation?
    }

    private enum MapTarget: Hashable {
        case place(EntryLocation)
        case photo(UUID)
    }

    private static let span: CLLocationDistance = 400
    private static let resultLimit = 40
    private static let initialSearchRadius: CLLocationDistance = 50_000

    init(
        initialSelection: LocationSelection,
        savesOnly: Bool = false,
        query: String? = nil,
        results: [EntryLocation] = [],
        resultSymbols: [EntryLocation: String] = [:],
        photos: [MapPhotoPin] = [],
        onSelect: @escaping (LocationSelection) -> Void
    ) {
        let results = results.filter { $0.coordinate != nil }
        self.savesOnly = savesOnly
        self.query = query
        self.photos = photos
        self.onSelect = onSelect
        _results = State(initialValue: results)
        _resultSymbols = State(initialValue: resultSymbols)

        if let location = initialSelection.resolvedLocation, let pin = location.mapPin {
            _restoredMapPin = State(initialValue: pin.coordinate)
            if location.savedLocationID != nil {
                _choice = State(initialValue: .saved)
            } else if location.mapItemID != nil {
                _restoredNearby = State(initialValue: location.withoutMapPin)
                _restoredNearbySymbol = State(initialValue: resultSymbols[location.withoutMapPin])
                _choice = State(initialValue: .nearby)
            }
        }

        if results.count == 1, let only = results.first {
            _restoredMapPin = State(initialValue: only.coordinate)
            _restoredNearby = State(initialValue: only.mapItemID == nil ? nil : only)
            _restoredNearbySymbol = State(
                initialValue: only.mapItemID == nil ? nil : resultSymbols[only]
            )
            _choice = State(initialValue: only.mapItemID == nil ? .address : .nearby)
        }

        let manager = LocationManager.shared
        if let bounds = Self.bounds(of: results) {
            _position = State(initialValue: .rect(bounds))
        } else if let coordinate = results.first?.coordinate
            ?? initialSelection.mapPin?.coordinate
            ?? initialSelection.resolvedLocation?.coordinate
        {
            _position = State(initialValue: .region(Self.region(around: coordinate)))
        } else if manager.isAuthorized {
            let fallback = manager.lastLocation.map { MapCameraPosition.region(Self.region(around: $0.coordinate)) }
            _position = State(initialValue: .userLocation(fallback: fallback ?? .automatic))
        } else if let last = manager.lastLocation {
            _position = State(initialValue: .region(Self.region(around: last.coordinate)))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    private static func bounds(of places: [EntryLocation]) -> MKMapRect? {
        let points = places.compactMap(\.coordinate).map(MKMapPoint.init)
        guard points.count > 1 else { return nil }

        let bounds = points.reduce(MKMapRect.null) { rect, point in
            rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        return bounds.insetBy(dx: -bounds.width * 0.2, dy: -bounds.height * 0.2)
    }

    private static func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: span,
            longitudinalMeters: span
        )
    }

    private var chosenLocation: EntryLocation? {
        guard let addressLocation else { return nil }
        switch choice {
        case .saved:
            if let savedPlace { return savedPlace.entryLocation }
        case .nearby:
            if let nearbyPlace { return nearbyPlace }
        case .address:
            break
        }
        return addressLocation
    }

    private var savedPlace: SavedLocation? {
        center.flatMap(savedLocation(near:))
    }

    private var suggestedSaveName: String {
        choice == .nearby ? nearbyPlace?.name ?? "" : ""
    }

    private var occupyingSaved: SavedLocation? {
        chosenLocation.flatMap { SavedLocation.occupying($0, in: savedLocations) }
    }

    private var occupyingFavorite: SavedLocation? {
        let occupying = occupyingSaved
        return occupying?.isFavorite == true ? occupying : nil
    }

    private var selectedSaved: SavedLocation? {
        choice == .saved ? savedPlace : nil
    }

    private var nearbyPlace: EntryLocation? {
        guard let nearby = restoredNearby ?? placeName?.nearbyPlace else { return nil }
        if let savedPlace, RecentLocationStore.isSamePlace(savedPlace.entryLocation, nearby) {
            return nil
        }
        return nearby
    }

    /// Mirrors how `nearbyPlace` picks its location, so the icon can't describe a different place.
    private var nearbySymbol: String {
        let symbol = restoredNearby == nil ? placeName?.nearbySymbol : restoredNearbySymbol
        return symbol ?? "building.2"
    }

    private var addressLocation: EntryLocation? {
        guard let center, !isMoving else { return nil }
        if let named = placeName?.location { return named }
        guard namingFailed else { return nil }
        return EntryLocation(
            name: PlaceNamer.droppedPinName,
            latitude: center.latitude,
            longitude: center.longitude,
            needsName: true
        )
    }

    private var favoriteLocations: [SavedLocation] {
        savedLocations.filter(\.isFavorite)
    }

    private var markers: [EntryLocation] {
        results.filter { place in
            !favoriteLocations.contains { RecentLocationStore.isSamePlace($0.entryLocation, place) }
        }
    }

    private var savedMarkers: [SavedLocation] {
        guard query != nil else { return favoriteLocations }
        return favoriteLocations.filter { saved in
            results.contains { RecentLocationStore.isSamePlace(saved.entryLocation, $0) }
        }
    }

    private var isPinHidden: Bool {
        pinnedSelection != nil && (!isMoving || isFlyingToSelection)
    }

    private var trimmedSaveName: String {
        saveName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedSaveName.isEmpty
            && !savedLocations.contains {
                $0.id != pendingSave?.existing?.id
                    && $0.name.caseInsensitiveCompare(trimmedSaveName) == .orderedSame
            }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if compactCardHeight > 0 {
                map
            }

            locationCard
                .padding(.horizontal)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height + 10
                } action: { height in
                    guard addressLocation == nil else { return }
                    compactCardHeight = height
                }
        }
        .navigationTitle("Choose on Map")
        .navigationSubtitle(query ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Current Location", systemImage: isCenteredOnUser ? "location.fill" : "location") {
                    Task { await centerOnUser() }
                }
            }
        }
        .alert(
            pendingSave?.existing == nil ? "Save Location" : "Rename Location",
            isPresented: $isSaving
        ) {
            let pending = pendingSave
            TextField("Name", text: $saveName)
                .textInputAutocapitalization(.words)
            Button("Save") {
                if let pending { saveAndSelect(pending) }
            }
            .disabled(!canSave)
            Button("Cancel", role: .cancel) {
                pendingSave = nil
            }
        } message: {
            Text("Name this place, like Home or Work.")
        }
        .onAppear {
            selectSavedResult()
            selectRestoredMarker()
            if position.followsUserLocation {
                Task { _ = await LocationManager.shared.currentLocation() }
            }
        }
        .onDisappear {
            namingTask?.cancel()
            featureTask?.cancel()
            areaSearchTask?.cancel()
        }
    }

    private var map: some View {
        Map(position: $position, selection: $mapSelection) {
            UserAnnotation()

            ForEach(savedMarkers) { saved in
                let target = MapTarget.place(saved.entryLocation)
                Annotation(
                    saved.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: saved.latitude,
                        longitude: saved.longitude
                    ),
                    anchor: .center
                ) {
                    placeMarker(symbol: "star.fill", tint: .yellow, target: target)
                }
                .tag(MapSelection(target))
            }

            ForEach(markers, id: \.self) { place in
                if let coordinate = place.coordinate {
                    let target = MapTarget.place(place)
                    Annotation(place.name, coordinate: coordinate, anchor: .center) {
                        placeMarker(
                            symbol: resultSymbols[place] ?? "mappin",
                            tint: .red,
                            target: target
                        )
                    }
                    .tag(MapSelection(target))
                }
            }

            ForEach(photos) { photo in
                Annotation(String(localized: "Photo"), coordinate: photo.coordinate, anchor: .center) {
                    photoThumbnail(photo)
                }
                .annotationTitles(.hidden)
                .tag(MapSelection(MapTarget.photo(photo.id)))
            }
        }
        .mapControls {
            MapCompass()
        }
        .mapFeatureSelectionDisabled { $0.kind != .pointOfInterest }
        .onChange(of: mapSelection) { _, selection in
            guard let selection else {
                if let pinnedSelection {
                    mapSelection = pinnedSelection
                }
                return
            }
            guard selection != pinnedSelection else { return }
            guard standsForAPlace(selection) else {
                mapSelection = pinnedSelection
                return
            }
            withAnimation(.snappy(duration: 0.2)) {
                pinnedSelection = selection
            }
            switch selection.value {
            case .place(let place):
                pin(place)
            case .photo(let id):
                if let photo = photos.first(where: { $0.id == id }) {
                    pin(photo.location, at: photo.coordinate)
                }
            case nil:
                if let feature = selection.feature {
                    select(feature)
                }
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            guard !isSaving else { return }
            // Only a camera that has left the pinned spot counts as moving away from it. Setting
            // `position` to where the map already is still reports a change, and that used to
            // throw away a selection the moment it was made.
            let hasLeftPin = center.map {
                MKMapPoint($0).distance(to: MKMapPoint(context.region.center)) >= 1
            } ?? false
            if hasLeftPin, !isFlyingToSelection, !position.followsUserLocation {
                hasMovedMap = true
            }
            if hasLeftPin, pinnedSelection != nil, !isFlyingToSelection {
                withAnimation(.snappy(duration: 0.2)) {
                    pinnedSelection = nil
                }
                mapSelection = nil
            }
            if !isMoving {
                withAnimation(.snappy(duration: 0.2)) { isMoving = true }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard !isSaving else { return }
            withAnimation(.snappy(duration: 0.2)) { isMoving = false }
            isFlyingToSelection = false
            camera = context.camera
            settledRegion = context.region
            settleCamera()
        }
        .onChange(of: LocationManager.shared.lastLocation) {
            if position.followsUserLocation { settleCamera() }
        }
        .overlay {
            pin
                .opacity(isPinHidden ? 0 : 1)
                .allowsHitTesting(false)
        }
        .safeAreaPadding(.bottom, compactCardHeight)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func placeMarker(
        symbol: String,
        tint: Color,
        target: MapTarget
    ) -> some View {
        let isSelected = pinnedSelection?.value == target
        return Image(systemName: symbol)
            .font(.detailEmphasis)
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(tint))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .scaleEffect(isSelected ? 1.2 : 1)
            .animation(.snappy(duration: 0.2), value: isSelected)
    }

    private func photoThumbnail(_ photo: MapPhotoPin) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Group {
            if let thumbnail = photo.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.controlFill
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(shape)
        .overlay(shape.stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .scaleEffect(pinnedSelection?.value == .photo(photo.id) ? 1.2 : 1)
        .animation(.snappy(duration: 0.2), value: pinnedSelection)
    }

    private var pin: some View {
        ZStack {
            Ellipse()
                .fill(Color.progressFill)
                .frame(width: 7, height: 3.5)
                .scaleEffect(isMoving ? 1.3 : 1)

            Image(systemName: "mappin")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .foregroundStyle(.red)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                .offset(y: isMoving ? -23 : -15)
        }
    }

    private var locationCard: some View {
        Card {
            let saved = addressLocation == nil ? nil : savedPlace
            let nearby = addressLocation == nil ? nil : nearbyPlace
            let hasAlternatives = saved != nil || nearby != nil
            let isAddressSelected = hasAlternatives && chosenLocation == addressLocation

            Button {
                choice = .address
            } label: {
                HStack(spacing: 8) {
                    if addressLocation != nil {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.rowIcon)
                            .foregroundStyle(.primary)
                            .frame(width: 15)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let location = addressLocation {
                            Text(location.name)
                                .font(.rowTitle)
                                .lineLimit(2)

                            if let address = location.address {
                                Text(address)
                                    .font(.subtitle)
                                    .foregroundStyle(Color.tertiaryText)
                                    .lineLimit(2)
                            } else if location.needsName {
                                Text("You're offline. The name will be filled in when you're back online.")
                                    .font(.subtitle)
                                    .foregroundStyle(Color.tertiaryText)
                            }
                        } else {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Finding Address…")
                                    .font(.rowTitle)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if addressLocation != nil {
                        Image(systemName: "checkmark")
                            .font(.chevron)
                            .foregroundStyle(Color.accentColor)
                            .opacity(isAddressSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, hasAlternatives ? 12 : 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isAddressSelected ? .isSelected : [])

            if let saved {
                Divider()
                    .padding(.horizontal, 16)

                LocationOptionRow(
                    icon: saved.isFavorite ? "star.fill" : "mappin",
                    title: saved.name,
                    subtitle: saved.isFavorite
                        ? String(localized: "Saved place") : saved.address,
                    isSelected: choice == .saved
                ) {
                    choice = .saved
                }
            }

            if let nearby {
                Divider()
                    .padding(.horizontal, 16)

                LocationOptionRow(
                    icon: nearbySymbol,
                    title: nearby.name,
                    subtitle: String(localized: "Nearby place"),
                    isSelected: choice == .nearby
                ) {
                    choice = .nearby
                }
            }

            if savesOnly {
                let occupying = occupyingFavorite
                let isBlocked = chosenLocation == nil || occupying != nil

                ButtonRow(
                    icon: .customSymbol(occupying == nil ? "star" : "star.fill"),
                    title: occupying == nil
                        ? String(localized: "Save As…") : String(localized: "Already Saved"),
                    tint: isBlocked ? .controlFill : .accentColor,
                    textColor: isBlocked ? .secondary : .white
                ) {
                    guard !isBlocked, let location = chosenLocation, let center else { return }
                    saveName = suggestedSaveName
                    pendingSave = PendingSave(
                        location: location,
                        center: center,
                        existing: selectedSaved
                    )
                    isSaving = true
                }
                .allowsHitTesting(!isBlocked)
            } else {
                DoubleButtonRow(
                    leftIcon: .customSymbol(selectedSaved == nil ? "star" : "pencil"),
                    leftTitle: selectedSaved == nil
                        ? String(localized: "Save As…") : String(localized: "Rename…"),
                    leftAction: {
                        guard let location = chosenLocation, let center else { return }
                        saveName = selectedSaved?.name ?? suggestedSaveName
                        pendingSave = PendingSave(
                            location: location,
                            center: center,
                            existing: selectedSaved
                        )
                        isSaving = true
                    },
                    leftDisabled: selectedSaved == nil && occupyingFavorite != nil,
                    rightIcon: .customSymbol("checkmark", tint: .white),
                    rightTitle: String(localized: "Set Location"),
                    rightTint: .accentColor,
                    rightTextColor: .white,
                    rightAction: {
                        if var location = chosenLocation, let center {
                            location.mapPin = MapPin(center)
                            onSelect(.place(location))
                        }
                    }
                )
                .disabled(chosenLocation == nil)
                .opacity(chosenLocation == nil ? 0.5 : 1)
            }
        }
        .animation(.snappy(duration: 0.3), value: chosenLocation)
        .animation(.snappy(duration: 0.3), value: nearbyPlace)
        .animation(.snappy(duration: 0.3), value: savedPlace?.id)
        .animation(.snappy(duration: 0.3), value: choice)
    }

    private var isCenteredOnUser: Bool {
        if position.followsUserLocation { return true }
        guard let userCenter, let center else { return false }
        return MKMapPoint(userCenter).distance(to: MKMapPoint(center)) < 1
    }

    private func updateCenter(_ cameraCenter: CLLocationCoordinate2D) {
        if let center, MKMapPoint(center).distance(to: MKMapPoint(cameraCenter)) < 1 {
            return
        }

        let coordinate: CLLocationCoordinate2D
        if let restoredMapPin,
            MKMapPoint(restoredMapPin).distance(to: MKMapPoint(cameraCenter)) < 1
        {
            coordinate = restoredMapPin
        } else {
            coordinate = cameraCenter
            if pinnedSelection != nil {
                withAnimation(.snappy(duration: 0.2)) {
                    pinnedSelection = nil
                }
                mapSelection = nil
            }
            featureTask?.cancel()
            restoredMapPin = nil
            restoredNearby = nil
            restoredNearbySymbol = nil
            choice = savedLocation(near: coordinate) == nil ? .address : .saved
        }

        center = coordinate
        placeName = nil
        namingFailed = false
        isNaming = true

        namingTask?.cancel()
        namingTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let result = await PlaceNamer.name(for: coordinate)
            guard !Task.isCancelled else { return }
            placeName = result
            namingFailed = result == nil
            isNaming = false
            if restoredMapPin == nil, choice != .saved, nearbyPlace != nil {
                choice = .nearby
            }
        }

        adoptSavedPlace(at: coordinate)
    }

    /// Opening the picker where a saved place already is — standing at it, most often — should
    /// look like its marker had been tapped: the marker selected and the dropped pin out of the
    /// way, rather than the pin sitting on top of the star. Only until the map is moved, so
    /// panning near a saved place still drops a pin of its own.
    private func adoptSavedPlace(at coordinate: CLLocationCoordinate2D) {
        guard !hasMovedMap, pinnedSelection == nil,
            let saved = savedLocation(near: coordinate),
            savedMarkers.contains(where: { $0.id == saved.id })
        else { return }

        withAnimation(.snappy(duration: 0.2)) {
            pinnedSelection = MapSelection(MapTarget.place(saved.entryLocation))
        }
        mapSelection = pinnedSelection
        pin(saved.entryLocation)
    }

    /// Neighborhood and region labels name an area rather than somewhere you can be at, and they
    /// have no marker of ours to grow. Letting one become the selection would only hide the pin
    /// and leave the card describing the same address, so the tap stays a tap on the map.
    private func standsForAPlace(_ selection: MapSelection<MapTarget>) -> Bool {
        if selection.value != nil { return true }
        return selection.feature?.kind == .pointOfInterest
    }

    private func select(_ feature: MapFeature) {
        let coordinate = feature.coordinate

        featureTask?.cancel()
        restoredMapPin = coordinate
        restoredNearby = nil
        restoredNearbySymbol = nil
        choice = .nearby

        featureTask = Task {
            let item = try? await MKMapItemRequest(feature: feature).mapItem
            guard !Task.isCancelled else { return }
            guard let location = item.flatMap(EntryLocation.init(mapItem:)) else {
                deselectFeature(at: coordinate)
                return
            }
            restoredNearby = location
            restoredNearbySymbol = item?.pointOfInterestCategory?.symbolName
            if let saved = savedLocation(near: coordinate),
                RecentLocationStore.isSamePlace(saved.entryLocation, location)
            {
                choice = .saved
            }
        }

        moveCamera(to: coordinate)
    }

    /// A point of interest that never resolves to a place can't fill the nearby row, so the pin
    /// comes back and the card falls back to the address rather than sitting on an empty choice.
    private func deselectFeature(at coordinate: CLLocationCoordinate2D) {
        withAnimation(.snappy(duration: 0.2)) {
            pinnedSelection = nil
        }
        mapSelection = nil
        if choice == .nearby {
            choice = savedLocation(near: coordinate) == nil ? .address : .saved
        }
    }

    private func pin(_ place: EntryLocation) {
        guard let coordinate = place.coordinate else { return }
        pin(place, at: coordinate)
    }

    private func pin(_ place: EntryLocation?, at coordinate: CLLocationCoordinate2D) {
        featureTask?.cancel()
        restoredMapPin = coordinate
        restoredNearby = place?.mapItemID == nil ? nil : place
        restoredNearbySymbol = restoredNearby.flatMap { resultSymbols[$0] }

        if let place, let saved = savedLocation(near: coordinate),
            RecentLocationStore.isSamePlace(saved.entryLocation, place)
        {
            choice = .saved
        } else {
            choice = restoredNearby == nil ? .address : .nearby
        }

        moveCamera(to: coordinate)
    }

    private func selectSavedResult() {
        guard results.count == 1, let only = results.first, let coordinate = only.coordinate,
            let saved = savedLocation(near: coordinate),
            RecentLocationStore.isSamePlace(saved.entryLocation, only)
        else { return }
        choice = .saved
    }

    private func selectRestoredMarker() {
        guard let restoredMapPin else { return }
        let pinPoint = MKMapPoint(restoredMapPin)
        let isAtPin = { (coordinate: CLLocationCoordinate2D) in
            MKMapPoint(coordinate).distance(to: pinPoint) < 1
        }

        let target: MapTarget
        if let saved = savedMarkers.first(where: {
            isAtPin(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
        }) {
            target = .place(saved.entryLocation)
        } else if let place = markers.first(where: { $0.coordinate.map(isAtPin) ?? false }) {
            target = .place(place)
        } else if let photo = photos.first(where: { isAtPin($0.coordinate) }) {
            target = .photo(photo.id)
        } else {
            return
        }

        pinnedSelection = MapSelection(target)
        mapSelection = pinnedSelection
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        if let center, MKMapPoint(center).distance(to: MKMapPoint(coordinate)) < 1 {
            // Already there — nothing to fly to, and reassigning the camera only risks the
            // selection being read as a move away from it.
            return
        }
        isFlyingToSelection = pinnedSelection != nil
        withAnimation {
            if let camera {
                position = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: camera.distance,
                        heading: camera.heading,
                        pitch: camera.pitch
                    )
                )
            } else {
                position = .region(Self.region(around: coordinate))
            }
        }
    }

    private func searchArea(_ region: MKCoordinateRegion) {
        guard let query else { return }
        guard let searchedRegion else {
            searchedRegion = region
            if results.isEmpty {
                let nearby = MKCoordinateRegion(
                    center: region.center,
                    latitudinalMeters: Self.initialSearchRadius,
                    longitudinalMeters: Self.initialSearchRadius
                )
                runSearch(query, in: nearby, showsResults: true)
            }
            return
        }
        guard Self.hasMovedFar(from: searchedRegion, to: region) else { return }
        self.searchedRegion = region
        runSearch(query, in: region, showsResults: false)
    }

    private func runSearch(_ query: String, in region: MKCoordinateRegion, showsResults: Bool) {
        areaSearchTask?.cancel()
        areaSearchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.pointOfInterest, .address]
            request.region = region
            request.regionPriority = showsResults ? .default : .required
            guard let items = try? await MKLocalSearch(request: request).start().mapItems,
                !Task.isCancelled
            else { return }

            var merged = results
            for item in items {
                guard let place = EntryLocation(mapItem: item),
                    !merged.contains(where: { RecentLocationStore.isSamePlace($0, place) })
                else { continue }
                merged.append(place)
                if let symbol = item.pointOfInterestCategory?.symbolName {
                    resultSymbols[place] = symbol
                }
            }

            while merged.count > Self.resultLimit,
                let index = merged.firstIndex(where: { !Self.region(region, contains: $0) })
            {
                merged.remove(at: index)
            }

            withAnimation(.snappy(duration: 0.3)) {
                results = merged
            }

            guard showsResults else { return }
            if let bounds = Self.bounds(of: merged) {
                withAnimation {
                    position = .rect(bounds)
                }
            } else if let only = merged.first {
                pin(only)
            }
        }
    }

    private static func hasMovedFar(
        from old: MKCoordinateRegion,
        to new: MKCoordinateRegion
    ) -> Bool {
        let latShift = abs(new.center.latitude - old.center.latitude) / old.span.latitudeDelta
        let lonShift = abs(new.center.longitude - old.center.longitude) / old.span.longitudeDelta
        let zoom = new.span.latitudeDelta / old.span.latitudeDelta
        return latShift > 1.0 / 3 || lonShift > 1.0 / 3 || zoom > 2 || zoom < 0.5
    }

    private static func region(_ region: MKCoordinateRegion, contains place: EntryLocation) -> Bool {
        guard let coordinate = place.coordinate else { return false }
        return abs(coordinate.latitude - region.center.latitude) <= region.span.latitudeDelta / 2
            && abs(coordinate.longitude - region.center.longitude) <= region.span.longitudeDelta / 2
    }

    private func savedLocation(near coordinate: CLLocationCoordinate2D) -> SavedLocation? {
        let point = MKMapPoint(coordinate)
        return savedLocations
            .map { saved in
                let savedPoint = MKMapPoint(
                    CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude)
                )
                return (saved, savedPoint.distance(to: point))
            }
            .filter { $0.1 <= PlaceNamer.nearbyRadius }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func settleCamera() {
        guard let region = settledRegion, let camera else { return }
        if position.followsUserLocation {
            guard Self.isNearUser(region.center) else { return }
            position = .camera(camera)
            userCenter = region.center
        }
        searchArea(region)
        updateCenter(region.center)
    }

    private static func isNearUser(_ center: CLLocationCoordinate2D) -> Bool {
        guard let user = LocationManager.shared.lastLocation else { return false }
        let tolerance = max(user.horizontalAccuracy, 200)
        return user.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude)) <= tolerance
    }

    private func centerOnUser() async {
        let manager = LocationManager.shared
        if !manager.isAuthorized {
            guard await manager.requestPermission() == .authorized else { return }
        }
        guard !isCenteredOnUser else { return }
        withAnimation {
            position = .userLocation(fallback: position)
        }
        _ = await manager.currentLocation()
    }

    private func saveAndSelect(_ pending: PendingSave) {
        guard canSave else { return }
        defer { pendingSave = nil }

        if let existing = pending.existing {
            renameAndSelect(existing, at: pending.center)
            return
        }

        do {
            if let occupying = SavedLocation.occupying(pending.location, in: savedLocations) {
                try occupying.rename(to: trimmedSaveName, in: modelContext)
                occupying.isFavorite = true
                try modelContext.save()
                onSelect(.place(pinned(occupying, at: pending.center)))
                return
            }
            guard let saved = try SavedLocation.save(
                named: trimmedSaveName,
                from: pending.location,
                in: modelContext
            ) else {
                toastCenter?.show(
                    .failure(
                        String(localized: "Couldn't Save Location"),
                        message: pending.location.name
                    )
                )
                return
            }
            onSelect(.place(pinned(saved, at: pending.center)))
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Save Location")))
        }
    }

    private func renameAndSelect(_ saved: SavedLocation, at center: CLLocationCoordinate2D) {
        do {
            try saved.rename(to: trimmedSaveName, in: modelContext)
            onSelect(.place(pinned(saved, at: center)))
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Rename Location")))
        }
    }

    /// Naming a place doesn't move the map off it, so the selection leaves carrying the pin it was
    /// made at — the picker opens back at the same spot, and the sheet goes on crediting the map.
    private func pinned(
        _ saved: SavedLocation,
        at center: CLLocationCoordinate2D
    ) -> EntryLocation {
        var location = saved.entryLocation
        location.mapPin = MapPin(center)
        return location
    }
}
