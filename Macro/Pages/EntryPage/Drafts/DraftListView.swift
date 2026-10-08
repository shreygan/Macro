//
//  DraftListView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/3/26.
//

import SwiftData
import SwiftUI

enum DraftFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case logs
    case library

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .logs: return "Logs"
        case .library: return "Library"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "No Drafts"
        case .logs: return "No Log Drafts"
        case .library: return "No Library Drafts"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "tray.full"
        case .logs: return "calendar.badge.clock"
        case .library: return "book.pages"
        }
    }

    func includes(_ draft: EntryDraft) -> Bool {
        switch self {
        case .all: return true
        case .logs: return draft.kind?.isLog == true
        case .library: return draft.kind?.isLog != true
        }
    }
}

enum DraftSortOption {
    case lastEdited
    case dateCreated
    case logDate
    case name
}

struct DraftListView: View {
    var onResume: (EntryDraft) -> Void
    var onDelete: (EntryDraft) -> Void

    @Query(sort: \EntryDraft.updatedAt, order: .reverse) private var drafts:
        [EntryDraft]
    @Query(sort: \ServingSizeUnit.displayOrder) private var portionUnitOptions:
        [ServingSizeUnit]

    @State private var searchText = ""
    @State private var filter: DraftFilter = .all
    @State private var sortOption: DraftSortOption = .lastEdited
    @State private var sortDescending = true

    private var filteredDrafts: [EntryDraft] {
        let matches = drafts.filter { draft in
            filter.includes(draft)
                && (searchText.isEmpty
                    || displayName(for: draft).localizedStandardContains(
                        searchText
                    ))
        }

        return matches.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return displayName(for: lhs).localizedStandardCompare(
                    displayName(for: rhs)
                ) == .orderedAscending
            case .lastEdited:
                return ordered(lhs.updatedAt, rhs.updatedAt)
            case .dateCreated:
                return ordered(lhs.createdAt, rhs.createdAt)
            case .logDate:
                return ordered(
                    lhs.timestamp ?? lhs.updatedAt,
                    rhs.timestamp ?? rhs.updatedAt
                )
            }
        }
    }

    private func ordered(_ lhs: Date, _ rhs: Date) -> Bool {
        sortDescending ? lhs > rhs : lhs < rhs
    }

    private func displayName(for draft: EntryDraft) -> String {
        let typeName = draft.entryType?.rawValue.capitalized ?? "Entry"
        return draft.name.isEmpty ? "New \(typeName)" : draft.name
    }

    var body: some View {
        let drafts = filteredDrafts

        ZStack {
            Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                filterPicker

                if drafts.isEmpty {
                    emptyStateView
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        draftCard(drafts)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8),
                                value: drafts
                            )
                    }
                    .transition(.opacity)
                }
            }
        }
        .withGlobalSwipeDismissal()
        .animation(.easeInOut(duration: 0.25), value: drafts.isEmpty)
        .animation(.easeInOut(duration: 0.25), value: filter)
        .onChange(of: filter) { _, newFilter in
            if newFilter == .library && sortOption == .logDate {
                sortOption = .lastEdited
            }
        }
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $searchText, prompt: "Search drafts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
    }

    private func draftCard(_ drafts: [EntryDraft]) -> some View {
        Card {
            EntryList(
                items: drafts,
                allowSwipeActions: true,
                showCard: false,
                rowContent: { draft in
                    DraftRow(
                        draft: draft,
                        servingUnits: portionUnitOptions,
                        showsLogDate: true
                    ) {
                        onResume(draft)
                    }
                    .contextMenu {
                        Button {
                            onResume(draft)
                        } label: {
                            Label(
                                "Resume Draft",
                                systemImage: "square.and.pencil"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            onDelete(draft)
                        } label: {
                            Label("Delete Draft", systemImage: "trash")
                        }
                    }
                },
                onDelete: { draft in
                    onDelete(draft)
                }
            )
        }
        .padding([.horizontal, .bottom])
        .transition(.opacity)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(DraftFilter.allCases) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding([.horizontal, .bottom])
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if searchText.isEmpty {
            ContentUnavailableView {
                Label(filter.emptyTitle, systemImage: filter.symbol)
            } description: {
                Text("Unfinished entries you close will appear here.")
                    .font(.subheadline)
            }
        } else {
            ContentUnavailableView {
                Label(
                    "No Results for \"\(searchText)\"",
                    systemImage: "magnifyingglass"
                )
            } description: {
                Text("Try a different search.")
                    .font(.subheadline)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                if filter != .library {
                    Text("Log Date").tag(DraftSortOption.logDate)
                }
                Text("Last Edited").tag(DraftSortOption.lastEdited)
                Text("Date Created").tag(DraftSortOption.dateCreated)
                Text("Name").tag(DraftSortOption.name)
            }
            if sortOption != .name {
                Divider()
                Picker("Order", selection: $sortDescending) {
                    Text("Newest First").tag(true)
                    Text("Oldest First").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
