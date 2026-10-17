//
//  ToggleRow.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/7/26.
//

import SwiftUI

struct ToggleRow: View {
    var icon: RowIcon? = nil
    var title: String
    var titleExtension: String? = nil
    var subtitle: String? = nil
    var animatesSubtitle: Bool = false
    var info: String? = nil

    @Binding var isOn: Bool

    var body: some View {
        BaseRowLayout(
            icon: icon,
            title: title,
            titleExtension: titleExtension,
            subtitle: subtitle,
            animatesSubtitle: animatesSubtitle,
            info: info
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}
