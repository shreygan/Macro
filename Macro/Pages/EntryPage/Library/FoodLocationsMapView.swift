//
//  FoodLocationsMapView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/14/26.
//

import MapKit
import SwiftData
import SwiftUI

struct FoodLocationsMapView: View {
    let food: FoodItem
    var initialPlace: EntryLocation? = nil

    var body: some View {
        FoodLocationsMapContent(food: food, initialPlace: initialPlace)
    }
}

struct ShowOnMapButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Show on Map", systemImage: "map")
                .font(.detailEmphasis)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Color.controlFill))
        }
        .buttonStyle(.plain)
        .padding(.vertical, -2)
        .padding(.trailing, -6)
    }
}

private struct FoodLocationsMapContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.tabBarHeight) private var tabBarHeight

    let food: FoodItem

    @Query private var logs: [LoggedEntry]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var mode: Mode = .locations
    @State private var position: MapCameraPosition
    @State private var cameraDistance: CLLocationDistance?
    @State private var cameraHeading: CLLocationDirection = 0
    @State private var selectedPlace: EntryLocation?
    @State private var cardHeights: [EntryLocation: CGFloat] = [:]
    @State private var framingWidth: CGFloat = 0
    @State private var placeToShow: EntryLocation?
    @State private var viewerGroup: PhotoGroup?
    @State private var viewerSelection: PersistentIdentifier?
    @State private var hasFramed = false
    @State private var isShowingAll = false

    @Namespace private var photoNamespace

    private enum Mode: Hashable {
        case locations, photos
    }

    private struct PhotoGroup: Identifiable {
        let id = UUID()
        let items: [PhotoViewerItem]
        let sourceID: PersistentIdentifier
    }

    private static let placeDistance: CLLocationDistance = 1500
    private static let maxSelectDistance: CLLocationDistance = 4000
    private static let minFramePadding: CLLocationDistance = 500

    init(food: FoodItem, initialPlace: EntryLocation?) {
        self.food = food
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
        _selectedPlace = State(initialValue: initialPlace)
        if let coordinate = initialPlace?.coordinate {
            _position = State(
                initialValue: .camera(
                    MapCamera(centerCoordinate: coordinate, distance: Self.placeDistance)
                )
            )
            _hasFramed = State(initialValue: true)
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    private var cardBottomPadding: CGFloat {
        tabBarHeight > 0 ? tabBarHeight - 8 : 16
    }

    private var places: [FoodPlace] {
        FoodPlace.places(in: logs).filter { $0.location.coordinate != nil }
    }

    private func photoItems(at place: FoodPlace) -> [PhotoViewerItem] {
        PhotoLog.logs(from: place.logs).flatMap { log in
            log.photos.map { PhotoViewerItem(photo: $0, entry: log.entry) }
        }
    }

    private func isDefault(_ location: EntryLocation) -> Bool {
        guard let current = food.defaultLocation else { return false }
        return RecentLocationStore.isSamePlace(current, location)
    }

    private func isSelected(_ place: FoodPlace) -> Bool {
        guard let selectedPlace else { return false }
        return RecentLocationStore.isSamePlace(selectedPlace, place.location)
    }

    var body: some View {
        let places = places
        let selected = mode == .locations ? places.first(where: isSelected) : nil
        let hasPhotos = places.contains { !photoItems(at: $0).isEmpty }

        map(places)
            .safeAreaPadding(.bottom, tabBarHeight)
            .ignoresSafeArea(.container, edges: tabBarHeight > 0 ? .bottom : [])
            .background(alignment: .bottom) {
                ZStack {
                    ForEach(places, id: \.location) { place in
                        placeCard(place)
                            .padding(.horizontal)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                cardHeights[place.location] = height
                            }
                    }
                }
                .hidden()
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                if let selected {
                    placeCard(selected)
                        .padding(.horizontal)
                        .padding(.bottom, cardBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.3), value: selected?.location)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                framingWidth = max(0, width - 32)
            }
            .onAppear {
                if !hasFramed, let framing = framingPosition(for: places) {
                    hasFramed = true
                    position = framing
                    isShowingAll = true
                }
                if selectedPlace == nil, places.count == 1 {
                    selectedPlace = places.first?.location
                }
            }
            .onChange(of: hasPhotos) { _, hasPhotos in
                if !hasPhotos {
                    mode = .locations
                }
            }
            .withGlobalSwipeDismissal()
            .navigationTitle("Locations")
            .navigationSubtitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAll(places)
                    } label: {
                        Image(systemName: "map")
                            .symbolVariant(isShowingAll ? .fill : .none)
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.default, value: isShowingAll)
                    }
                    .accessibilityLabel("Show All")
                    .accessibilityAddTraits(isShowingAll ? .isSelected : [])

                    if hasPhotos {
                        modeMenu
                    }
                }
            }
            .navigationDestination(item: $placeToShow) { place in
                FoodLogsView(food: food, place: place, showsMapButton: false)
            }
            .fullScreenCover(item: $viewerGroup) { group in
                PhotoViewer(items: group.items, selection: $viewerSelection)
                    .navigationTransition(.zoom(sourceID: group.sourceID, in: photoNamespace))
            }
    }

    private var modeMenu: some View {
        Menu {
            Picker("Show", selection: $mode) {
                Label("Locations", systemImage: "mappin.and.ellipse").tag(Mode.locations)
                Label("Photos", systemImage: "photo.on.rectangle").tag(Mode.photos)
            }
        } label: {
            Label(
                "Show",
                systemImage: mode == .locations ? "mappin.and.ellipse" : "photo.on.rectangle"
            )
        }
    }

    private func map(_ places: [FoodPlace]) -> some View {
        MapReader { proxy in
            mapContent(places, proxy: proxy)
                .onTapGesture { point in
                    deselect(tappedAt: point, places: places, proxy: proxy)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10).onChanged { _ in leaveShowAll() }
                )
                .simultaneousGesture(MagnifyGesture().onChanged { _ in leaveShowAll() })
                .simultaneousGesture(RotateGesture().onChanged { _ in leaveShowAll() })
                .simultaneousGesture(TapGesture(count: 2).onEnded { leaveShowAll() })
        }
    }

    private func leaveShowAll() {
        if isShowingAll {
            isShowingAll = false
        }
    }

    private func mapContent(_ places: [FoodPlace], proxy: MapProxy) -> some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(places, id: \.location) { place in
                if let coordinate = place.location.coordinate {
                    switch mode {
                    case .locations:
                        Annotation(place.location.name, coordinate: coordinate, anchor: .center) {
                            Button {
                                select(place, proxy: proxy)
                            } label: {
                                countMarker(place)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(place.location.name)
                            .accessibilityValue(logCountText(place.logs.count))
                        }

                    case .photos:
                        let items = photoItems(at: place)
                        if let cover = items.first {
                            Annotation(place.location.name, coordinate: coordinate, anchor: .center) {
                                Button {
                                    viewerSelection = cover.id
                                    viewerGroup = PhotoGroup(items: items, sourceID: cover.id)
                                } label: {
                                    photoMarker(cover.photo, count: items.count)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: cover.id, in: photoNamespace)
                                .accessibilityLabel(place.location.name)
                                .accessibilityValue(photoCountText(items.count))
                            }
                        }
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
        }
        .mapFeatureSelectionDisabled { _ in true }
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraDistance = context.camera.distance
            cameraHeading = context.camera.heading
        }
        .onChange(of: mode) {
            selectedPlace = nil
        }    }

    private func countMarker(_ place: FoodPlace) -> some View {
        let count = place.logs.count
        let isSelected = isSelected(place)
        return Text(count > 99 ? "99+" : count.formatted())
            .font(.detailEmphasis)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 24)
            .background(Capsule().fill(isDefault(place.location) ? Color.accentColor : .red))
            .overlay(Capsule().stroke(.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .scaleEffect(isSelected ? 1.2 : 1)
            .animation(.snappy(duration: 0.2), value: isSelected)
            .padding(4)
            .contentShape(Rectangle())
    }

    private func photoMarker(_ photo: EntryPhoto, count: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return EntryPhotoImage(photo: photo, framingWidth: framingWidth)
            .frame(width: 40, height: 40)
            .clipShape(shape)
            .overlay(shape.stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text(count > 99 ? "99+" : count.formatted())
                        .font(.tag)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(.red))
                        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                }
            }
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
    }

    private func placeCard(_ place: FoodPlace) -> some View {
        Card {
            FoodPlaceRow(
                food: food,
                place: place,
                servingUnits: portionUnitOptions,
                usualPortion: PortionKey.usual(in: logs),
                onSelect: { placeToShow = $0 },
                onSetDefault: {
                    setDefaultLocation(
                        $0,
                        for: food,
                        in: modelContext,
                        toastCenter: toastCenter
                    )
                }
            )

            ButtonRow(
                icon: .customSymbol("map"),
                title: String(localized: "Open in Maps"),
                topPadding: 0
            ) {
                Task { await place.location.openInMaps() }
            }
        }
    }

    private func logCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 log") : String(localized: "\(count) logs")
    }

    private func photoCountText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 photo") : String(localized: "\(count) photos")
    }

    private func select(_ place: FoodPlace, proxy: MapProxy) {
        guard !isSelected(place) else {
            selectedPlace = nil
            return
        }
        selectedPlace = place.location
        guard let coordinate = place.location.coordinate else { return }
        isShowingAll = false
        let currentDistance = cameraDistance ?? Self.placeDistance
        let distance = min(currentDistance, Self.maxSelectDistance)
        let center = cardClearingCenter(
            for: coordinate,
            cardHeight: cardHeights[place.location] ?? 0,
            zoomScale: distance / currentDistance,
            proxy: proxy
        )
        withAnimation(.snappy(duration: 0.4)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: distance,
                    heading: cameraHeading
                )
            )
        }
    }

    private func cardClearingCenter(
        for coordinate: CLLocationCoordinate2D,
        cardHeight: CGFloat,
        zoomScale: Double,
        proxy: MapProxy
    ) -> CLLocationCoordinate2D {
        guard let pinPoint = proxy.convert(coordinate, to: .local),
            let shifted = proxy.convert(
                CGPoint(
                    x: pinPoint.x,
                    y: pinPoint.y + (cardHeight + cardBottomPadding - tabBarHeight) / 2
                ),
                from: .local
            )
        else { return coordinate }
        let pin = MKMapPoint(coordinate)
        let offset = MKMapPoint(shifted)
        return MKMapPoint(
            x: pin.x + (offset.x - pin.x) * zoomScale,
            y: pin.y + (offset.y - pin.y) * zoomScale
        ).coordinate
    }

    private func deselect(tappedAt point: CGPoint, places: [FoodPlace], proxy: MapProxy) {
        guard selectedPlace != nil else { return }
        let hitsMarker = places.contains { place in
            guard let coordinate = place.location.coordinate,
                let markerPoint = proxy.convert(coordinate, to: .local)
            else { return false }
            return hypot(markerPoint.x - point.x, markerPoint.y - point.y) < 24
        }
        guard !hitsMarker else { return }
        selectedPlace = nil
    }

    private func showAll(_ places: [FoodPlace]) {
        guard let framing = framingPosition(for: places) else { return }
        if places.count > 1 {
            selectedPlace = nil
        }
        isShowingAll = true
        withAnimation(.easeInOut(duration: 0.5)) {
            position = framing
        }
    }

    private func framingPosition(for places: [FoodPlace]) -> MapCameraPosition? {
        let coordinates = places.compactMap(\.location.coordinate)
        guard let first = coordinates.first else { return nil }

        guard coordinates.count > 1 else {
            return .camera(MapCamera(centerCoordinate: first, distance: Self.placeDistance))
        }

        let bounds = coordinates.dropFirst().reduce(
            MKMapRect(origin: MKMapPoint(first), size: MKMapSize())
        ) { rect, coordinate in
            rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize()))
        }
        let minPadding =
            Self.minFramePadding * MKMapPointsPerMeterAtLatitude(first.latitude)
        let padded = bounds.insetBy(
            dx: -max(bounds.width * 0.2, minPadding),
            dy: -max(bounds.height * 0.2, minPadding)
        )
        return .rect(padded)
    }
}
