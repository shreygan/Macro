//
//  LocationPickerSheet.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import MapKit
import SwiftData
import SwiftUI

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    @Binding var selection: LocationSelection
    var foodID: UUID? = nil
    var photos: [LoggedPhoto] = []
    var logDate: Date? = nil
    var isAddingSaved = false
    var nearby: NearbyPlaceSearch? = nil
    var defaultFor: FoodItem? = nil

    @Query(sort: \SavedLocation.displayOrder) private var savedLocations: [SavedLocation]
    @Query(sort: \RecentLocation.lastUsed, order: .reverse)
    private var recentLocations: [RecentLocation]

    @State private var search = LocationSearch()
    @State private var searchText = ""
    @State private var previousPlaces: [PreviousPlace] = []
    @State private var resolvingResult: MKLocalSearchCompletion?
    @State private var path: [Route] = []
    @State private var showReorderSheet = false
    @State private var nameEdit: NameEdit?
    @State private var isNamingPlace = false
    @State private var nameText = ""
    @State private var isResolvingCurrent = false
    @State private var photoPlaces: [PhotoPlace] = []
    @State private var photoThumbnails: [UUID: UIImage] = [:]
    @State private var nearbyResults: [NearbyPlace]?
    @State private var selectionOnDismissal: LocationSelection?

    private static let recentLocationLimit = 5

    private enum Route: Hashable {
        case map
        case results(query: String, places: [EntryLocation])
        case manageSaved
        case adjustOnMap(EntryLocation)
        case allRecents
    }

    private struct NameEdit {
        enum Mode {
            case save, rename
        }

        var location: EntryLocation
        var mode: Mode
        var existing: SavedLocation?
    }

    private struct LocationAction: Identifiable {
        let id: String
        var icon: String
        var iconTint: Color = .primary
        var title: String
        var subtitle: String? = nil
        var isDestructive = false
        var action: () -> Void
    }

    private struct NearbyRequest: Equatable {
        let search: NearbyPlaceSearch?
        let permission: LocationManager.Permission
        let isReducedAccuracy: Bool
    }

    /// Somewhere this food has been logged, and the last time it was. The fetch runs newest-first
    /// and keeps the first row each place appears in, so the date it arrives with is that place's
    /// most recent one.
    private struct PreviousPlace: Hashable {
        let location: EntryLocation
        let lastLogged: Date
    }

    private struct PhotoPlace: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let image: UIImage
        let capturedAt: Date?
        var location: EntryLocation?
    }

    private static let photoClusterRadius: CLLocationDistance = 50
    private static var cachedThumbnails: [UUID: UIImage] = [:]

    private var locationManager: LocationManager { .shared }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nearbyRequest: NearbyRequest {
        NearbyRequest(
            search: nearby,
            permission: locationManager.permission,
            isReducedAccuracy: locationManager.isReducedAccuracy
        )
    }

    /// The sheet's own search once it has landed, and until then whatever a warm-up already
    /// found for where we are — a card the cache can fill is on screen from the first frame
    /// instead of sliding in a beat after the sheet settles.
    private var nearbyResolved: [NearbyPlace] {
        if let nearbyResults { return nearbyResults }
        guard let nearby, !isAddingSaved, let origin = placeOrigin else { return [] }
        return NearbyPlaceCache.shared.cached(for: nearby, near: origin) ?? []
    }

    private var nearbyPlaces: [EntryLocation] {
        let places = nearbyResolved
        // A lone branch that's already the selection says nothing the sheet isn't saying.
        if places.count == 1, isSelected(places[0].location) { return [] }
        return places.map(\.location)
    }

    private var nearbySymbols: [EntryLocation: String] {
        Dictionary(
            nearbyResolved.compactMap { place in place.symbol.map { (place.location, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var favoriteLocations: [SavedLocation] {
        savedLocations.filter(\.isFavorite)
    }

    private var recents: [EntryLocation] {
        let favorites = favoriteLocations.map(\.entryLocation)
        return recentLocations.map(\.location).filter { recent in
            (!isAddingSaved || recent.hasCoordinate)
                && !favorites.contains { RecentLocationStore.isSamePlace($0, recent) }
        }
    }

    /// What Recents has left to say once the cards above it have had their turn. Every log writes
    /// a recent, so anywhere this food has been logged is already up the page under a heading that
    /// says more about it — Recents is for everywhere else you've been. Search still looks through
    /// all of them, since a place you can't see is a place you'd want to type the name of.
    private var otherRecents: [EntryLocation] {
        recents.filter { recent in
            !previousPlaces.contains { RecentLocationStore.isSamePlace($0.location, recent) }
        }
    }

    private var matchingLocations: [EntryLocation] {
        let query = FoodSearch(trimmedQuery)
        var candidates: [EntryLocation] = isAddingSaved ? [] : savedLocations.map(\.entryLocation)
        for recent in recents
        where !candidates.contains(where: { RecentLocationStore.isSamePlace($0, recent) }) {
            candidates.append(recent)
        }
        return candidates.filter {
            query.matches(name: $0.name, fields: [$0.address])
        }
    }

    /// The selection as the sheet shows it. Picking writes through the binding while the sheet
    /// is still on screen, so rows and cards keyed to the selection would pop in or out a beat
    /// before it slides away. Everything on screen keeps reading the selection as it was on tap.
    private var shownSelection: LocationSelection {
        selectionOnDismissal ?? selection
    }

    /// The place the selection stands for, under the name any saved record gives it. Read from
    /// the stored selection rather than `resolvedLocation`, so a Current Location still waiting
    /// on its reverse-geocode doesn't show a half-named place.
    private var selectedPlace: EntryLocation? {
        guard !isAddingSaved else { return nil }
        let stored: EntryLocation? =
            switch shownSelection {
            case .none: nil
            case .place(let place): place
            case .current(let place): place
            }
        guard let stored else { return nil }
        return namedMatch(for: stored).map { resolved($0, keeping: stored) } ?? stored
    }

    private func isDefaultLocation(_ location: EntryLocation) -> Bool {
        guard let stored = defaultFor?.defaultLocation else { return false }
        return RecentLocationStore.isSamePlace(stored, location)
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCommitName: Bool {
        !trimmedName.isEmpty
            && !savedLocations.contains {
                $0.id != nameEdit?.existing?.id
                    && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            }
    }

    private var nameAlertTitle: LocalizedStringKey {
        nameEdit?.mode == .rename ? "Rename Place" : "Save Location"
    }

    private var nameAlertMessage: LocalizedStringKey {
        nameEdit?.mode == .rename
            ? "Apply a custom name to this location instead of the map’s default."
            : "Name this place, like Home or Work."
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        if trimmedQuery.isEmpty {
                            idleContent
                        } else {
                            searchContent
                        }
                    }
                    .animation(.snappy(duration: 0.3), value: trimmedQuery.isEmpty)
                    .animation(.snappy(duration: 0.3), value: search.places)
                    .animation(.snappy(duration: 0.3), value: search.completions)
                    .animation(.snappy(duration: 0.3), value: search.expandedTitle)
                    .animation(.snappy(duration: 0.3), value: search.hasFinished)
                }
                .tabBarScrollInsets(ignoring: .container)
                .scrollDismissesKeyboard(.immediately)
            }
            .withGlobalSwipeDismissal()
            .navigationTitle(isAddingSaved ? "Add Saved Location" : "Location")
            .navigationSubtitle(defaultFor?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search places or addresses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .map:
                    MapPinPickerView(
                        initialSelection: selection,
                        savesOnly: isAddingSaved,
                        photos: mapPhotoPins
                    ) {
                        if isAddingSaved {
                            dismiss()
                        } else {
                            select($0)
                        }
                    }
                case .results(let query, let places):
                    MapPinPickerView(
                        initialSelection: selection,
                        savesOnly: isAddingSaved,
                        query: query,
                        results: places,
                        resultSymbols: search.placeSymbols.merging(nearbySymbols) { current, _ in
                            current
                        },
                        photos: mapPhotoPins
                    ) {
                        if isAddingSaved {
                            dismiss()
                        } else {
                            select($0)
                        }
                    }
                case .manageSaved:
                    ManageSavedLocationsView(allowsAdding: false)
                case .adjustOnMap(let location):
                    MapPinPickerView(initialSelection: .place(location), photos: mapPhotoPins) {
                        select($0)
                    }
                case .allRecents:
                    allRecentsContent
                }
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderSavedLocationsView()
        }
        .alert(nameAlertTitle, isPresented: $isNamingPlace) {
            TextField("Name", text: $nameText)
                .textInputAutocapitalization(.words)
            Button("Save", action: commitName)
                .disabled(!canCommitName)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(nameAlertMessage)
        }
        .onChange(of: searchText) { _, newValue in
            search.query = newValue
        }
        .onChange(of: savedLocations.map(\.entryLocation)) {
            loadPreviousPlaces()
        }
        .task {
            loadPreviousPlaces()
            await biasSearch()
        }
        .task(id: photos.map(\.id)) {
            await loadPhotoPlaces()
        }
        .task(id: nearbyRequest) {
            await loadNearbyPlaces()
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        Card {
            RowGroup(.divider) {
                currentLocationRow

                LocationOptionRow(
                    icon: "map",
                    title: String(localized: "Choose on Map"),
                    subtitle: mapSubtitle,
                    isSelected: shownSelection.mapPin != nil,
                    reservesCheckmarkSpace: false
                ) {
                    path.append(.map)
                }

                if !shownSelection.isNone {
                    LocationOptionRow(
                        icon: "location.slash",
                        iconTint: .red,
                        title: String(localized: "Remove Location")
                    ) {
                        select(.none)
                    }
                }
            }
        }
        .padding(.horizontal)

        if let place = selectedPlace {
            let actions = selectionActions(for: place, selectsOnDefault: false)
            if !actions.isEmpty {
                Card(place.name) {
                    RowGroup(.divider) {
                        ForEach(actions) { action in
                            LocationOptionRow(
                                icon: action.icon,
                                iconTint: action.iconTint,
                                title: action.title,
                                subtitle: action.subtitle,
                                reservesCheckmarkSpace: false,
                                action: action.action
                            )
                        }
                    }
                }
                .padding([.top, .horizontal])
            }
        }

        if !photoPlaces.isEmpty {
            Card(String(localized: "From Your Photos")) {
                RowGroup(.divider) {
                    ForEach(photoPlaces) { place in
                        photoPlaceRow(place)
                    }
                }
            }
            .padding([.top, .horizontal])
        }

        if let nearby, !nearbyPlaces.isEmpty {
            Card(String(localized: "Nearby")) {
                RowGroup(.divider) {
                    ForEach(nearbyPlaces, id: \.self) { place in
                        locationRow(
                            place,
                            icon: favoriteMatch(for: place) != nil
                                ? "star.fill" : nearbySymbols[place] ?? "mappin",
                            subtitle: distanceSubtitle(for: place)
                        )
                    }
                }
            } headerAccessory: {
                let mappable = nearbyPlaces.filter(\.hasCoordinate)
                if !mappable.isEmpty {
                    showOnMapButton(mappable, query: nearby.name)
                }
            }
            .padding([.top, .horizontal])
        }

        if !previousPlaces.isEmpty {
            Card(String(localized: "Previously Logged At")) {
                RowGroup(.divider) {
                    ForEach(previousPlaces, id: \.self) { place in
                        locationRow(
                            place.location,
                            icon: favoriteMatch(for: place.location) != nil
                                ? "star.fill" : "clock.arrow.circlepath",
                            subtitle: loggedSubtitle(for: place)
                        )
                    }
                }
            }
            .padding([.top, .horizontal])
        }

        if !isAddingSaved && !favoriteLocations.isEmpty {
            Card(String(localized: "Saved")) {
                RowGroup(.divider) {
                    ForEach(favoriteLocations) { saved in
                        locationRow(saved.entryLocation, icon: "star.fill")
                    }
                }
            } headerAccessory: {
                savedMenu
            }
            .padding([.top, .horizontal])
        }

        if !otherRecents.isEmpty {
            Card(String(localized: "Recents")) {
                RowGroup(.divider, isLazy: true) {
                    ForEach(otherRecents.prefix(Self.recentLocationLimit), id: \.self) { location in
                        locationRow(
                            location,
                            icon: "clock",
                            onForget: { deleteRecent(location) }
                        )
                    }
                } bottomContent: {
                    if otherRecents.count > Self.recentLocationLimit {
                        Divider()
                            .padding(.horizontal, 16)

                        ButtonRow(
                            icon: .customSymbol("clock"),
                            title: String(localized: "See All Recents (\(otherRecents.count))")
                        ) {
                            path.append(.allRecents)
                        }
                    }
                }
            }
            .padding([.top, .horizontal])
        }
    }

    private var allRecentsContent: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                Card {
                    RowGroup(.divider, isLazy: true) {
                        if otherRecents.isEmpty {
                            BaseRowLayout(
                                icon: .customSymbol("clock"),
                                title: String(localized: "No Recent Places"),
                                subtitle: String(
                                    localized: "Places you log at show up here, newest first."
                                )
                            ) {
                                EmptyView()
                            }
                        }

                        ForEach(otherRecents, id: \.self) { location in
                            locationRow(
                                location,
                                icon: "clock",
                                onForget: { deleteRecent(location) }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .tabBarScrollInsets(ignoring: .container)
        }
        .withGlobalSwipeDismissal()
        .navigationTitle("Recents")
        .navigationSubtitle("^[\(otherRecents.count) place](inflect: true)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var searchContent: some View {
        if !isAddingSaved {
            Card {
                LocationOptionRow(
                    icon: "text.cursor",
                    title: String(localized: "Use “\(trimmedQuery)”")
                ) {
                    select(.place(EntryLocation(name: trimmedQuery)))
                }
            }
            .padding(.horizontal)
        }

        let matches = matchingLocations
        if !matches.isEmpty {
            Card(String(localized: "Your Locations")) {
                RowGroup(.divider) {
                    ForEach(matches, id: \.self) { location in
                        locationRow(
                            location,
                            icon: favoriteMatch(for: location) != nil ? "star.fill" : "clock",
                            subtitle: distanceSubtitle(for: location)
                        )
                    }
                }
            }
            .padding(isAddingSaved ? .horizontal : [.top, .horizontal])
        }

        let resultsPadding: Edge.Set =
            isAddingSaved && matches.isEmpty ? .horizontal : [.top, .horizontal]
        let places = search.places.filter { place in
            !matches.contains { RecentLocationStore.isSamePlace($0, place) }
        }
        if search.didFail && search.places.isEmpty {
            Card(String(localized: "Results")) {
                BaseRowLayout(
                    icon: .customSymbol("wifi.slash"),
                    title: String(localized: "Search Unavailable"),
                    subtitle: isAddingSaved
                        ? String(localized: "Check your connection, or choose the place on the map.")
                        : String(localized: "Check your connection, or use the name as typed.")
                ) {
                    EmptyView()
                }
            }
            .padding(resultsPadding)
        } else if !places.isEmpty || !search.completions.isEmpty {
            Card(
                search.expandedTitle
                    ?? (photoOrigin != nil
                        ? String(localized: "Near Your Photo")
                        : String(localized: "Results"))
            ) {
                RowGroup(.divider, isLazy: true) {
                    ForEach(places, id: \.self) { place in
                        locationRow(
                            place,
                            icon: favoriteMatch(for: place) != nil
                                ? "star.fill" : search.placeSymbols[place] ?? "mappin",
                            subtitle: distanceSubtitle(for: place)
                        )
                        .disabled(resolvingResult != nil)
                    }

                    ForEach(search.completions, id: \.self) { result in
                        resultRow(result)
                            .disabled(resolvingResult != nil)
                    }
                }
            } headerAccessory: {
                let mappable = search.places.filter(\.hasCoordinate)
                if !mappable.isEmpty || !search.hasFinished {
                    showOnMapButton(mappable, query: search.expandedTitle ?? trimmedQuery)
                }
            }
            .padding(resultsPadding)
        } else if search.hasFinished && matches.isEmpty {
            Card(String(localized: "Results")) {
                LocationOptionRow(
                    icon: "map",
                    title: String(localized: "Choose on Map"),
                    subtitle: String(localized: "No places found for “\(trimmedQuery)”"),
                    reservesCheckmarkSpace: false
                ) {
                    path.append(.map)
                }
            }
            .padding(resultsPadding)
        }
    }

    private var savedMenu: some View {
        Menu {
            Button("Edit", systemImage: "pencil") {
                path.append(.manageSaved)
            }

            Button("Reorder", systemImage: "arrow.up.arrow.down") {
                showReorderSheet = true
            }
            .disabled(favoriteLocations.count < 2)
        } label: {
            Image(systemName: "ellipsis")
                .font(.menuIcon)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.controlFill))
        }
        .buttonStyle(.plain)
        .padding(.vertical, -2)
        .padding(.trailing, -6)
        .accessibilityLabel("Saved Location Options")
    }

    private func showOnMapButton(_ places: [EntryLocation], query: String) -> some View {
        ShowOnMapButton {
            path.append(.results(query: query, places: places))
        }
    }

    private var currentLocationRow: some View {
        let subtitle: String? =
            switch locationManager.permission {
            case .denied, .restricted:
                String(localized: "Turn on location access in Settings")
            case .notDetermined:
                nil
            case .authorized:
                shownSelection.currentPlaceName
            }

        return LocationOptionRow(
            icon: "location.fill",
            iconTint: .accentColor,
            title: String(localized: "Current Location"),
            subtitle: subtitle,
            isSelected: isAddingSaved ? nil : shownSelection.isCurrent,
            reservesCheckmarkSpace: false,
            isLoading: isResolvingCurrent
        ) {
            if isAddingSaved {
                addCurrentLocation()
            } else {
                chooseCurrentLocation()
            }
        }
        .disabled(isResolvingCurrent)
    }

    /// A query row ("coffee", "pizza") stands for a search, so it reads as one — a magnifying
    /// glass and a chevron, not a pin — and it only ever widens the results. Saving or renaming
    /// would have to pick a place on your behalf, so neither is offered here.
    private func resultRow(_ result: MKLocalSearchCompletion) -> some View {
        let isQuery = search.isQuery(result)
        let row = LocationOptionRow(
            icon: isQuery ? "magnifyingglass" : "mappin",
            title: result.title,
            subtitle: result.subtitle.isEmpty
                ? (isQuery ? String(localized: "Search nearby") : nil) : result.subtitle,
            isLoading: resolvingResult == result,
            showsChevron: isQuery
        ) {
            if isQuery {
                expand(result)
            } else if isAddingSaved {
                save(result)
            } else {
                choose(result)
            }
        }
        .frame(minHeight: 72)

        return CustomSwipeRow(
            content: { row },
            onFavorite: isAddingSaved || isQuery ? nil : { save(result) },
            favoriteTitle: "Save"
        )
        .contextMenu {
            if !isAddingSaved && !isQuery {
                Button("Rename…", systemImage: "pencil") {
                    rename(result)
                }

                Button("Save Location…", systemImage: "star") {
                    save(result)
                }
            }
        }
    }

    private var mapPhotoPins: [MapPhotoPin] {
        photoPlaces.map { place in
            MapPhotoPin(
                id: place.id,
                coordinate: place.coordinate,
                thumbnail: photoThumbnails[place.id],
                location: place.location
            )
        }
    }

    /// A pin that stands for somewhere — a saved place or a map result — is worth naming. Only a
    /// bare one falls back to its address, since "Dropped Pin" would say nothing.
    private var mapSubtitle: String? {
        guard case .place(let location) = shownSelection, location.mapPin != nil else {
            return nil
        }
        let named = namedMatch(for: location).map { resolved($0, keeping: location) } ?? location
        if named.savedLocationID != nil || named.mapItemID != nil { return named.name }
        return named.address ?? named.name
    }

    @ViewBuilder
    private func photoPlaceRow(_ place: PhotoPlace) -> some View {
        let thumbnail = photoThumbnails[place.id].map(RowThumbnail.image) ?? .placeholder

        Group {
            if let location = place.location {
                locationRow(
                    location,
                    icon: "photo",
                    subtitle: photoSubtitle(for: place, address: location.address),
                    thumbnail: thumbnail,
                    onAdjust: { adjustOnMap(place, from: location) }
                )
            } else {
                LocationOptionRow(
                    icon: "photo",
                    title: String(localized: "Finding Place…"),
                    subtitle: String(localized: "Looking up where this photo was taken"),
                    thumbnail: thumbnail
                ) {}
                .redacted(reason: .placeholder)
                .frame(minHeight: 72)
                .allowsHitTesting(false)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func locationRow(
        _ place: EntryLocation,
        icon: String,
        subtitle: String? = nil,
        thumbnail: RowThumbnail? = nil,
        onAdjust: (() -> Void)? = nil,
        onForget: (() -> Void)? = nil
    ) -> some View {
        // A fresh map result doesn't know it's been named, so the row stands for the saved
        // record wherever one covers this place — title, selection and all.
        let named = namedMatch(for: place)
        let location = named.map { resolved($0, keeping: place) } ?? place
        let saved = named?.isFavorite == true ? named : nil
        let row = LocationOptionRow(
            icon: icon,
            title: location.name,
            subtitle: subtitle ?? location.address,
            isSelected: isAddingSaved ? nil : isSelected(location),
            reservesCheckmarkSpace: false,
            thumbnail: thumbnail
        ) {
            if isAddingSaved {
                startSave(location)
            } else {
                select(.place(location))
            }
        }

        // Saving needs somewhere to put the pin, so a place that is only a typed name can't be
        // saved — but it can still be made the default, and that has to be reachable from the row.
        let actions = selectionActions(for: location, selectsOnDefault: true)
        let canSave = saved != nil || location.hasCoordinate
        let hasSwipeActions = canSave || onAdjust != nil || onForget != nil

        if isAddingSaved {
            row.frame(minHeight: 72)
        } else if hasSwipeActions {
            CustomSwipeRow(
                content: { row.frame(minHeight: 72) },
                onDelete: onForget,
                onEdit: onAdjust,
                editTitle: "Adjust",
                onFavorite: canSave
                    ? {
                        if let saved {
                            unsave(saved)
                        } else {
                            startSave(location)
                        }
                    }
                    : nil,
                isFavorited: saved != nil,
                favoriteTitle: "Save",
                unfavoriteTitle: "Unsave"
            )
            .contextMenu {
                if let onAdjust {
                    Button("Adjust on Map", systemImage: "mappin.and.ellipse", action: onAdjust)
                }

                menuItems(for: actions)

                if let onForget {
                    Button("Remove from Recents", systemImage: "clock.badge.xmark", action: onForget)
                }
            }
        } else if !actions.isEmpty {
            row.contextMenu {
                menuItems(for: actions)
            }
        } else {
            row
        }
    }

    private func deleteRecent(_ location: EntryLocation) {
        do {
            try withAnimation {
                try RecentLocationStore.delete(location, in: modelContext)
            }
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Remove Recent"), message: location.name)
            )
        }
    }

    /// One description of everything you can do to a place, rendered both as rows under the
    /// selected place's card and as items in each row's context menu, so the two can't drift.
    ///
    /// Nothing here names the place or the food in its title — the card header and the row the
    /// menu belongs to already say which place, and the food is the same for the whole sheet.
    private func selectionActions(
        for location: EntryLocation,
        selectsOnDefault: Bool
    ) -> [LocationAction] {
        guard !isAddingSaved else { return [] }
        let named = namedMatch(for: location)
        let saved = named?.isFavorite == true ? named : nil
        var actions: [LocationAction] = []

        if location.hasCoordinate || named != nil {
            actions.append(
                LocationAction(id: "rename", icon: "pencil", title: String(localized: "Rename…")) {
                    startRename(location)
                }
            )
        }

        if let named, let mapName = named.mapName {
            actions.append(
                LocationAction(
                    id: "mapName",
                    icon: "arrow.uturn.backward",
                    title: String(localized: "Use Map’s Name"),
                    subtitle: mapName
                ) {
                    useMapName(named, at: location)
                }
            )
        }

        // A default has to stand on its own every time it's read, so an unresolved Current
        // Location or a pin still waiting on a name can't become one.
        if let food = defaultFor, !location.needsName {
            if isDefaultLocation(location) {
                actions.append(
                    LocationAction(
                        id: "clearDefault",
                        icon: "pin.slash",
                        title: String(localized: "Stop Using Here by Default"),
                        subtitle: String(localized: "“\(food.name)” won’t have a default location")
                    ) {
                        setDefaultLocation(nil, for: food)
                    }
                )
            } else {
                actions.append(
                    LocationAction(
                        id: "setDefault",
                        icon: "pin",
                        title: String(localized: "Use Here by Default"),
                        subtitle: food.defaultLocation.map {
                            String(localized: "Replaces “\($0.name)”")
                        } ?? String(localized: "For “\(food.name)”")
                    ) {
                        setDefaultLocation(location, for: food)
                        if selectsOnDefault {
                            select(.place(location))
                        }
                    }
                )
            }
        }

        if let saved {
            actions.append(
                LocationAction(
                    id: "unsave",
                    icon: "trash",
                    iconTint: .red,
                    title: String(localized: "Delete Saved Location"),
                    isDestructive: true
                ) {
                    unsave(saved)
                }
            )
        } else if location.hasCoordinate {
            actions.append(
                LocationAction(id: "save", icon: "star", title: String(localized: "Save Location…")) {
                    startSave(location)
                }
            )
        }

        return actions
    }

    @ViewBuilder
    private func menuItems(for actions: [LocationAction]) -> some View {
        ForEach(actions) { action in
            Button(role: action.isDestructive ? .destructive : nil, action: action.action) {
                Label(action.title, systemImage: action.icon)

                if let subtitle = action.subtitle {
                    Text(subtitle)
                }
            }
        }
    }

    private func namedMatch(for location: EntryLocation) -> SavedLocation? {
        SavedLocation.linked(location, in: savedLocations)
    }

    private func favoriteMatch(for location: EntryLocation) -> SavedLocation? {
        let match = namedMatch(for: location)
        return match?.isFavorite == true ? match : nil
    }

    private func resolved(_ saved: SavedLocation, keeping place: EntryLocation) -> EntryLocation {
        var named = saved.entryLocation
        named.mapPin = place.mapPin
        return named
    }

    private func addCurrentLocation() {
        Task {
            if locationManager.permission == .notDetermined {
                guard await locationManager.requestPermission() == .authorized else { return }
            }
            guard locationManager.isAuthorized else {
                locationManager.openSettings()
                return
            }

            isResolvingCurrent = true
            defer { isResolvingCurrent = false }

            guard let fix = await locationManager.currentLocation(),
                let place = await PlaceNamer.name(for: fix.coordinate)
            else {
                toastCenter?.show(.failure(String(localized: "Couldn't Find Current Location")))
                return
            }
            startSave(place.location)
        }
    }

    private func startSave(_ location: EntryLocation) {
        let occupying = SavedLocation.occupying(location, in: savedLocations)
        if let occupying, occupying.isFavorite {
            toastCenter?.show(
                .info(
                    String(localized: "Already Saved"),
                    message: occupying.name,
                    symbol: "star.fill"
                )
            )
            return
        }
        nameEdit = NameEdit(location: location, mode: .save, existing: occupying)
        nameText = occupying?.name ?? location.name
        isNamingPlace = true
    }

    private func startRename(_ location: EntryLocation) {
        let existing = namedMatch(for: location)
        nameEdit = NameEdit(location: location, mode: .rename, existing: existing)
        nameText = existing?.name ?? location.name
        isNamingPlace = true
    }

    /// Saving or renaming needs one place, and a row with several branches behind it hasn't
    /// named one yet. The results widen to the branches, so the toast says which to act on.
    private func multipleMatchesMessage(for result: MKLocalSearchCompletion) -> String {
        String(localized: "“\(result.title)” matches more than one place. Choose one below.")
    }

    private func rename(_ result: MKLocalSearchCompletion) {
        resolvingResult = result
        Task {
            let resolution = await search.resolve(result)
            resolvingResult = nil
            switch resolution {
            case .place(let location):
                startRename(location)
            case .expanded:
                toastCenter?.show(
                    .info(
                        String(localized: "Pick a Place to Rename"),
                        message: multipleMatchesMessage(for: result),
                        symbol: "mappin.and.ellipse"
                    )
                )
            case .failed:
                toastCenter?.show(
                    .failure(String(localized: "Couldn't Rename Location"), message: result.title)
                )
            }
        }
    }

    private func save(_ result: MKLocalSearchCompletion) {
        resolvingResult = result
        Task {
            let resolution = await search.resolve(result)
            resolvingResult = nil
            switch resolution {
            case .place(let location):
                startSave(location)
            case .expanded:
                toastCenter?.show(
                    .info(
                        String(localized: "Pick a Place to Save"),
                        message: multipleMatchesMessage(for: result),
                        symbol: "mappin.and.ellipse"
                    )
                )
            case .failed:
                toastCenter?.show(
                    .failure(String(localized: "Couldn't Save Location"), message: result.title)
                )
            }
        }
    }

    private func commitName() {
        guard canCommitName, let edit = nameEdit else { return }
        nameEdit = nil
        let name = trimmedName
        do {
            switch edit.mode {
            case .save:
                if let existing = edit.existing {
                    try existing.rename(to: name, in: modelContext)
                    existing.isFavorite = true
                    try modelContext.save()
                    updateSelection(to: existing.entryLocation, matching: edit.location)
                } else {
                    let saved = try withAnimation {
                        try SavedLocation.save(named: name, from: edit.location, in: modelContext)
                    }
                    if isAddingSaved {
                        dismiss()
                    } else if let saved {
                        updateSelection(to: saved.entryLocation, matching: edit.location)
                    }
                }

            case .rename:
                let renamed = try withAnimation {
                    try SavedLocation.rename(edit.location, to: name, in: modelContext)
                }
                if let renamed {
                    updateSelection(to: renamed.entryLocation, matching: edit.location)
                }
            }
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(
                    edit.mode == .rename
                        ? String(localized: "Couldn't Rename Location")
                        : String(localized: "Couldn't Save Location"),
                    message: edit.location.name
                )
            )
        }
    }

    private func useMapName(_ saved: SavedLocation, at location: EntryLocation) {
        let name = saved.name
        var reverted = saved.entryLocation
        reverted.name = saved.mapName ?? name
        if !saved.isFavorite {
            reverted.savedLocationID = nil
        }
        do {
            try withAnimation {
                try saved.revertToMapName(in: modelContext)
            }
            updateSelection(to: reverted, matching: location)
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Rename Location"), message: name)
            )
        }
    }

    private func updateSelection(to named: EntryLocation, matching location: EntryLocation) {
        var named = named
        switch selection {
        case .place(let selected)
        where RecentLocationStore.isSamePlace(selected, location):
            named.mapPin = selected.mapPin
            selection = .place(named)
        case .current(let selected?)
        where RecentLocationStore.isSamePlace(selected, location):
            // Naming where you're standing doesn't stop you standing there, so the selection keeps
            // saying it was found for you and simply takes the new name with it.
            selection = .current(named)
        default:
            break
        }
    }

    private func setDefaultLocation(_ location: EntryLocation?, for food: FoodItem) {
        do {
            try withAnimation(.snappy(duration: 0.3)) {
                try DefaultLocationResolver.set(location, for: food, in: modelContext)
            }
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(
                    location == nil
                        ? String(localized: "Couldn't Clear Default Location")
                        : String(localized: "Couldn't Set Default Location"),
                    message: food.name
                )
            )
        }
    }

    private func unsave(_ saved: SavedLocation) {
        let name = saved.name
        do {
            let record = try withAnimation {
                try saved.delete(in: modelContext)
            }
            toastCenter?.show(.savedLocationDeleted(record, in: modelContext, presenter: toastCenter))
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Delete Saved Location"), message: name)
            )
        }
    }

    /// Every row that stands for the selected place is checked, whether the place was found for
    /// you, pinned on the map or picked from a list — the rows say which place, and Current
    /// Location and Choose on Map say how it got there. A fix that hasn't landed yet stands for
    /// no place at all, so it marks nothing but its own row.
    private func isSelected(_ location: EntryLocation) -> Bool {
        guard let selected = selectedPlace else { return false }
        // Both sides are read under the name a saved record gives them, or a renamed place would
        // fail to recognise itself in a row that still carries the map's name.
        let named = namedMatch(for: location)?.entryLocation ?? location
        return RecentLocationStore.isSamePlace(selected, named)
    }

    private func select(_ newSelection: LocationSelection) {
        selectionOnDismissal = selection
        selection = newSelection
        dismiss()
    }

    private func chooseCurrentLocation() {
        switch locationManager.permission {
        case .authorized:
            if selection == .current(nil) {
                dismiss()
            } else {
                if selection.isCurrent {
                    locationManager.discardCachedLocation()
                }
                select(.current(nil))
            }
        case .notDetermined:
            Task {
                if await locationManager.requestPermission() == .authorized {
                    select(.current(nil))
                }
            }
        case .denied, .restricted:
            locationManager.openSettings()
        }
    }

    private func choose(_ result: MKLocalSearchCompletion) {
        resolvingResult = result
        Task {
            let resolution = await search.resolve(result)
            resolvingResult = nil
            switch resolution {
            case .place(let location):
                select(.place(location))
            case .expanded:
                break
            case .failed:
                select(
                    .place(
                        EntryLocation(
                            name: result.title,
                            address: result.subtitle.isEmpty ? nil : result.subtitle
                        )
                    )
                )
            }
        }
    }

    /// Widens the results to everywhere a query row matches. A lone match is listed like any
    /// other, for you to pick — the search is the row's whole job, so it never selects. And a
    /// query that matches nothing can't fall back to its own text, since "coffee" names no place.
    private func expand(_ result: MKLocalSearchCompletion) {
        resolvingResult = result
        Task {
            let resolution = await search.resolve(result)
            resolvingResult = nil
            if case .failed = resolution {
                toastCenter?.show(
                    .failure(String(localized: "No Places Found"), message: result.title)
                )
            }
        }
    }

    private func loadPreviousPlaces() {
        guard let foodID else { return }
        var descriptor = FetchDescriptor<LoggedEntry>(
            predicate: #Predicate {
                $0.originalFoodItem?.id == foodID && $0.parentEntry == nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        var places: [PreviousPlace] = []
        for entry in (try? modelContext.fetch(descriptor)) ?? [] {
            guard let location = entry.location?.withoutMapPin,
                !places.contains(where: { RecentLocationStore.isSamePlace($0.location, location) })
            else { continue }
            places.append(PreviousPlace(location: location, lastLogged: entry.timestamp))
            if places.count == 5 { break }
        }
        previousPlaces = places
    }

    private func loadNearbyPlaces() async {
        guard let nearby, !isAddingSaved else { return }
        var origin = placeOrigin
        if origin == nil, locationManager.isAuthorized, !locationManager.isReducedAccuracy {
            origin = await locationManager.currentLocation()
        }
        guard !Task.isCancelled else { return }
        guard let origin else {
            withAnimation(.snappy(duration: 0.3)) {
                nearbyResults = []
            }
            return
        }
        let places = await NearbyPlaceCache.shared.places(for: nearby, near: origin)
        guard !Task.isCancelled else { return }
        withAnimation(.snappy(duration: 0.3)) {
            nearbyResults = places
        }
    }

    private func loadPhotoPlaces() async {
        guard !isAddingSaved else { return }

        var clusters: [(photo: LoggedPhoto, coordinate: CLLocationCoordinate2D)] = []
        for photo in photos {
            guard let coordinate = photo.coordinate else { continue }
            let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let isNearExisting = clusters.contains {
                CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    .distance(from: point) <= Self.photoClusterRadius
            }
            guard !isNearExisting else { continue }
            clusters.append((photo, coordinate))
        }

        let photoIDs = Set(photos.map(\.id))
        Self.cachedThumbnails = Self.cachedThumbnails.filter { photoIDs.contains($0.key) }
        photoThumbnails = Self.cachedThumbnails

        var places = clusters.map { cluster in
            PhotoPlace(
                id: cluster.photo.id,
                coordinate: cluster.coordinate,
                image: cluster.photo.image,
                capturedAt: cluster.photo.capturedAt,
                location: PhotoPlaceNamer.knownLocation(
                    at: cluster.coordinate,
                    savedLocations: savedLocations
                )
            )
        }
        photoPlaces = deduplicated(places)

        for place in places where photoThumbnails[place.id] == nil {
            guard let thumbnail = await thumbnail(of: place.image), !Task.isCancelled
            else { continue }
            Self.cachedThumbnails[place.id] = thumbnail
            withAnimation(.easeOut(duration: 0.2)) {
                photoThumbnails[place.id] = thumbnail
            }
        }

        for index in places.indices where places[index].location == nil {
            let location = await PhotoPlaceNamer.location(
                at: places[index].coordinate,
                savedLocations: savedLocations
            )
            guard !Task.isCancelled else { return }
            places[index].location = location
            withAnimation(.snappy(duration: 0.3)) {
                photoPlaces = places
            }
        }

        let unique = deduplicated(places)
        if unique.count != photoPlaces.count {
            withAnimation(.snappy(duration: 0.3)) {
                photoPlaces = unique
            }
        }
    }

    private func deduplicated(_ places: [PhotoPlace]) -> [PhotoPlace] {
        var unique: [PhotoPlace] = []
        for place in places {
            if let location = place.location,
                unique.contains(where: {
                    $0.location.map { RecentLocationStore.isSamePlace($0, location) } ?? false
                })
            {
                continue
            }
            unique.append(place)
        }
        return unique
    }

    private func thumbnail(of image: UIImage) async -> UIImage? {
        let side: CGFloat = 120
        let scale = side / max(min(image.size.width, image.size.height), 1)
        return await image.byPreparingThumbnail(
            ofSize: CGSize(width: image.size.width * scale, height: image.size.height * scale)
        )
    }

    private func photoSubtitle(for place: PhotoPlace, address: String?) -> String? {
        guard let capturedAt = place.capturedAt, let logDate,
            !Calendar.current.isDate(capturedAt, inSameDayAs: logDate)
        else { return address }

        let isSameYear = Calendar.current.isDate(capturedAt, equalTo: logDate, toGranularity: .year)
        let day = capturedAt.formatted(
            isSameYear
                ? .dateTime.month(.abbreviated).day()
                : .dateTime.month(.abbreviated).day().year()
        )
        let taken = String(localized: "Taken \(day)")
        guard let address else { return taken }
        return "\(taken) · \(address)"
    }

    private func distanceText(for location: EntryLocation) -> String? {
        guard let origin = placeOrigin, let destination = location.clLocation else { return nil }
        return Measurement(value: origin.distance(from: destination), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private func distanceSubtitle(for location: EntryLocation) -> String? {
        guard let distance = distanceText(for: location) else { return location.address }
        guard let address = location.address else { return distance }
        return "\(distance) · \(address)"
    }

    /// When you were last here, and how far away it is. A card of one chain's branches reads the
    /// same down every row, so the distance is what tells you which one you're standing at.
    private func loggedSubtitle(for place: PreviousPlace) -> String {
        let logged = String(localized: "Logged \(EntryHelper.logDayText(place.lastLogged))")
        guard let distance = distanceText(for: place.location) else { return logged }
        return "\(logged) · \(distance)"
    }

    private func adjustOnMap(_ place: PhotoPlace, from location: EntryLocation) {
        var pinned = location
        pinned.mapPin = MapPin(place.coordinate)
        path.append(.adjustOnMap(pinned))
    }

    private var photoOrigin: CLLocation? {
        let located = photos.filter { $0.coordinate != nil }
        let photo = logDate.flatMap { date in
            located.min { lhs, rhs in
                timeGap(of: lhs, from: date) < timeGap(of: rhs, from: date)
            }
        } ?? located.first
        guard let coordinate = photo?.coordinate else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func timeGap(of photo: LoggedPhoto, from date: Date) -> TimeInterval {
        photo.capturedAt.map { abs($0.timeIntervalSince(date)) } ?? .infinity
    }

    private var searchOrigin: CLLocation? {
        photoOrigin ?? locationManager.lastLocation
    }

    /// A reduced-accuracy fix can be kilometres off, so it can rough out a search region but
    /// can't rank places or measure how far away they are.
    private var placeOrigin: CLLocation? {
        if let photoOrigin { return photoOrigin }
        return locationManager.isReducedAccuracy ? nil : locationManager.lastLocation
    }

    private func biasSearch() async {
        search.bias(toward: searchOrigin ?? selection.resolvedLocation?.clLocation)
        guard searchOrigin == nil, locationManager.isAuthorized else { return }
        search.bias(toward: await locationManager.currentLocation())
    }
}
