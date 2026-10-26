//
//  CreateFromSearchButtons.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/9/26.
//

import SwiftData
import SwiftUI

struct CreateFromSearchButtons: View {
    let query: String
    let title: LocalizedStringKey
    let onCreate: (_ name: String, _ source: String) -> Void

    @Query(filter: #Predicate<EntrySource> { !$0.isHidden })
    private var visibleSources: [EntrySource]

    var body: some View {
        if let split = FoodSearch.sourceSplit(
            of: query,
            sources: visibleSources.map(\.source)
        ) {
            Button("Create \"\(query.titleCasedFoodName)\"") {
                onCreate(query, "")
            }
            .tint(.accentColor)

            Button("Create \"\(split.name.titleCasedFoodName)\" from \(split.source)") {
                onCreate(split.name, split.source)
            }
            .tint(.accentColor)
        } else {
            Button(title) {
                onCreate(query, "")
            }
            .tint(.accentColor)
        }
    }
}

struct CreateFromSearchRows: View {
    let query: String
    let split: (name: String, source: String)?
    let onCreate: (_ name: String, _ source: String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ButtonRow(
                icon: .customSymbol("plus.circle.fill"),
                title: String(localized: "Create \"\(query.titleCasedFoodName)\""),
                bottomPadding: split == nil ? 16 : 2
            ) {
                onCreate(query, "")
            }

            if let split {
                ButtonRow(
                    icon: .customSymbol("plus.circle.fill"),
                    title: String(localized: "Create \"\(split.name.titleCasedFoodName)\" from \(split.source)")
                ) {
                    onCreate(split.name, split.source)
                }
                .transition(.opacity)
            }
        }
    }
}

struct LibrarySearchCard<Results: View>: View {
    let query: String
    let hasResults: Bool
    let onCreate: (_ name: String, _ source: String) -> Void
    @ViewBuilder var results: Results

    @Query(filter: #Predicate<EntrySource> { !$0.isHidden })
    private var visibleSources: [EntrySource]

    var body: some View {
        let split = FoodSearch.sourceSplit(of: query, sources: visibleSources.map(\.source))
            .map { (name: $0.name, source: $0.source) }

        Card(String(localized: "Library"), titleBottomPadding: hasResults ? -4 : 0) {
            if hasResults {
                results

                Divider()
                    .padding(.horizontal, 16)
            } else {
                Text("Not in your library yet.")
                    .font(.compactTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding([.top, .horizontal])
            }

            CreateFromSearchRows(query: query, split: split, onCreate: onCreate)
                .padding(.top, 8)
        }
        .animation(.snappy, value: split?.source)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: EntrySource.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    container.mainContext.insert(EntrySource(source: "Trader Joe's", displayOrder: 0))

    return ZStack {
        Color.background.ignoresSafeArea()
        ScrollView {
            VStack {
                LibrarySearchCard(query: "oat milk", hasResults: false, onCreate: { _, _ in }) {
                    EmptyView()
                }
                .padding(.horizontal)

                Card(String(localized: "Built-In"), titleBottomPadding: 4) {
                    BaseRowLayout(
                        icon: .customSymbol("carton.fill", tint: .blue),
                        title: "Milk (2%)",
                        subtitle: "Glass · 240 ml"
                    ) {}
                    .padding(.bottom, 6)
                }
                .padding([.top, .horizontal])

                LibrarySearchCard(query: "trader joe's chicken thigh", hasResults: true, onCreate: { _, _ in }) {
                    BaseRowLayout(title: "Chicken Breast", subtitle: "Costco · 100 g") {}
                }
                .padding([.top, .horizontal])
            }
        }
    }
    .modelContainer(container)
}
