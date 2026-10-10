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
            .tint(.blue)

            Button("Create \"\(split.name.titleCasedFoodName)\" from \(split.source)") {
                onCreate(split.name, split.source)
            }
            .tint(.blue)
        } else {
            Button(title) {
                onCreate(query, "")
            }
            .tint(.blue)
        }
    }
}
