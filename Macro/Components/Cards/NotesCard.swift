//
//  NotesCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/9/26.
//

import SwiftUI

struct NotesCard: View {
    @Binding var pinnedNote: String
    @Binding var logNote: String
    var pinnedUpdated: Date? = nil
    var allowsPinning: Bool = true
    var isEditable: Bool = true
    var onViewAll: (() -> Void)? = nil

    @State private var isEditingPinned = false
    @State private var isAddingPinned = false

    private let noteAnimation = Animation.spring(response: 0.3, dampingFraction: 0.8)

    private var showsPinnedRow: Bool {
        allowsPinning
            && (!pinnedNote.isEmpty || isEditingPinned || isAddingPinned)
    }

    private var showsAddPinned: Bool {
        isEditable && allowsPinning && !showsPinnedRow
    }

    private var showsDeletePinned: Bool {
        isEditable && allowsPinning && !pinnedNote.isEmpty
    }

    private var hasMenuItems: Bool {
        onViewAll != nil || showsAddPinned || showsDeletePinned
    }

    private var pinnedCaption: String? {
        guard let pinnedUpdated else { return nil }
        return String(
            localized:
                "Updated \(pinnedUpdated.formatted(.relative(presentation: .named)))"
        )
    }

    var body: some View {
        Card("Notes") {
            RowGroup(.divider) {
                if showsPinnedRow {
                    WrappedInputRow(
                        placeholder: "Pinned note",
                        text: $pinnedNote,
                        caption: pinnedCaption,
                        captionSymbol: "pin.fill",
                        captionTint: .orange,
                        isEditable: isEditable,
                        characterLimit: 2000,
                        focusOnAppear: isAddingPinned,
                        onFocusChange: { focused in
                            isEditingPinned = focused
                            if !focused {
                                isAddingPinned = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                WrappedInputRow(
                    placeholder: "Add a note...",
                    text: $logNote,
                    isEditable: isEditable,
                    characterLimit: 2000
                )
            }
        } headerAccessory: {
            if hasMenuItems {
                menu
            }
        }
        .animation(noteAnimation, value: showsPinnedRow)
    }

    private var menu: some View {
        Menu {
            if let onViewAll {
                Button(
                    "View All Notes",
                    systemImage: "clock.arrow.circlepath",
                    action: onViewAll
                )
            }

            if showsAddPinned {
                Button(
                    "Add Pinned Note",
                    systemImage: "pin",
                    action: addPinned
                )
            }

            if showsDeletePinned {
                Button(
                    "Delete Pinned Note",
                    systemImage: "trash",
                    role: .destructive,
                    action: deletePinned
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.gray.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .padding(.vertical, -2)
        .padding(.trailing, -6)
        .accessibilityLabel("Note Options")
    }

    private func deletePinned() {
        withAnimation(noteAnimation) {
            isAddingPinned = false
            isEditingPinned = false
            pinnedNote = ""
        }
    }

    private func addPinned() {
        withAnimation(noteAnimation) {
            isAddingPinned = true
        }
    }
}

#Preview {
    @Previewable @State var emptyPinned = ""
    @Previewable @State var emptyLog = ""
    @Previewable @State var pinned = "Ask them to hold the oil next time"
    @Previewable @State var longLog =
        "Much better this time, asked for less oil and it was way lighter"

    ZStack {
        Color.background.ignoresSafeArea()

        ScrollView {
            VStack {
                NotesCard(
                    pinnedNote: $emptyPinned,
                    logNote: $emptyLog,
                    onViewAll: {}
                )
                .padding()

                NotesCard(
                    pinnedNote: $pinned,
                    logNote: $longLog,
                    pinnedUpdated: Date().addingTimeInterval(-86400 * 21),
                    onViewAll: {}
                )
                .padding()

                NotesCard(
                    pinnedNote: $pinned,
                    logNote: $emptyLog,
                    pinnedUpdated: Date().addingTimeInterval(-86400 * 21),
                    isEditable: false,
                    onViewAll: {}
                )
                .padding()
            }
        }
    }
}
