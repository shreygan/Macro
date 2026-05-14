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
                            //                            MealRow(
                            //                                title: "Grilled Chicken Salad",
                            //                                subtitle: "Sweetgreen, 1 bowl",
                            //                                calorie: "450",
                            //                                protein: "42",
                            //                                carbs: "12",
                            //                                fat: "18",
                            //                                fiber: "6"
                            //                            )
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
                                icon: .system("cup.and.saucer"),
                                title: "Add New Drink",
                                bottomPadding: 2
                            ) {}
                            ButtonRow(
                                icon: .system("barcode.viewfinder"),
                                title: "Scan Barcode",
                                bottomPadding: 2
                            ) {}
                            ButtonRow(
                                icon: .system("wand.and.sparkles"),
                                title: "AI Estimate",
                                bottomPadding: 2
                            ) {}
                            ButtonRow(
                                icon: .system("message"),
                                title: "Quick Log",
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
            AddFoodSheetView(onLogInstantly: { savedFood in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.foodToLog = savedFood
                }
            })
        }
        .sheet(item: $foodToLog) { food in
            LogFoodSheetView(food: food)
        }
    }
}

#Preview {
    NewEntrySheetView()
}
