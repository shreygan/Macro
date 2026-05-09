//
//  LogEntrySheetView.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/3/26.
//

import SwiftUI

struct LogEntrySheetView: View {
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack {
                        Card("Favorites") {
                            RowGroup(.none) {

                                MealRow(
                                    title: "Grilled Chicken Salad",
                                    subtitle: "Sweetgreen, 1 bowl",
                                    calorie: "450",
                                    protein: "42",
                                    carbs: "12",
                                    fat: "18",
                                    fiber: "6"
                                )

                                ButtonRow(
                                    icon: .system("plus"),
                                    title: "Add Favorite"
                                ) {
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Card("New Entry") {
                            ButtonRow(
                                icon: .system("fork.knife"),
                                title: "Add New Food",
                                bottomPadding: 2,
                            ) {}
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
                                NavigationRow(
                                    icon: .system("fork.knife"),
                                    title: "Foods"
                                ) {}
                                NavigationRow(
                                    icon: .system("cup.and.saucer"),
                                    title: "Drinks"
                                ) {}
                            }

                        }
                        .padding([.top, .leading, .trailing])

                        Card("Test") {
                            BaseRowLayout(
                                icon: .system(
                                    "cup.and.saucer.fill",
                                    tint: .blue
                                ),
                                title: "Serving Size"
                            ) {
                                DropdownPill(
                                    options: ["Cup", "Tbsp", "g"],
                                    selection: .constant("Cup")
                                )
                            }
                        } menuItems: {

                            Button {
                                print("Edit tapped")
                            } label: {
                                Label("Edit Meal", systemImage: "pencil")
                            }

                            Button {
                                print("Duplicate tapped")
                            } label: {
                                Label(
                                    "Duplicate",
                                    systemImage: "plus.square.on.square"
                                )
                            }

                            Divider()

                            Button(role: .destructive) {
                                print("Delete tapped")
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .padding([.top, .leading, .trailing])
                        // TODO: FIX CARD HOLDING DOWN SO CAN HOLD DOWN ANYWHERE ON CARD

                        Spacer()
                    }
                }
                .navigationTitle("Log Entry")
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
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    LogEntrySheetView()
}
