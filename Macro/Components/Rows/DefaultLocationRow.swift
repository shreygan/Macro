//
//  DefaultLocationRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/13/26.
//

import SwiftData
import SwiftUI

struct DefaultLocationRow: View {
    @Binding var location: EntryLocation?
    var sourceName: String = ""
    var foodIDs: [UUID] = []
    var title: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    @State private var isPickerPresented = false
    @State private var pickerSelection: LocationSelection = .none

    private var nearby: NearbyPlaceSearch? {
        let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : .source(trimmed)
    }

    var body: some View {
        row
            .sheet(isPresented: $isPickerPresented) {
            LocationPickerSheet(
                selection: $pickerSelection,
                foodIDs: foodIDs,
                nearby: nearby
            )
        }
        .onChange(of: pickerSelection) { _, newValue in
            Task { await apply(newValue) }
        }
        .animation(.snappy(duration: 0.3), value: location)
    }

    @ViewBuilder
    private var row: some View {
        if let title {
            BaseRowLayout(title: title, fitsRightContent: true) {
                LocationPill(
                    selection: location.map { .place($0) } ?? .none,
                    action: openPicker
                )
            }
        } else {
            Button(action: openPicker) {
                HStack(spacing: 8) {
                    label
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.chevron)
                        .foregroundStyle(Color.tertiaryText)
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(minHeight: RowMetrics.controlHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, RowMetrics.verticalPadding)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let location {
            VStack(alignment: .leading, spacing: 2) {
                Text.location(location.name)
                    .font(.rowValue)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let address = location.address {
                    Text(address)
                        .font(.subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text("Default Location")
                .font(.rowValue)
                .foregroundStyle(Color.placeholderText)
        }
    }

    private func openPicker() {
        pickerSelection = location.map { .place($0) } ?? .none
        isPickerPresented = true
    }

    private func apply(_ selection: LocationSelection) async {
        switch selection {
        case .none:
            if location != nil { location = nil }
        case .place(let place):
            guard place != location else { return }
            let named = await DefaultLocationResolver.named(place)
            guard pickerSelection == selection else { return }
            store(named)
        case .current(let resolved):
            let place: EntryLocation?
            if let resolved {
                place = resolved
            } else {
                let saved = (try? modelContext.fetch(FetchDescriptor<SavedLocation>())) ?? []
                place = await LocationManager.shared.currentPlace(matching: saved)
            }
            guard let place, pickerSelection.isCurrent else { return }
            let named = await DefaultLocationResolver.named(place)
            guard pickerSelection.isCurrent else { return }
            store(named)
        }
    }

    private func store(_ place: EntryLocation?) {
        guard let place else {
            toastCenter?.show(.failure(String(localized: "Couldn't Set Default Location")))
            return
        }
        location = place.withoutMapPin
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self, EntrySource.self, SavedLocation.self, LoggedEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )

    struct DefaultLocationRowPreview: View {
        @State private var empty: EntryLocation?
        @State private var chain: EntryLocation? = EntryLocation(
            name: "Chipotle Mexican Grill",
            address: "4000 Factoria Blvd SE, Bellevue, WA 98006",
            latitude: 47.5745,
            longitude: -122.1690,
            mapItemID: "IBC211BDD06B0F997"
        )
        @State private var exact: EntryLocation? = EntryLocation(
            name: "Work",
            latitude: 47.6,
            longitude: -122.2
        )

        var body: some View {
            ZStack {
                Color.background.ignoresSafeArea()

                Card {
                    RowGroup(.divider) {
                        FullWidthInputRow(placeholder: "Name", text: .constant("Burrito Bowl"))
                        DefaultLocationRow(location: $empty)
                        DefaultLocationRow(location: $chain, sourceName: "Chipotle")
                        DefaultLocationRow(location: $exact, sourceName: "Work")
                    }
                }
                .padding()
            }
        }
    }

    return DefaultLocationRowPreview()
        .modelContainer(container)
}
