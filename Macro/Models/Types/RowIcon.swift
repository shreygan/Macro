//
//  RowIcon.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

enum RowIcon {
    /// For Macro symbols defined in AppSymbols.
    case appSymbol(AppSymbols, tint: Color = .primary)
    /// For SF Symbols. Passes the string name.
    case customSymbol(String, tint: Color = .primary)
    /// For custom asset catalog images. Passes the Image itself.
    case custom(Image)
}
