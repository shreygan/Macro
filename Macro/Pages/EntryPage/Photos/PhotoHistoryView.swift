//
//  PhotoHistoryView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftData
import SwiftUI

enum PhotoHistoryMode: String, CaseIterable {
    case grid
    case logs

    var title: String {
        switch self {
        case .grid: String(localized: "Grid")
        case .logs: String(localized: "By Log")
        }
    }
}

struct PhotoLog: Identifiable {
    let entry: LoggedEntry
    let photos: [EntryPhoto]

    var id: UUID { entry.id }

    static func logs(from entries: [LoggedEntry]) -> [PhotoLog] {
        entries.compactMap { entry in
            let photos = (entry.photos ?? []).sorted {
                $0.displayOrder < $1.displayOrder
            }
            return photos.isEmpty ? nil : PhotoLog(entry: entry, photos: photos)
        }
    }

    static func detail(for entry: LoggedEntry) -> String? {
        let parts = [entry.category?.category, entry.locationName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func detailText(for entry: LoggedEntry) -> Text? {
        Text.detailLine([entry.category?.category], location: entry.locationName)
    }
}

struct PhotoHistoryView: View {
    let food: FoodItem
    var currentEntryID: UUID? = nil
    var isPushedView: Bool = false

    var body: some View {
        if isPushedView {
            PhotoHistoryContent(
                food: food,
                currentEntryID: currentEntryID,
                isPushedView: true
            )
        } else {
            NavigationStack {
                PhotoHistoryContent(
                    food: food,
                    currentEntryID: currentEntryID,
                    isPushedView: false
                )
            }
            .environment(\.tabBarHeight, 0)
        }
    }
}

private struct PhotoHistoryContent: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("photoHistoryMode") private var mode: PhotoHistoryMode = .logs

    let food: FoodItem
    let currentEntryID: UUID?
    let isPushedView: Bool

    @Query private var logs: [LoggedEntry]

    @State private var framingWidth: CGFloat = 0
    @State private var viewerPhoto: EntryPhoto? = nil
    @State private var viewerSelection: PersistentIdentifier? = nil
    @State private var selectedEntry: LoggedEntry? = nil

    @Namespace private var photoNamespace

    init(food: FoodItem, currentEntryID: UUID?, isPushedView: Bool) {
        self.food = food
        self.currentEntryID = currentEntryID
        self.isPushedView = isPushedView
        _logs = Query(FoodItemStore.topLevelLogsDescriptor(for: food))
    }

    private struct PhotoMonth: Identifiable {
        let id: Date
        var logs: [PhotoLog]
    }

    private func months(_ photoLogs: [PhotoLog]) -> [PhotoMonth] {
        let calendar = Calendar.current
        var result: [PhotoMonth] = []
        for log in photoLogs {
            let month =
                calendar.dateInterval(of: .month, for: log.entry.timestamp)?
                .start ?? log.entry.timestamp
            if result.last?.id == month {
                result[result.count - 1].logs.append(log)
            } else {
                result.append(PhotoMonth(id: month, logs: [log]))
            }
        }
        return result
    }

    var body: some View {
        let photoLogs = PhotoLog.logs(from: logs)
        let months = months(photoLogs)

        ZStack {
            Color.background.ignoresSafeArea()

            if photoLogs.isEmpty {
                ContentUnavailableView {
                    Label("No Photos", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Photos you add when logging this \(food.type.rawValue) will appear here.")
                        .font(.subheadline)
                }
            } else {
                Group {
                    switch mode {
                    case .logs:
                        logList(months)
                    case .grid:
                        photoGrid(months)
                    }
                }
                .tabBarScrollInsets()
                .safeAreaBar(edge: .top) {
                    Picker("View", selection: $mode) {
                        ForEach(PhotoHistoryMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .bottom])
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            framingWidth = max(0, width - 32)
        }        .navigationDestination(item: $selectedEntry) { entry in
            LoggedEntryDetailView(entry: entry, isReadOnly: true)
        }
        .fullScreenCover(item: $viewerPhoto) { photo in
            PhotoViewer(
                items: photoLogs.flatMap { log in
                    log.photos.map { PhotoViewerItem(photo: $0, entry: log.entry) }
                },
                selection: $viewerSelection,
                currentEntryID: currentEntryID
            )
            .navigationTransition(
                .zoom(
                    sourceID: viewerSelection ?? photo.persistentModelID,
                    in: photoNamespace
                )
            )
        }
        .navigationTitle("Photos")
        .navigationSubtitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPushedView {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private func openViewer(_ photo: EntryPhoto) {
        viewerSelection = photo.persistentModelID
        viewerPhoto = photo
    }

    private func monthHeader(_ month: Date, isFirst: Bool) -> some View {
        Text(month.formatted(.dateTime.month(.wide).year()))
            .font(.sectionTitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, isFirst ? 0 : 12)
    }

    private func logList(_ months: [PhotoMonth]) -> some View {
        ScrollView {
            LazyVStack {
                ForEach(months) { month in
                    Section {
                        ForEach(month.logs) { log in
                            LogPhotoCard(
                                log: log,
                                detail: PhotoLog.detailText(for: log.entry),
                                isCurrent: log.id == currentEntryID,
                                framingWidth: framingWidth,
                                namespace: photoNamespace,
                                onSelectPhoto: { openViewer($0) },
                                onOpenLog: { selectedEntry = log.entry }
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 18)
                        }
                    } header: {
                        monthHeader(month.id, isFirst: month.id == months.first?.id)
                    }
                }
            }
        }
    }

    private func photoGrid(_ months: [PhotoMonth]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 4),
                    count: 3
                ),
                spacing: 4
            ) {
                ForEach(months) { month in
                    Section {
                        ForEach(month.logs) { log in
                            ForEach(log.photos) { photo in
                                gridCell(PhotoViewerItem(photo: photo, entry: log.entry))
                            }
                        }
                    } header: {
                        monthHeader(month.id, isFirst: month.id == months.first?.id)
                            .padding(.horizontal, -16)
                            .padding(.bottom, 4)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func gridCell(_ item: PhotoViewerItem) -> some View {
        let photo = item.photo
        let entry = item.entry
        let photoID = item.id

        return Button {
            openViewer(photo)
        } label: {
            EntryPhotoImage(photo: photo, framingWidth: framingWidth)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if entry.id == currentEntryID {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(
            .contextMenuPreview,
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contextMenu {
            if entry.id != currentEntryID {
                Button {
                    selectedEntry = entry
                } label: {
                    Label("View Log", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .matchedTransitionSource(id: photoID, in: photoNamespace)
        .accessibilityLabel(
            "Photo from \(EntryHelper.logDateText(entry.timestamp))"
        )
    }
}

private struct LogPhotoCard: View {
    let log: PhotoLog
    let detail: Text?
    let isCurrent: Bool
    let framingWidth: CGFloat
    let namespace: Namespace.ID
    var onSelectPhoto: (EntryPhoto) -> Void
    var onOpenLog: () -> Void

    private var photoWidth: CGFloat {
        let available = max(0, framingWidth - 32)
        return log.photos.count > 1 ? (available * 0.82).rounded() : available
    }

    private var note: String? {
        guard let note = log.entry.logNote, !note.isEmpty else { return nil }
        return note
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                carousel

                if let note {
                    Text(note)
                        .font(.rowValue)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var header: some View {
        let content = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(EntryHelper.logDateText(log.entry.timestamp))
                    .font(.rowTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let detail {
                    detail
                        .font(.subtitle)
                        .foregroundStyle(Color.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrent {
                Text("This Log")
                    .tagStyle(.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.chevron)
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(.horizontal, 16)

        if isCurrent {
            content
        } else {
            Button(action: onOpenLog) {
                content.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(log.photos) { photo in
                    Button {
                        onSelectPhoto(photo)
                    } label: {
                        EntryPhotoImage(photo: photo, framingWidth: framingWidth)
                            .frame(width: photoWidth, height: photoWidth)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(
                        id: photo.persistentModelID,
                        in: namespace
                    )
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollDisabled(log.photos.count < 2)
        .frame(height: photoWidth)
    }
}
