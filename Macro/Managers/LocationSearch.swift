//
//  LocationSearch.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import CoreLocation
import MapKit

@Observable
final class LocationSearch: NSObject, MKLocalSearchCompleterDelegate {
    enum Resolution {
        case place(EntryLocation)
        case expanded
        case failed
    }

    private(set) var places: [EntryLocation] = []
    private(set) var placeSymbols: [EntryLocation: String] = [:]
    private(set) var completions: [MKLocalSearchCompletion] = []
    private(set) var expandedTitle: String?
    private(set) var didFail = false
    private(set) var hasFinished = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private let queryCompleter = MKLocalSearchCompleter()
    @ObservationIgnored private var region: MKCoordinateRegion?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var rawCompletions: [MKLocalSearchCompletion] = []

    /// Nothing on `MKLocalSearchCompletion` says whether it stands for a place or for a search,
    /// so a second completer asks for query completions alone and the titles it answers with are
    /// the rows that mean "search for this".
    private var queryKeys: Set<String> = []

    private static let biasRadius: CLLocationDistance = 50_000
    private static let searchDelay: Duration = .milliseconds(350)
    private static let placeLimit = 10

    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let previous = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != previous else { return }
            if expandedTitle != nil || !Self.isRefinement(trimmed, of: previous) {
                places = []
            }
            expandedTitle = nil
            hasFinished = false
            searchTask?.cancel()
            if trimmed.isEmpty {
                completer.cancel()
                queryCompleter.cancel()
                rawCompletions = []
                queryKeys = []
                places = []
                completions = []
                didFail = false
            } else {
                completer.queryFragment = trimmed
                queryCompleter.queryFragment = trimmed
                scheduleSearch(for: trimmed)
            }
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address, .query]
        queryCompleter.delegate = self
        queryCompleter.resultTypes = [.query]
    }

    func bias(toward location: CLLocation?) {
        guard let location else { return }
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: Self.biasRadius,
            longitudinalMeters: Self.biasRadius
        )
        self.region = region
        completer.region = region
        queryCompleter.region = region
    }

    /// Whether a row stands for a search rather than a place. A query row is never resolved
    /// straight into a selection, however few places it turns out to match.
    func isQuery(_ completion: MKLocalSearchCompletion) -> Bool {
        queryKeys.contains(Self.key(for: completion))
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> Resolution {
        let query = query
        let isQuery = isQuery(completion)
        let request = MKLocalSearch.Request(completion: completion)
        guard let items = try? await MKLocalSearch(request: request).start().mapItems
        else { return .failed }

        let located = Self.locations(from: items)
        if located.isEmpty { return .failed }
        if !isQuery, located.count == 1 {
            return .place(located[0].location)
        }
        guard query == self.query else { return .failed }

        searchTask?.cancel()
        expandedTitle = completion.title
        setPlaces(located)
        completions = []
        return .expanded
    }

    private func scheduleSearch(for text: String) {
        searchTask = Task {
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            request.resultTypes = [.pointOfInterest, .address]
            if let region {
                request.region = region
            }
            let items = try? await MKLocalSearch(request: request).start().mapItems
            guard !Task.isCancelled else { return }

            setPlaces(Array(Self.locations(from: items ?? []).prefix(Self.placeLimit)))
            completions = Self.removingDuplicates(of: places, from: rawCompletions)
            hasFinished = true
        }
    }

    private func setPlaces(_ located: [(location: EntryLocation, symbol: String?)]) {
        places = located.map(\.location)
        placeSymbols = Dictionary(
            located.compactMap { item in item.symbol.map { (item.location, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func locations(
        from items: [MKMapItem]
    ) -> [(location: EntryLocation, symbol: String?)] {
        items.compactMap { item in
            EntryLocation(mapItem: item).map { ($0, item.pointOfInterestCategory?.symbolName) }
        }
    }

    private static func isRefinement(_ text: String, of previous: String) -> Bool {
        let text = text.lowercased()
        let previous = previous.lowercased()
        return !previous.isEmpty && (text.hasPrefix(previous) || previous.hasPrefix(text))
    }

    private static func removingDuplicates(
        of places: [EntryLocation],
        from completions: [MKLocalSearchCompletion]
    ) -> [MKLocalSearchCompletion] {
        completions.filter { completion in
            !places.contains { place in
                matches(place.name, completion.title)
                    && matches(firstLine(of: place.address), firstLine(of: completion.subtitle))
            }
        }
    }

    /// Both completers answer the same fragment, so a query row is recognised by the title and
    /// subtitle it arrives with in each.
    private static func key(for completion: MKLocalSearchCompletion) -> String {
        let title = completion.title.collapsingWhitespace.trimmingCharacters(in: .whitespaces)
        let subtitle = completion.subtitle.collapsingWhitespace
            .trimmingCharacters(in: .whitespaces)
        return "\(title.lowercased())\n\(subtitle.lowercased())"
    }

    private static func firstLine(of address: String?) -> String {
        address?.split(separator: ",").first.map(String.init) ?? ""
    }

    private static func matches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.collapsingWhitespace.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(rhs.collapsingWhitespace.trimmingCharacters(in: .whitespaces))
            == .orderedSame
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let isQueryPass = completer === queryCompleter
        Task { @MainActor in
            guard self.expandedTitle == nil else { return }
            if isQueryPass {
                self.queryKeys = Set(self.queryCompleter.results.map(Self.key(for:)))
            } else {
                self.rawCompletions = self.completer.results
                self.completions = Self.removingDuplicates(
                    of: self.places,
                    from: self.rawCompletions
                )
                self.didFail = false
            }
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        let isQueryPass = completer === queryCompleter
        Task { @MainActor in
            guard self.expandedTitle == nil else { return }
            // A failed classification pass leaves rows looking like places; the resolve that
            // follows still won't commit one, since it only selects a lone exact match.
            if isQueryPass {
                self.queryKeys = []
                return
            }
            self.rawCompletions = []
            self.completions = []
            self.didFail = true
        }
    }
}

extension MKPointOfInterestCategory {
    var symbolName: String? {
        switch self {
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .bakery: "birthday.cake.fill"
        case .brewery: "mug.fill"
        case .winery, .distillery: "wineglass.fill"
        case .nightlife: "party.popper.fill"
        case .foodMarket: "cart.fill"
        case .store: "bag.fill"
        case .hotel: "bed.double.fill"
        case .airport: "airplane"
        case .park, .nationalPark: "tree.fill"
        case .beach: "beach.umbrella.fill"
        case .campground, .rvPark: "tent.fill"
        case .fitnessCenter: "dumbbell.fill"
        case .movieTheater: "film.fill"
        case .theater: "theatermasks.fill"
        case .musicVenue: "music.note"
        case .museum, .landmark, .nationalMonument, .castle, .fortress: "building.columns.fill"
        case .conventionCenter: "building.2.fill"
        case .planetarium: "moon.stars.fill"
        case .library: "books.vertical.fill"
        case .school, .university: "graduationcap.fill"
        case .hospital: "cross.case.fill"
        case .pharmacy: "pills.fill"
        case .gasStation: "fuelpump.fill"
        case .evCharger: "bolt.car.fill"
        case .parking: "parkingsign"
        case .publicTransport: "tram.fill"
        case .carRental, .goKart: "car.fill"
        case .automotiveRepair: "wrench.and.screwdriver.fill"
        case .stadium: "sportscourt.fill"
        case .zoo, .animalService: "pawprint.fill"
        case .aquarium, .fishing: "fish.fill"
        case .amusementPark, .fairground: "balloon.2.fill"
        case .bank, .atm: "banknote.fill"
        case .marina: "sailboat.fill"
        case .police: "shield.fill"
        case .fireStation: "flame.fill"
        case .postOffice, .mailbox: "envelope.fill"
        case .laundry: "washer.fill"
        case .restroom: "toilet.fill"
        case .beauty, .spa: "sparkles"
        case .bowling: "figure.bowling"
        case .golf, .miniGolf: "figure.golf"
        case .hiking: "figure.hiking"
        case .skiing: "figure.skiing.downhill"
        case .soccer: "soccerball"
        case .tennis: "tennis.racket"
        case .basketball: "basketball.fill"
        case .baseball: "baseball.fill"
        case .volleyball: "volleyball.fill"
        case .swimming: "figure.pool.swim"
        case .surfing: "figure.surfing"
        case .kayaking: "oar.2.crossed"
        case .rockClimbing: "figure.climbing"
        case .skating, .skatePark: "figure.skating"
        default: nil
        }
    }
}
