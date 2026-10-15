//
//  ManageSavedLocationsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/12/26.
//

import SwiftData
import SwiftUI

struct ManageSavedLocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastCenter) private var toastCenter

    var allowsAdding = true

    @Query(sort: \SavedLocation.displayOrder) private var savedLocations: [SavedLocation]

    @State private var renamingID: UUID?
    @State private var nameText = ""
    @State private var showReorderSheet = false
    @State private var showAddSheet = false
    @FocusState private var focusedID: UUID?

    private static let listAnimation = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8
    )

    private var favorites: [SavedLocation] {
        savedLocations.filter(\.isFavorite)
    }

    private var renamed: [SavedLocation] {
        savedLocations.filter { !$0.isFavorite }
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        let name = trimmedName
        return savedLocations.contains {
            $0.id != renamingID && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private var canCommitName: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if savedLocations.isEmpty && !allowsAdding {
                ContentUnavailableView(
                    "No Saved Locations",
                    systemImage: "star",
                    description: Text("Use Save As… on the map to name a place, like Home or Work.")
                )
            } else {
                ScrollView {
                    VStack {
                        if !favorites.isEmpty || allowsAdding {
                            Card(renamed.isEmpty ? nil : String(localized: "Saved")) {
                                if !favorites.isEmpty {
                                    EntryList(
                                        items: favorites,
                                        showCard: false,
                                        rowContent: { saved in
                                            row(for: saved)
                                        },
                                        onDelete: delete,
                                        onEdit: startRename,
                                        editTitle: "Rename",
                                        onFavorite: toggleFavorite,
                                        isFavorited: { _ in true }
                                    )
                                }

                                if allowsAdding {
                                    if !favorites.isEmpty {
                                        Divider()
                                            .padding(.horizontal, 16)
                                    }

                                    ButtonRow(
                                        icon: .customSymbol("plus"),
                                        title: String(localized: "Add Location"),
                                        topPadding: favorites.isEmpty ? 12 : 8
                                    ) {
                                        startAdd()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        if !renamed.isEmpty {
                            Card(String(localized: "Renamed Places")) {
                                EntryList(
                                    items: renamed,
                                    showCard: false,
                                    rowContent: { saved in
                                        row(for: saved)
                                    },
                                    onDelete: delete,
                                    onEdit: startRename,
                                    editTitle: "Rename",
                                    onFavorite: toggleFavorite,
                                    isFavorited: { _ in false }
                                )
                            }
                            .padding([.top, .horizontal])
                        }
                    }
                    .animation(
                        Self.listAnimation,
                        value: savedLocations.map { [$0.id.uuidString, String($0.isFavorite)] }
                    )
                }
                .tabBarScrollInsets(ignoring: .container)
            }
        }
        .withCustomKeyboardToolbar()
        .withGlobalSwipeDismissal()
        .navigationTitle("Saved Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showReorderSheet = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(favorites.count < 2)

                if allowsAdding {
                    Button {
                        startAdd()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onChange(of: focusedID) { oldValue, newValue in
            guard newValue == nil, let oldValue, oldValue == renamingID, !isDuplicateName else {
                return
            }
            commitRename()
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderSavedLocationsView()
        }
        .sheet(isPresented: $showAddSheet) {
            LocationPickerSheet(selection: .constant(.none), isAddingSaved: true)
        }
    }

    private func row(for saved: SavedLocation) -> some View {
        let isRenaming = renamingID == saved.id
        let logCount = (saved.entries ?? []).filter { $0.parentEntry == nil }.count

        return HStack(spacing: 8) {
            Image(systemName: saved.isFavorite ? "star.fill" : "mappin")
                .font(.rowIcon)
                .frame(width: 15)

            VStack(alignment: .leading, spacing: 2) {
                Text(saved.name)
                    .font(.rowTitle)
                    .foregroundStyle(.primary)
                    .opacity(isRenaming ? 0 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if isRenaming {
                            nameField(for: saved)
                        }
                    }

                if let address = saved.address {
                    Text(address)
                        .font(.subtitle)
                        .foregroundStyle(Color.tertiaryText)
                }
            }

            Spacer()

            if isRenaming && isDuplicateName {
                Text("Already exists")
                    .font(.compactValue)
                    .foregroundStyle(.red)
            } else {
                Text("^[\(logCount) log](inflect: true)")
                    .font(.compactValue)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRenaming {
                startRename(saved)
            }
        }
        .contextMenu {
            if !isRenaming {
                Button {
                    startRename(saved)
                } label: {
                    Label("Rename Location", systemImage: "pencil")
                }

                if let mapName = saved.mapName {
                    Button {
                        useMapName(saved)
                    } label: {
                        Label("Use Map’s Name", systemImage: "arrow.uturn.backward")
                        Text(mapName)
                    }
                }

                Button {
                    toggleFavorite(saved)
                } label: {
                    Label(
                        saved.isFavorite ? "Remove from Saved" : "Add to Saved",
                        systemImage: saved.isFavorite ? "star.slash" : "star"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    delete(saved)
                } label: {
                    Label("Delete Saved Location", systemImage: "trash")
                }
            }
        }
    }

    private func nameField(for saved: SavedLocation) -> some View {
        TextField(saved.name, text: $nameText)
            .font(.rowTitle)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($focusedID, equals: saved.id)
            .autoFloatingToolbar(
                for: .default,
                actions: KeyboardToolbarActions(
                    canConfirm: canCommitName,
                    onCancel: cancelRename,
                    onConfirm: commitRename
                )
            )
            .onSubmit {
                if !isDuplicateName {
                    commitRename()
                }
            }
            .onAppear {
                focusedID = saved.id
            }
    }

    private func startAdd() {
        if renamingID != nil {
            commitRename()
        }
        showAddSheet = true
    }

    private func startRename(_ saved: SavedLocation) {
        if renamingID != nil {
            commitRename()
        }
        nameText = saved.name
        renamingID = saved.id
    }

    private func cancelRename() {
        renamingID = nil
        focusedID = nil
    }

    private func commitRename() {
        guard let renamingID,
            let saved = savedLocations.first(where: { $0.id == renamingID })
        else { return }
        let name = trimmedName
        let shouldSave = canCommitName && name != saved.name

        self.renamingID = nil
        focusedID = nil

        guard shouldSave else { return }
        do {
            try saved.rename(to: name, in: modelContext)
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Rename Location"), message: saved.name)
            )
        }
    }

    private func useMapName(_ saved: SavedLocation) {
        if renamingID == saved.id {
            cancelRename()
        }
        let name = saved.name
        do {
            try withAnimation(Self.listAnimation) {
                try saved.revertToMapName(in: modelContext)
            }
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Rename Location"), message: name)
            )
        }
    }

    private func toggleFavorite(_ saved: SavedLocation) {
        saved.isFavorite.toggle()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(
                .failure(String(localized: "Couldn't Update Location"), message: saved.name)
            )
        }
    }

    private func delete(_ saved: SavedLocation) {
        if renamingID == saved.id {
            cancelRename()
        }
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
}

struct ReorderSavedLocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastCenter) private var toastCenter

    @Query(sort: \SavedLocation.displayOrder) private var savedLocations: [SavedLocation]

    @State private var editMode: EditMode = .active

    private var favorites: [SavedLocation] {
        savedLocations.filter(\.isFavorite)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { saved in
                    Text(saved.name)
                }
                .onMove(perform: move)
            }
            .contentMargins(.top, 0)
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Saved Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = favorites
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, saved) in ordered.enumerated() {
            saved.displayOrder = index
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            toastCenter?.show(.failure(String(localized: "Couldn't Reorder Locations")))
        }
    }
}
