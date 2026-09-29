//
//  DraftCloseButton.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftUI

struct DraftCloseButton: View {
    var isResumedDraft: Bool
    var canSaveDraft: Bool = true

    var onClose: () -> Void
    var onSaveDraft: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        Menu {
            Button(
                "Save as Draft",
                systemImage: "square.and.arrow.down",
                action: onSaveDraft
            )
            .disabled(!canSaveDraft)

            Button(
                isResumedDraft ? "Delete Draft" : "Discard",
                systemImage: "trash",
                role: .destructive,
                action: onDiscard
            )
        } label: {
            Image(systemName: "xmark")
                .foregroundStyle(.primary)
        } primaryAction: {
            onClose()
        }
    }
}
