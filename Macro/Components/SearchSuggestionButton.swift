//
//  SearchSuggestionButton.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/9/26.
//

import SwiftUI

struct SearchSuggestionButton: View {
    let suggestion: String?
    let fallback: LocalizedStringKey
    let onSelect: (String) -> Void

    var body: some View {
        if let suggestion {
            Button("Did you mean \"\(suggestion)\"?") {
                onSelect(suggestion)
            }
            .tint(.blue)
        } else {
            Text(fallback)
        }
    }
}
