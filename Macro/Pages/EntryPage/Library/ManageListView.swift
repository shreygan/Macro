//
//  ManageListView.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/2/26.
//

import SwiftData
import SwiftUI

struct ManageListView: View {
    @Environment(\.modelContext) private var modelContext

    let kind: LibraryListKind

    @Query(sort: \EntrySource.displayOrder) private var sources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) private var categories:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) private var foodGroups:
        [FoodGroupSource]

    @State private var itemToDelete: LibraryListItem? = nil
    @State private var showReorderSheet = false
    @State private var renamingItem: LibraryListItem? = nil
    @State private var isAdding = false
    @State private var nameText = ""
    @State private var usageByName: [String: LibraryListUsage] = [:]
    @FocusState private var focusedField: EditingField?
    @State private var scrollPosition = ScrollPosition()
    @Environment(\.tabBarHeight) private var tabBarHeight

    private enum EditingField: Hashable {
        case rename(PersistentIdentifier)
        case add
    }

    private static let listAnimation = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8
    )

    private var items: [LibraryListItem] {
        LibraryListItem.items(
            for: kind,
            sources: sources,
            categories: categories,
            foodGroups: foodGroups
        )
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let items = items
        let defaults = items.filter(\.isDefault)
        let customs = items.filter { !$0.isDefault }
        let missingDefaults = LibraryListStore.missingDefaults(
            for: kind,
            existing: items
        )

        ZStack {
            Color.background.ignoresSafeArea()

            ScrollView {
                VStack {
                    Card("Defaults") {
                        itemList(defaults, allItems: items)

                        if !missingDefaults.isEmpty {
                            ButtonRow(
                                icon: .customSymbol("arrow.counterclockwise"),
                                title: "Restore Defaults",
                                topPadding: defaults.isEmpty ? 12 : 8
                            ) {
                                withAnimation {
                                    LibraryListStore.restoreDefaults(
                                        for: kind,
                                        existing: items,
                                        in: modelContext
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Card("Custom") {
                        itemList(customs, allItems: items)

                        if isAdding {
                            VStack(spacing: 0) {
                                if !customs.isEmpty {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }

                                newItemRow(allItems: items)
                            }
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.animation(
                                        .easeOut(duration: 0.2).delay(0.12)
                                    ),
                                    removal: .opacity.animation(
                                        .easeOut(duration: 0.15)
                                    )
                                )
                            )
                        }

                        ButtonRow(
                            icon: .customSymbol("plus"),
                            title: "Add \(kind.itemName)",
                            topPadding: customs.isEmpty && !isAdding ? 12 : 8
                        ) {
                            startAdd(allItems: items)
                        }
                    }
                    .padding([.top, .horizontal])
                }
                .padding(.bottom)
                .animation(Self.listAnimation, value: items)
            }
            .scrollPosition($scrollPosition)
            .contentMargins(
                .bottom,
                tabBarHeight > 0 ? tabBarHeight + 12 : 0,
                for: .scrollContent
            )
            .contentMargins(.bottom, tabBarHeight, for: .scrollIndicators)
            .ignoresSafeArea(.container, edges: tabBarHeight > 0 ? .bottom : [])
        }
        .withCustomKeyboardToolbar()
        .withGlobalSwipeDismissal()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showReorderSheet = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(items.count < 2)

                Button {
                    startAdd(allItems: items)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onChange(of: items, initial: true) {
            refreshUsage()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard newValue == nil, !isDuplicateName(allItems: items) else {
                return
            }
            switch oldValue {
            case .add where isAdding:
                commitAdd(allItems: items)
            case .rename(let id) where renamingItem?.id == id:
                commitRename(allItems: items)
            default:
                break
            }
        }
        .alert(
            "Delete \(kind.itemName)?",
            isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            ),
            presenting: itemToDelete
        ) { item in
            deleteActions(for: item)
        } message: { item in
            deleteMessage(for: item)
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderListView(kind: kind)
        }
    }

    @ViewBuilder
    private func itemList(
        _ list: [LibraryListItem],
        allItems: [LibraryListItem]
    ) -> some View {
        if !list.isEmpty {
            EntryList(
                items: list,
                showCard: false,
                rowContent: { item in
                    itemRow(item, usage: usageByName[item.name], allItems: allItems)
                },
                onDelete: { item in
                    itemToDelete = item
                },
                onEdit: { item in
                    startRename(item, allItems: allItems)
                },
                editTitle: "Rename"
            )
        }
    }

    private func itemRow(
        _ item: LibraryListItem,
        usage: LibraryListUsage?,
        allItems: [LibraryListItem]
    ) -> some View {
        let isRenaming = renamingItem?.id == item.id

        return HStack(spacing: 8) {
            if isRenaming {
                nameField(
                    .rename(item.id),
                    placeholder: item.name,
                    allItems: allItems,
                    onConfirm: { commitRename(allItems: allItems) }
                )
            } else {
                if item.isHidden {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.isHidden ? .secondary : .primary)
            }

            Spacer()

            if isRenaming && isDuplicateName(allItems: allItems) {
                duplicateText
            } else {
                usageText(usage)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRenaming {
                startRename(item, allItems: allItems)
            }
        }
        .contextMenu {
            if !isRenaming {
                Button {
                    startRename(item, allItems: allItems)
                } label: {
                    Label("Rename \(kind.itemName)", systemImage: "pencil")
                }

                Button {
                    setHidden(item, !item.isHidden)
                } label: {
                    Label(
                        item.isHidden
                            ? "Show in Dropdowns" : "Hide from Dropdowns",
                        systemImage: item.isHidden ? "eye" : "eye.slash"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    itemToDelete = item
                } label: {
                    Label("Delete \(kind.itemName)", systemImage: "trash")
                }
            }
        }
    }

    private func usageText(_ usage: LibraryListUsage?) -> some View {
        let foodCount = usage?.foodCount ?? 0
        let logCount = usage?.logCount ?? 0

        return Group {
            if foodCount == 0 && logCount == 0 {
                Text("Unused")
            } else {
                Text(
                    "^[\(foodCount) item](inflect: true) · ^[\(logCount) log](inflect: true)"
                )
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
    }

    private func newItemRow(allItems: [LibraryListItem]) -> some View {
        HStack(spacing: 8) {
            nameField(
                .add,
                placeholder: "New \(kind.itemName)",
                allItems: allItems,
                onConfirm: { commitAdd(allItems: allItems) }
            )

            Spacer()

            if isDuplicateName(allItems: allItems) {
                duplicateText
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
    }

    private func nameField(
        _ field: EditingField,
        placeholder: String,
        allItems: [LibraryListItem],
        onConfirm: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: $nameText)
            .font(.system(size: 16, weight: .medium))
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .focused($focusedField, equals: field)
            .autoFloatingToolbar(
                for: .default,
                actions: KeyboardToolbarActions(
                    canConfirm: canCommitName(allItems: allItems),
                    onCancel: cancelEditing,
                    onConfirm: onConfirm
                )
            )
            .onSubmit {
                if !isDuplicateName(allItems: allItems) {
                    onConfirm()
                }
            }
            .onAppear {
                if case .rename = field {
                    focusedField = field
                }
            }
    }

    private var duplicateText: some View {
        Text("Already exists")
            .font(.system(size: 14))
            .foregroundStyle(.red)
    }

    private func isDuplicateName(allItems: [LibraryListItem]) -> Bool {
        let name = trimmedName
        return allItems.contains {
            $0.id != renamingItem?.id
                && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func canCommitName(allItems: [LibraryListItem]) -> Bool {
        !trimmedName.isEmpty && !isDuplicateName(allItems: allItems)
    }

    private func finishEditing(allItems: [LibraryListItem]) {
        if renamingItem != nil {
            commitRename(allItems: allItems)
        }
        if isAdding {
            commitAdd(allItems: allItems)
        }
    }

    private func startRename(
        _ item: LibraryListItem,
        allItems: [LibraryListItem]
    ) {
        finishEditing(allItems: allItems)
        nameText = item.name
        renamingItem = item
    }

    private func startAdd(allItems: [LibraryListItem]) {
        guard !isAdding else {
            focusedField = .add
            return
        }
        finishEditing(allItems: allItems)
        nameText = ""
        withAnimation(Self.listAnimation) {
            isAdding = true
            scrollPosition.scrollTo(edge: .bottom)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard isAdding else { return }
            focusedField = .add
        }
    }

    private func cancelEditing() {
        renamingItem = nil
        focusedField = nil
        withAnimation(Self.listAnimation) {
            isAdding = false
        }
    }

    private func commitRename(allItems: [LibraryListItem]) {
        guard let item = renamingItem else { return }
        let name = trimmedName
        let shouldSave = canCommitName(allItems: allItems) && name != item.name

        renamingItem = nil
        focusedField = nil

        guard shouldSave else { return }
        withAnimation {
            LibraryListStore.rename(
                item.id,
                to: name,
                in: kind,
                context: modelContext
            )
        }
    }

    private func commitAdd(allItems: [LibraryListItem]) {
        guard isAdding else { return }
        let name = trimmedName
        let shouldSave = canCommitName(allItems: allItems)

        focusedField = nil
        let nextOrder = (allItems.map(\.displayOrder).max() ?? -1) + 1

        withAnimation(Self.listAnimation) {
            isAdding = false
            guard shouldSave else { return }
            LibraryListStore.add(
                name,
                to: kind,
                displayOrder: nextOrder,
                in: modelContext
            )
        }
    }

    @ViewBuilder
    private func deleteActions(for item: LibraryListItem) -> some View {
        let isUsed = usage(of: item).isUsed

        if isUsed && !item.isHidden {
            Button("Hide from Dropdowns") {
                setHidden(item, true)
            }
        }

        Button(
            isUsed ? "Delete from All Items" : "Delete",
            role: .destructive
        ) {
            withAnimation {
                LibraryListStore.delete(item.id, in: modelContext)
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    private func usage(of item: LibraryListItem) -> LibraryListUsage {
        usageByName[item.name]
            ?? LibraryListStore.usage(of: item.name, in: kind, context: modelContext)
    }

    private func refreshUsage() {
        usageByName = Dictionary(
            items.map {
                (
                    $0.name,
                    LibraryListStore.usage(
                        of: $0.name,
                        in: kind,
                        context: modelContext
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func setHidden(_ item: LibraryListItem, _ isHidden: Bool) {
        withAnimation {
            LibraryListStore.setHidden(item.id, isHidden, in: modelContext)
        }
    }

    private func deleteMessage(for item: LibraryListItem) -> Text {
        let usage = usage(of: item)
        let itemName = kind.itemName.lowercased()

        guard usage.isUsed else {
            return Text("Are you sure you want to delete \(item.name)?")
        }

        if item.isHidden {
            return Text(
                "\(item.name) is used by ^[\(usage.foodCount) library item](inflect: true) and ^[\(usage.logCount) log](inflect: true). Deleting it will remove it from all of them, leaving them without a \(itemName)."
            )
        }
        return Text(
            "\(item.name) is used by ^[\(usage.foodCount) library item](inflect: true) and ^[\(usage.logCount) log](inflect: true). Hide it to keep it on them but remove it from dropdowns, or delete it to remove it from all of them."
        )
    }
}

private struct ReorderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let kind: LibraryListKind

    @Query(sort: \EntrySource.displayOrder) private var sources: [EntrySource]
    @Query(sort: \CategorySource.displayOrder) private var categories:
        [CategorySource]
    @Query(sort: \FoodGroupSource.displayOrder) private var foodGroups:
        [FoodGroupSource]

    @State private var editMode: EditMode = .active

    private var items: [LibraryListItem] {
        LibraryListItem.items(
            for: kind,
            sources: sources,
            categories: categories,
            foodGroups: foodGroups
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Text(item.name)
                }
                .onMove(perform: moveItems)
            }
            .contentMargins(.top, 0)
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder \(kind.title)")
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

    private func moveItems(from source: IndexSet, to destination: Int) {
        var ids = items.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        LibraryListStore.reorder(ids, in: modelContext)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        LoggedEntry.self,
        EntrySource.self,
        CategorySource.self,
        FoodGroupSource.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(
        EntrySource(source: "Home", isDefault: true, displayOrder: 0)
    )

    return NavigationStack {
        ManageListView(kind: .sources)
    }
    .modelContainer(container)
}
