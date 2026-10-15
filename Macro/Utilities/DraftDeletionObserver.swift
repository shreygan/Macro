//
//  DraftDeletionObserver.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/15/26.
//

import SwiftData
import SwiftUI

private struct DraftDeletionObserver: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    let id: UUID
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content.task {
            guard isEnabled else { return }
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                guard DraftStore.fetch(id: id, in: modelContext) == nil else { continue }
                action()
                return
            }
        }
    }
}

extension View {
    func onDraftDeleted(
        id: UUID,
        isEnabled: Bool = true,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(DraftDeletionObserver(id: id, isEnabled: isEnabled, action: action))
    }
}
