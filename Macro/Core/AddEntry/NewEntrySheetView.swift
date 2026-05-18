//
//  LogEntrySheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftUI

struct NewEntrySheetView: View {
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""

    @State private var showAddFoodSheet = false
    @State private var showAddRecipeSheet = false
    @State private var foodToLog: FoodItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("Favorites") {
                            Text("TODO")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .padding()
                        } menuItems: {
                            Button {

                            } label: {
                                Label("Add a Favorite", systemImage: "star")
                            }

                            Button {

                            } label: {
                                Label("Edit Favorites", systemImage: "pencil")
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card("New Entry") {
                            ButtonRow(
                                icon: .system("fork.knife"),
                                title: "Add New Food",
                                bottomPadding: 2
                            ) {
                                showAddFoodSheet = true
                            }
                            ButtonRow(
                                icon: .system("list.clipboard"),
                                title: "Add New Recipe",
                                bottomPadding: 2
                            ) {
                                showAddRecipeSheet = true
                            }
                            ButtonRow(
                                icon: .system("cup.and.saucer"),
                                title: "Add New Drink",
                            ) {}
                        }
                        .padding([.top, .leading, .trailing])

                        Card("Library") {
                            RowGroup(.divider) {
                                NavigationLink(
                                    destination: FoodLibrarySheetView()
                                ) {
                                    NavigationRow(
                                        icon: .system("fork.knife"),
                                        title: "Foods"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink(
                                    destination: FoodLibrarySheetView()
                                ) {
                                    NavigationRow(
                                        icon: .system("list.clipboard"),
                                        title: "Recipes"
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationRow(
                                    icon: .system("cup.and.saucer"),
                                    title: "Drinks"
                                )
                            }

                        }
                        .padding([.top, .leading, .trailing])

                        Spacer()
                    }
                }
                .navigationTitle("New Entry")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $searchText,
                    prompt: "What did you eat today?"
                )
                .searchDictationBehavior(.automatic)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
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
        .sheet(isPresented: $showAddFoodSheet) {
            AddEntrySheetView(
                entryType: .food,
                onLogInstantly: { savedFood in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.foodToLog = savedFood
                    }
                }
            )
        }
        .sheet(isPresented: $showAddRecipeSheet) {
            AddRecipeSheetView()
        }
        .sheet(item: $foodToLog) { food in
            LogFoodSheetView(food: food)
        }
    }
}

#Preview {
    NewEntrySheetView()
}
