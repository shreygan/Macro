//
//  HomeView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImportSheet = false
    @State private var showGoalSetupSheet = false
    @State private var showDeleteConfirmation = false

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

            try modelContext.save()
            print("All data successfully cleared.")
        } catch {
            print("Failed to clear data: \(error.localizedDescription)")
        }
    }

    func currDate() -> String {
        let date = Date()
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Hello World!")
            }
            .navigationTitle("Home")
            .navigationSubtitle(currDate())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "calendar")
                    }

                    Button {
                    } label: {
                        Image(systemName: "gear")
                    }

                    Menu {
                        Button {
                            showImportSheet = true
                        } label: {
                            Label(
                                "Import...",
                                systemImage: "square.and.arrow.down"
                            )
                        }

                        Button {
                            showGoalSetupSheet = true
                        } label: {
                            Label("Update Goals", systemImage: "target")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }

                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportView()
            }
            .sheet(isPresented: $showGoalSetupSheet) {
                GoalSetupView(
                    isCalorieActive: .constant(false),
                    isProteinActive: .constant(false),
                    isCarbsActive: .constant(false),
                    isFatActive: .constant(false),
                    isFiberActive: .constant(false)
                )
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(
                    "This will permanently delete all your saved ingredients, foods, and recipes. This action cannot be undone."
                )
            }
        }
    }
}

#Preview {
    HomeView()
}
