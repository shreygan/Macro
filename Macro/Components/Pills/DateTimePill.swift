//
//  DateTimePill.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/23/26.
//

import SwiftUI

struct DateTimePill: View {
    @Binding var selection: Date
    var components: DatePickerComponents
    var range: ClosedRange<Date>? = nil

    @ViewBuilder
    private var picker: some View {
        if let range {
            DatePicker(
                "",
                selection: $selection,
                in: range,
                displayedComponents: components
            )
        } else {
            DatePicker(
                "",
                selection: $selection,
                displayedComponents: components
            )
        }
    }

    var body: some View {
        ZStack {
            Text(
                selection,
                format: components == .date
                    ? .dateTime.month().day().year() : .dateTime.hour().minute()
            )
            .font(.system(size: 16))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(UIColor.tertiarySystemFill))
            )
            .allowsHitTesting(false)

            picker
                .labelsHidden()
            .opacity(0.011)
            .clipped()
        }
        .fixedSize()
        .contentShape(Capsule())
    }
}
