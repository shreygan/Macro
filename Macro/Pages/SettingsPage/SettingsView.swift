//
//  SettingsView.swift
//  Macro
//
//  Created by Shrey Gangwar on 9/29/26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var users: [User]

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("Goals") {
                            RowGroup(.divider) {
                                NavigationLink {
                                    GoalSetupView(
                                        isCalorieActive: .constant(false),
                                        isProteinActive: .constant(false),
                                        isCarbsActive: .constant(false),
                                        isFatActive: .constant(false),
                                        isFiberActive: .constant(false)
                                    )
                                } label: {
                                    NavigationRow(
                                        icon: .customSymbol("target"),
                                        title: "Macro Goals"
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if let user = users.first {
                                    NavigationLink {
                                        GoalHistoryView(user: user)
                                    } label: {
                                        NavigationRow(
                                            icon: .customSymbol(
                                                "clock.arrow.circlepath"
                                            ),
                                            title: "Goal History"
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)

                        Card("Data") {
                            NavigationLink {
                                ImportView()
                            } label: {
                                NavigationRow(
                                    icon: .customSymbol("square.and.arrow.down"),
                                    title: "Import"
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding([.top, .leading, .trailing])

                        Card("Reset") {
                            InformationRow(
                                description:
                                    "Permanently removes all logged entries, saved foods, goals, and personal data from this device. This action cannot be undone."
                            )

                            ButtonRow(
                                icon: .customSymbol("trash", tint: .red),
                                title: "Delete All Data",
                                tint: .red.opacity(0.1),
                                textColor: .red,
                                topPadding: 0
                            ) {
                                showDeleteConfirmation = true
                            }
                        }
                        .padding([.top, .horizontal])
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Settings")
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
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                    dismiss()
                }
            } message: {
                Text(
                    "This will permanently delete all your logged entries, saved foods, and personal data. This action cannot be undone."
                )
            }
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: User.self)
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: EntrySource.self)
            try modelContext.delete(model: CategorySource.self)
            try modelContext.delete(model: FoodGroupSource.self)
            try modelContext.delete(model: ServingSizeUnit.self)
            try modelContext.delete(model: FavoriteEntry.self)
            try modelContext.delete(model: LoggedEntry.self)
            try modelContext.delete(model: EntryDraft.self)

            try modelContext.save()
            print("All data successfully cleared.")

            try AppSeeder.seedDefaults(into: modelContext)
            print("Default data successfully reseeded.")
        } catch {
            print(
                "Failed to clear or reseed data: \(error.localizedDescription)"
            )
        }
    }
}

#Preview {
    SettingsView()
}
