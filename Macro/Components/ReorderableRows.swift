//
//  ReorderableRows.swift
//  Macro
//

import CoreTransferable
import SwiftUI

struct ReorderableRows<Item: Identifiable, Row: View>: View where Item.ID == UUID {
    @Binding var items: [Item]
    var isEnabled: Bool = true
    @ViewBuilder var row: (Binding<Item>) -> Row

    @Environment(SwipeFocusManager.self) private var focusManager

    @State private var liftedID: UUID?
    @State private var liftResetTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ForEach($items) { $item in
                row($item)
                    .background {
                        if liftedID == item.id {
                            Rectangle()
                                .fill(.clear)
                                .glassEffect(
                                    .regular.tint(Color(white: 0.96).opacity(0.7)),
                                    in: .rect
                                )
                        }
                    }
                    .contentShape(
                        .dragPreview,
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                    .overlay(alignment: .top) {
                        if items.first?.id != item.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                    .allowsHitTesting(isEnabled)
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        )
                    )
            }
            .reorderable()
        }
        .environment(\.backgroundMaterial, nil)
        .reorderContainer(for: Item.self) { difference in
            guard isEnabled else { return }
            withAnimation(.snappy) {
                difference.apply(to: &items)
            }
            liftResetTask?.cancel()
            liftedID = nil
        }
        .dragContainer(for: ReorderDragItem.self) { id in
            beginLift(id)
            return [ReorderDragItem(id: id)]
        }
    }

    private func beginLift(_ id: UUID) {
        if focusManager.activeRowID != nil {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                focusManager.activeRowID = nil
            }
        }

        liftedID = id
        liftResetTask?.cancel()
        liftResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            liftedID = nil
        }
    }
}

private struct ReorderDragItem: Transferable, Identifiable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}

extension ReorderDifference where CollectionID == ReorderableSingleCollectionIdentifier {
    func apply<C>(to collection: inout C)
    where
        C: RangeReplaceableCollection,
        C.Element: Identifiable,
        C.Element.ID == ItemID
    {
        let moving = Set(sources)
        guard !moving.isEmpty else { return }

        var moved: [C.Element] = []
        moved.reserveCapacity(moving.count)
        collection.removeAll { element in
            guard moving.contains(element.id) else { return false }
            moved.append(element)
            return true
        }

        switch destination.position {
        case .before(let id):
            let index = collection.firstIndex { $0.id == id } ?? collection.endIndex
            collection.insert(contentsOf: moved, at: index)
        case .end:
            collection.append(contentsOf: moved)
        }
    }
}
