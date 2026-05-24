//
//  LibraryFilterType.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

enum LibraryFilterType: Equatable {
    case all
    case specific(EntryType)

    var displayName: String {
        switch self {
        case .all: return "All"
        case .specific(let type): return type.rawValue.capitalized
        }
    }
}
