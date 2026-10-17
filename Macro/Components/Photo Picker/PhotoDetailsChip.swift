//
//  PhotoDetailsChip.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import SwiftData
import SwiftUI

struct PhotoDetailsChip: View {
    let photo: LoggedPhoto
    var onUseTime: ((Date) -> Void)?
    var onUseLocation: ((EntryLocation) -> Void)?
    var entryDate: Date?
    var entryTime: Date?
    var entryLocation: EntryLocation?
    var isInteractive = true

    @Environment(\.modelContext) private var modelContext
    @State private var location: EntryLocation?
    @State private var appliedCount = 0

    private var capturedAt: Date? {
        guard onUseTime != nil, let capturedAt = photo.capturedAt, capturedAt <= .now
        else { return nil }
        return capturedAt
    }

    private var hasLocation: Bool {
        onUseLocation != nil && photo.coordinate != nil
    }

    private var timeText: String? {
        capturedAt.map(PhotoMetadata.captureText(for:))
    }

    private var isTimeApplied: Bool {
        guard let capturedAt, let entryDate, let entryTime else { return false }
        let calendar = Calendar.current
        let captured = calendar.dateComponents([.hour, .minute], from: capturedAt)
        let entry = calendar.dateComponents([.hour, .minute], from: entryTime)
        return calendar.isDate(capturedAt, inSameDayAs: entryDate)
            && captured.hour == entry.hour && captured.minute == entry.minute
    }

    private var isLocationApplied: Bool {
        guard let location, let entryLocation else { return false }
        return RecentLocationStore.isSamePlace(location.withoutMapPin, entryLocation.withoutMapPin)
    }

    private var hidesPlace: Bool {
        !isInteractive && (location == nil || isLocationApplied)
    }

    private var labelText: String {
        [timeText, hidesPlace ? nil : location?.name].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            chip
        }
        .task(id: photo.id) {
            await resolveLocation()
        }
    }

    @ViewBuilder
    private var chip: some View {
        if capturedAt != nil || (hasLocation && !hidesPlace) {
            Menu {
                menuContent
            } label: {
                Group {
                    if labelText.isEmpty {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text(labelText)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                }
                .font(.compactTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .animation(.snappy(duration: 0.3), value: labelText)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(isInteractive), in: .capsule)
            .padding(7)
            .contentShape(.capsule)
            .allowsHitTesting(isInteractive)
            .accessibilityRespondsToUserInteraction(isInteractive)
            .accessibilityLabel("Photo Details")
            .accessibilityValue(labelText)
            .sensoryFeedback(.success, trigger: appliedCount)
        }
    }

    private var menuContent: some View {
        PhotoDetailsActions(
            capturedAt: capturedAt,
            location: location,
            hasLocation: hasLocation,
            isTimeApplied: isTimeApplied,
            isLocationApplied: isLocationApplied,
            onUseTime: onUseTime,
            onUseLocation: onUseLocation,
            onApply: { appliedCount += 1 }
        )
    }

    private func resolveLocation() async {
        guard hasLocation, let coordinate = photo.coordinate else { return }
        let saved = (try? modelContext.fetch(FetchDescriptor<SavedLocation>())) ?? []
        if let known = PhotoPlaceNamer.knownLocation(at: coordinate, savedLocations: saved) {
            location = known
            return
        }
        let resolved = await PhotoPlaceNamer.location(at: coordinate, savedLocations: saved)
        guard !Task.isCancelled else { return }
        location = resolved
    }
}

struct PhotoDetailsActions: View {
    let capturedAt: Date?
    let location: EntryLocation?
    let hasLocation: Bool
    let isTimeApplied: Bool
    let isLocationApplied: Bool
    var onUseTime: ((Date) -> Void)?
    var onUseLocation: ((EntryLocation) -> Void)?
    var onApply: () -> Void

    var body: some View {
        if let capturedAt, let location {
            Button {
                onUseTime?(capturedAt)
                onUseLocation?(location)
                onApply()
            } label: {
                Text("Use Time & Location")
                Image(systemName: isTimeApplied && isLocationApplied ? "checkmark" : "checkmark.circle")
            }

            Divider()
        }

        if let capturedAt {
            Button {
                onUseTime?(capturedAt)
                onApply()
            } label: {
                Text("Use Time")
                Text(capturedAt.formatted(date: .abbreviated, time: .shortened))
                Image(systemName: isTimeApplied ? "checkmark" : "clock")
            }
        }

        if hasLocation {
            Button {
                guard let location else { return }
                onUseLocation?(location)
                onApply()
            } label: {
                Text("Use Location")
                Text(location?.name ?? String(localized: "Finding Place…"))
                Image(systemName: isLocationApplied ? "checkmark" : "mappin.and.ellipse")
            }
            .disabled(location == nil)
        }
    }
}

