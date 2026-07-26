//
//  RootDismissKey.swift
//  Macro
//
//  Created by Shrey Gangwar on 7/25/26.
//

import SwiftUI

struct RootDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var rootDismiss: (() -> Void)? {
        get { self[RootDismissKey.self] }
        set { self[RootDismissKey.self] = newValue }
    }
}
